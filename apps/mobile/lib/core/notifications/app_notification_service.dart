import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/anonymous/data/anonymous_repository.dart';
import '../../features/anonymous/domain/anonymous_message_model.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/domain/auth_state.dart' as local_auth;
import '../../features/chat/data/chat_repository.dart';
import '../../features/chat/domain/message_model.dart';
import '../../features/groups/data/groups_repository.dart';
import '../../features/groups/domain/group_model.dart';
import '../settings/app_preferences_repository.dart';

final appNotificationServiceProvider = Provider<AppNotificationService>((ref) {
  return AppNotificationService.instance;
});

class AppNotificationService {
  AppNotificationService._();

  static final AppNotificationService instance = AppNotificationService._();

  static const AndroidNotificationChannel _androidChannel = AndroidNotificationChannel(
    'vibeloop_activity',
    'Actividad de Nadien',
    description: 'Avisos de mensajes nuevos y mensajes anónimos.',
    importance: Importance.high,
  );

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final Map<String, StreamSubscription<List<MessageModel>>> _messageSubscriptions = {};
  final Map<String, StreamSubscription<List<AnonymousMessageModel>>> _anonymousSubscriptions = {};
  final Map<String, _GroupNotificationSnapshot> _snapshots = {};
  final Map<String, String> _groupNames = {};

  GoRouter? _router;
  bool _initialized = false;
  bool _firebaseMessagingInitialized = false;
  bool _syncInProgress = false;
  _NotificationSyncRequest? _pendingRequest;
  String? _activeSignature;
  String? _registeredPushToken;
  String? _registeredPushUserId;
  int _nextNotificationId = 1;
  NotificationPreferences _currentPreferences = const NotificationPreferences();

  Future<void> attachRouter(GoRouter router) async {
    _router = router;
    await _ensureInitialized();
  }

  Future<bool> requestPermissions() async {
    await _ensureInitialized();

    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    final macos = _plugin.resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>();

    final androidGranted = await android?.requestNotificationsPermission();
    final iosGranted = await ios?.requestPermissions(alert: true, badge: true, sound: true);
    final macosGranted = await macos?.requestPermissions(alert: true, badge: true, sound: true);
    final firebaseGranted = await _messaging.requestPermission(alert: true, badge: true, sound: true);

    final grantedValues = <bool>[
      androidGranted == true,
      iosGranted == true,
      macosGranted == true,
      firebaseGranted.authorizationStatus == AuthorizationStatus.authorized ||
          firebaseGranted.authorizationStatus == AuthorizationStatus.provisional,
    ];
    return grantedValues.any((value) => value);
  }

  Future<void> sync({
    required bool preferencesLoaded,
    required local_auth.AuthState authState,
    required AppPreferencesState preferences,
    required List<GroupModel> groups,
    required ChatRepository chatRepository,
    required AnonymousRepository anonymousRepository,
  }) async {
    _pendingRequest = _NotificationSyncRequest(
      preferencesLoaded: preferencesLoaded,
      authState: authState,
      preferences: preferences,
      groups: groups,
      chatRepository: chatRepository,
      anonymousRepository: anonymousRepository,
    );

    if (_syncInProgress) {
      return;
    }

    _syncInProgress = true;
    try {
      while (_pendingRequest != null) {
        final request = _pendingRequest!;
        _pendingRequest = null;
        await _syncInternal(request);
      }
    } finally {
      _syncInProgress = false;
    }
  }

  Future<void> dispose() async {
    await _cancelAllSubscriptions();
    await _clearPushRegistration();
  }

