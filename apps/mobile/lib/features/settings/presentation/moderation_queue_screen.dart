import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/vibe_tokens.dart';
import '../../../core/widgets/vibe_svg_icon.dart';
import '../../../core/widgets/vibe_ui.dart';
import '../data/safety_repository.dart';

final moderationReportsProvider =
    FutureProvider.family<List<ContentReportModel>, String?>((ref, statusFilter) async {
  final safetyRepo = ref.watch(safetyRepositoryProvider);
  return safetyRepo.fetchModerationReports(statusFilter: statusFilter, onlyMyReports: true);
});

class ModerationQueueScreen extends ConsumerStatefulWidget {
  const ModerationQueueScreen({super.key});

  @override
  ConsumerState<ModerationQueueScreen> createState() => _ModerationQueueScreenState();
}

class _ModerationQueueScreenState extends ConsumerState<ModerationQueueScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    final text = Theme.of(context).colorScheme.onSurface;

    return VibeScaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Estado de mis denuncias',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Material(
            color: surface,
            elevation: 0,
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: 'Volver',
              onPressed: () => context.pop(),
              icon: VibeSvgIcon(
                VibeAssetIcons.arrowBack,
                size: 20,
                color: text,
              ),
            ),
          ),
        ),
        leadingWidth: 64,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: VibeColors.primaryViolet,
          labelColor: VibeColors.primaryViolet,
          unselectedLabelColor: text.withValues(alpha: 0.6),
          tabs: const [
            Tab(text: 'Pendientes'),
            Tab(text: 'Sancionadas'),
            Tab(text: 'Desestimadas'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _ReportListTab(statusFilter: 'pending'),
          _ReportListTab(statusFilter: 'action_taken'),
          _ReportListTab(statusFilter: 'resolved_rejected'),
        ],
      ),
    );
  }
}

class _ReportListTab extends ConsumerWidget {
  const _ReportListTab({required this.statusFilter});

  final String statusFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(moderationReportsProvider(statusFilter));

    return reportsAsync.when(
      data: (reports) {
        if (reports.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shield_outlined,
                    size: 56,
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'No tienes denuncias en esta lista',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Aquí verás el progreso y la resolución de tus reportes de contenido.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(moderationReportsProvider(statusFilter));
          },
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: reports.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final report = reports[index];
              return _ReportStatusCard(report: report);
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Error al cargar tus denuncias: $err',
            textAlign: TextAlign.center,
            style: const TextStyle(color: VibeColors.dangerRed),
          ),
        ),
      ),
    );
  }
}

class _ReportStatusCard extends StatelessWidget {
  const _ReportStatusCard({required this.report});

  final ContentReportModel report;

  String _formatTargetType(String type) {
    switch (type) {
      case 'message':
        return 'Mensaje de chat';
      case 'anonymous_message':
        return 'Mensaje anónimo';
      case 'group_photo':
        return 'Foto de grupo';
      case 'group':
        return 'Grupo';
      case 'user':
        return 'Usuario';
      default:
        return type;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'action_taken':
        return VibeColors.successGreen;
      case 'resolved_rejected':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  String _formatStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'En revisión';
      case 'action_taken':
        return 'Medida aplicada';
      case 'resolved_rejected':
        return 'Desestimado';
      default:
        return status;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.hourglass_top_rounded;
      case 'action_taken':
        return Icons.check_circle_rounded;
      case 'resolved_rejected':
        return Icons.remove_circle_outline_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year;
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(report.status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: VibeColors.primaryViolet.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _formatTargetType(report.targetType),
                  style: const TextStyle(
                    color: VibeColors.primaryViolet,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_getStatusIcon(report.status), size: 13, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      _formatStatusLabel(report.status),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Motivo: ${report.reason}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          if (report.details != null && report.details!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Detalles: ${report.details}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.groups_rounded, size: 15, color: VibeColors.primaryViolet),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  report.groupName != null ? 'Grupo: ${report.groupName}' : 'Grupo no disponible',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              Text(
                _formatDate(report.createdAt),
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          if (report.targetPreview != null && report.targetPreview!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                '"${report.targetPreview}"',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.9),
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: statusColor.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_getStatusIcon(report.status), size: 16, color: statusColor),
                    const SizedBox(width: 6),
                    Text(
                      'Estado de la solicitud',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  report.status == 'pending'
                      ? 'Tu denuncia ha sido registrada y está siendo evaluada por el equipo de administración.'
                      : report.status == 'action_taken'
                          ? 'Se tomaron medidas disciplinarias sobre el contenido y/o usuario reportado.'
                          : 'La denuncia fue revisada y desestimada al no detectarse infracción a las normas.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85),
                  ),
                ),
                if (report.moderatorNotes != null && report.moderatorNotes!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Nota del equipo: ${report.moderatorNotes}',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
