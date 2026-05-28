import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final appPreferencesRepositoryProvider = Provider<AppPreferencesRepository>((ref) {
  return AppPreferencesRepository();
});

final appPreferencesControllerProvider = StateNotifierProvider<AppPreferencesController, AppPreferencesState>((ref) {
  return AppPreferencesController(ref.read(appPreferencesRepositoryProvider));
});

class AppPreferencesRepository {
  static const _themeModeKey = 'theme_mode';
  static const _notificationsEnabledKey = 'notifications_enabled';
  static const _messagePreviewsKey = 'message_previews';
  static const _soundsEnabledKey = 'sounds_enabled';
  static const _vibrationEnabledKey = 'vibration_enabled';

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  Future<ThemeMode> loadThemeMode() async {
    final prefs = await _prefs;
    final value = prefs.getString(_themeModeKey);
    return switch (value) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      _ => ThemeMode.system,
    };
  }

  Future<void> saveThemeMode(ThemeMode mode) async {
    final prefs = await _prefs;
    await prefs.setString(
      _themeModeKey,
      switch (mode) {
        ThemeMode.dark => 'dark',
        ThemeMode.light => 'light',
        ThemeMode.system => 'system',
      },
    );
  }

  Future<NotificationPreferences> loadNotificationPreferences() async {
    final prefs = await _prefs;
    return NotificationPreferences(
      notificationsEnabled: prefs.getBool(_notificationsEnabledKey) ?? true,
      showMessagePreviews: prefs.getBool(_messagePreviewsKey) ?? true,
      soundsEnabled: prefs.getBool(_soundsEnabledKey) ?? true,
      vibrationEnabled: prefs.getBool(_vibrationEnabledKey) ?? true,
    );
  }

  Future<void> saveNotificationPreferences(NotificationPreferences preferences) async {
    final prefs = await _prefs;
    await prefs.setBool(_notificationsEnabledKey, preferences.notificationsEnabled);
    await prefs.setBool(_messagePreviewsKey, preferences.showMessagePreviews);
    await prefs.setBool(_soundsEnabledKey, preferences.soundsEnabled);
    await prefs.setBool(_vibrationEnabledKey, preferences.vibrationEnabled);
  }
}

class AppPreferencesController extends StateNotifier<AppPreferencesState> {
  AppPreferencesController(this._repository) : super(const AppPreferencesState()) {
    _load();
  }

  final AppPreferencesRepository _repository;

  Future<void> _load() async {
    final themeMode = await _repository.loadThemeMode();
    final notifications = await _repository.loadNotificationPreferences();
    state = AppPreferencesState(
      loaded: true,
      themeMode: themeMode,
      notifications: notifications,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _repository.saveThemeMode(mode);
  }

  Future<void> updateNotifications(NotificationPreferences notifications) async {
    state = state.copyWith(notifications: notifications);
    await _repository.saveNotificationPreferences(notifications);
  }
}

class AppPreferencesState {
  const AppPreferencesState({
    this.loaded = false,
    this.themeMode = ThemeMode.system,
    this.notifications = const NotificationPreferences(),
  });

  final bool loaded;
  final ThemeMode themeMode;
  final NotificationPreferences notifications;

  AppPreferencesState copyWith({
    bool? loaded,
    ThemeMode? themeMode,
    NotificationPreferences? notifications,
  }) {
    return AppPreferencesState(
      loaded: loaded ?? this.loaded,
      themeMode: themeMode ?? this.themeMode,
      notifications: notifications ?? this.notifications,
    );
  }
}

class NotificationPreferences {
  const NotificationPreferences({
    this.notificationsEnabled = true,
    this.showMessagePreviews = true,
    this.soundsEnabled = true,
    this.vibrationEnabled = true,
  });

  final bool notificationsEnabled;
  final bool showMessagePreviews;
  final bool soundsEnabled;
  final bool vibrationEnabled;

  NotificationPreferences copyWith({
    bool? notificationsEnabled,
    bool? showMessagePreviews,
    bool? soundsEnabled,
    bool? vibrationEnabled,
  }) {
    return NotificationPreferences(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      showMessagePreviews: showMessagePreviews ?? this.showMessagePreviews,
      soundsEnabled: soundsEnabled ?? this.soundsEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
    );
  }
}