  Future<void> _syncInternal(_NotificationSyncRequest request) async {
    await _ensureInitialized();

    final user = request.authState.maybeWhen(authenticated: (user) => user, orElse: () => null);
    final isEnabled = request.preferences.notifications.notificationsEnabled;
    _currentPreferences = request.preferences.notifications;
    final signature = _buildSignature(
      userId: user?.id,
      preferencesLoaded: request.preferencesLoaded,
      enabled: isEnabled,
      groups: request.groups,
    );

    if (signature == _activeSignature) {
      await _syncPushRegistration(
        user: user,
        preferencesLoaded: request.preferencesLoaded,
        enabled: isEnabled,
      );
      return;
    }

    _activeSignature = signature;
    _groupNames
      ..clear()
      ..addEntries(request.groups.map((group) => MapEntry(group.id, group.name)));

    if (!request.preferencesLoaded || !isEnabled || user == null) {
      await _cancelAllSubscriptions();
      await _syncPushRegistration(
        user: user,
        preferencesLoaded: request.preferencesLoaded,
        enabled: isEnabled,
      );
      return;
    }

    final currentGroupIds = request.groups.map((group) => group.id).toSet();
    final staleGroupIds = _snapshots.keys.where((groupId) => !currentGroupIds.contains(groupId)).toList();
    for (final groupId in staleGroupIds) {
      _snapshots.remove(groupId);
      await _messageSubscriptions.remove(groupId)?.cancel();
      await _anonymousSubscriptions.remove(groupId)?.cancel();
    }

    for (final group in request.groups) {
      _messageSubscriptions[group.id] ??= request.chatRepository.watchMessages(group.id).listen(
        (messages) => _handleMessageSnapshot(group, user.id, messages),
        onError: (error, stackTrace) => debugPrint('[AppNotificationService] message stream error for ${group.id}: $error'),
      );

      _anonymousSubscriptions[group.id] ??= request.anonymousRepository.watchAnonymousMessages(group.id).listen(
        (messages) => _handleAnonymousSnapshot(group, messages),
        onError: (error, stackTrace) => debugPrint('[AppNotificationService] anonymous stream error for ${group.id}: $error'),
      );
    }

    await _syncPushRegistration(
      user: user,
      preferencesLoaded: request.preferencesLoaded,
      enabled: isEnabled,
    );
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) {
      return;
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
        macOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) {
          return;
        }
        _router?.go(payload);
      },
    );

    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(_androidChannel);

    await _ensureFirebaseMessagingInitialized();

    _initialized = true;
  }

  Future<void> _ensureFirebaseMessagingInitialized() async {
    if (_firebaseMessagingInitialized) {
      return;
    }

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    _messaging.onTokenRefresh.listen((token) {
      unawaited(_upsertPushToken(token));
    });

    FirebaseMessaging.onMessageOpenedApp.listen(_handleFirebaseMessage);

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleFirebaseMessage(initialMessage);
    }

    _firebaseMessagingInitialized = true;
  }

  Future<void> _cancelAllSubscriptions() async {
    for (final subscription in _messageSubscriptions.values) {
      await subscription.cancel();
    }
    for (final subscription in _anonymousSubscriptions.values) {
      await subscription.cancel();
    }
    _messageSubscriptions.clear();
    _anonymousSubscriptions.clear();
    _snapshots.clear();
    _groupNames.clear();
    _activeSignature = null;
  }

  Future<void> _syncPushRegistration({
    required User? user,
    required bool preferencesLoaded,
    required bool enabled,
  }) async {
    await _ensureFirebaseMessagingInitialized();

    if (!preferencesLoaded || !enabled || user == null) {
      await _clearPushRegistration();
      return;
    }

    final settings = await _messaging.getNotificationSettings();
    final permissionGranted = settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;

    if (!permissionGranted) {
      await _clearPushRegistration();
      return;
    }

    final token = await _messaging.getToken();
    if (token == null || token.trim().isEmpty) {
      return;
    }

    await _upsertPushToken(token.trim(), userId: user.id);
  }

  Future<void> _upsertPushToken(
    String token, {
    String? userId,
  }) async {
    final currentUserId = userId ?? _registeredPushUserId;
    if (currentUserId == null) {
      return;
    }

    if (_registeredPushToken != null && _registeredPushToken != token) {
      await _deletePushToken(_registeredPushToken!);
    }

    try {
      await Supabase.instance.client.from('user_push_devices').upsert({
        'user_id': currentUserId,
        'fcm_token': token,
        'platform': Platform.operatingSystem,
        'notifications_enabled': true,
        'show_message_previews': _currentPreferences.showMessagePreviews,
        'sounds_enabled': _currentPreferences.soundsEnabled,
        'vibration_enabled': _currentPreferences.vibrationEnabled,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'fcm_token');
      _registeredPushToken = token;
      _registeredPushUserId = currentUserId;
    } catch (error, stackTrace) {
      debugPrint('[AppNotificationService] Failed to store push token: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _clearPushRegistration() async {
    if (_registeredPushToken != null) {
      await _deletePushToken(_registeredPushToken!);
    }
    _registeredPushToken = null;
    _registeredPushUserId = null;
  }

  Future<void> _deletePushToken(String token) async {
    try {
      await Supabase.instance.client.from('user_push_devices').delete().eq('fcm_token', token);
    } catch (error, stackTrace) {
      debugPrint('[AppNotificationService] Failed to delete push token: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void _handleFirebaseMessage(RemoteMessage message) {
    final route = message.data['route']?.toString().trim();
    if (route == null || route.isEmpty) {
      return;
    }

    _router?.go(route);
  }

  void _handleMessageSnapshot(
    GroupModel group,
    String currentUserId,
    List<MessageModel> messages,
  ) {
    final snapshot = _snapshots.putIfAbsent(group.id, _GroupNotificationSnapshot.new);
    final topMessage = messages.isNotEmpty ? messages.first : null;
    final topMessageId = topMessage?.id;
    final topMessageCount = messages.length;

    final shouldNotify = snapshot.messageInitialized &&
        topMessageId != null &&
        topMessageId != snapshot.lastMessageId &&
        topMessageCount > snapshot.lastMessageCount &&
        topMessage?.senderId != currentUserId;

    snapshot
      ..messageInitialized = true
      ..lastMessageId = topMessageId
      ..lastMessageCount = topMessageCount;

    if (!shouldNotify || topMessage == null) {
      return;
    }

    unawaited(_showNotification(
      title: 'Nuevo mensaje',
      body: _buildNotificationBody(group.name, NotificationCategory.message),
      payload: '/groups/${group.id}/chat',
      category: NotificationCategory.message,
      groupId: group.id,
      showSound: _currentPreferences.soundsEnabled,
      showVibration: _currentPreferences.vibrationEnabled,
    ));
  }

  void _handleAnonymousSnapshot(
    GroupModel group,
    List<AnonymousMessageModel> messages,
  ) {
    final snapshot = _snapshots.putIfAbsent(group.id, _GroupNotificationSnapshot.new);
    final topMessage = messages.isNotEmpty ? messages.first : null;
    final topMessageId = topMessage?.id;
    final topMessageCount = messages.length;

    final shouldNotify = snapshot.anonymousInitialized &&
        topMessageId != null &&
        topMessageId != snapshot.lastAnonymousId &&
        topMessageCount > snapshot.lastAnonymousCount;

    snapshot
      ..anonymousInitialized = true
      ..lastAnonymousId = topMessageId
      ..lastAnonymousCount = topMessageCount;

    if (!shouldNotify || topMessage == null) {
      return;
    }

    unawaited(_showNotification(
      title: 'Mensaje anónimo',
      body: _buildNotificationBody(group.name, NotificationCategory.anonymous),
      payload: '/groups/${group.id}/anonymous',
      category: NotificationCategory.anonymous,
      groupId: group.id,
      showSound: _currentPreferences.soundsEnabled,
      showVibration: _currentPreferences.vibrationEnabled,
    ));
  }

  Future<void> _showNotification({
    required String title,
    required String body,
    required String payload,
    required NotificationCategory category,
    required String groupId,
    required bool showSound,
    required bool showVibration,
  }) async {
    try {
      final id = _nextNotificationId++;
      final androidDetails = AndroidNotificationDetails(
        _androidChannel.id,
        _androidChannel.name,
        channelDescription: _androidChannel.description,
        importance: Importance.high,
        priority: Priority.high,
        playSound: showSound,
        enableVibration: showVibration,
        icon: '@mipmap/ic_launcher',
      );
      final iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: showSound,
      );

      await _plugin.show(
        id,
        title,
        body,
        NotificationDetails(android: androidDetails, iOS: iosDetails, macOS: iosDetails),
        payload: payload,
      );
    } catch (error, stackTrace) {
      debugPrint('[AppNotificationService] Notification error ($category, $groupId): $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  String _buildNotificationBody(String groupName, NotificationCategory category) {
    if (!_currentPreferences.showMessagePreviews) {
      return category == NotificationCategory.anonymous
          ? 'Te han enviado un mensaje anónimo'
          : 'Tienes un mensaje nuevo';
    }

    final trimmedGroupName = groupName.trim();
    if (trimmedGroupName.isEmpty) {
      return category == NotificationCategory.anonymous
          ? 'Te han enviado un mensaje anónimo'
          : 'Tienes un mensaje nuevo';
    }

    return category == NotificationCategory.anonymous
        ? 'Te han enviado un mensaje anónimo en $trimmedGroupName'
        : 'Tienes un mensaje nuevo en $trimmedGroupName';
  }

  String _buildSignature({
    required String? userId,
    required bool preferencesLoaded,
    required bool enabled,
    required List<GroupModel> groups,
  }) {
    final groupSignature = groups.map((group) => '${group.id}:${group.name}').join('|');
    return '${userId ?? 'guest'}::$preferencesLoaded::$enabled::$groupSignature';
  }
}

class NotificationBootstrap extends ConsumerStatefulWidget {
  const NotificationBootstrap({
    super.key,
    required this.router,
    required this.child,
  });

  final GoRouter router;
  final Widget child;

  @override
  ConsumerState<NotificationBootstrap> createState() => _NotificationBootstrapState();
}

class _NotificationBootstrapState extends ConsumerState<NotificationBootstrap> {
  bool _initialSyncRequested = false;
  String? _loadedGroupsForUserId;

  @override
  void initState() {
    super.initState();
    unawaited(AppNotificationService.instance.attachRouter(widget.router));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authStateProvider, (_, __) => _syncNow());
    ref.listen(appPreferencesControllerProvider, (_, __) => _syncNow());
    ref.listen(groupsControllerProvider, (_, __) => _syncNow());

    if (!_initialSyncRequested) {
      _initialSyncRequested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncNow());
    }

    return widget.child;
  }

  void _syncNow() {
    final authState = ref.read(authStateProvider);
    final preferencesState = ref.read(appPreferencesControllerProvider);
    final groupsState = ref.read(groupsControllerProvider);
    final user = authState.maybeWhen(authenticated: (user) => user, orElse: () => null);

    if (user == null) {
      _loadedGroupsForUserId = null;
    } else if (_loadedGroupsForUserId != user.id) {
      _loadedGroupsForUserId = user.id;
      ref.read(groupsControllerProvider.notifier).loadMyGroups();
    }

    final groups = groupsState.valueOrNull ?? const <GroupModel>[];
    final chatRepository = ref.read(chatRepositoryProvider);
    final anonymousRepository = ref.read(anonymousRepositoryProvider);

    unawaited(
      AppNotificationService.instance.sync(
        preferencesLoaded: preferencesState.loaded,
        authState: authState,
        preferences: preferencesState,
        groups: groups,
        chatRepository: chatRepository,
        anonymousRepository: anonymousRepository,
      ),
    );
  }
}

class _NotificationSyncRequest {
  const _NotificationSyncRequest({
    required this.preferencesLoaded,
    required this.authState,
    required this.preferences,
    required this.groups,
    required this.chatRepository,
    required this.anonymousRepository,
  });

  final bool preferencesLoaded;
  final local_auth.AuthState authState;
  final AppPreferencesState preferences;
  final List<GroupModel> groups;
  final ChatRepository chatRepository;
  final AnonymousRepository anonymousRepository;
}

class _GroupNotificationSnapshot {
  bool messageInitialized = false;
  bool anonymousInitialized = false;
  String? lastMessageId;
  String? lastAnonymousId;
  int lastMessageCount = 0;
  int lastAnonymousCount = 0;
}

enum NotificationCategory { message, anonymous }
