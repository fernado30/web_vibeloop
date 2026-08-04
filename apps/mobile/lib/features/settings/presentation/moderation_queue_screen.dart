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
  return safetyRepo.fetchModerationReports(statusFilter: statusFilter);
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
          'Cola de moderación',
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
            Tab(text: 'Sancionados'),
            Tab(text: 'Desestimados'),
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 48,
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 12),
                Text(
                  'No hay denuncias en esta lista',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
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
              return _ReportCard(
                report: report,
                onRefresh: () {
                  ref.invalidate(moderationReportsProvider('pending'));
                  ref.invalidate(moderationReportsProvider('action_taken'));
                  ref.invalidate(moderationReportsProvider('resolved_rejected'));
                },
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Error al cargar denuncias: $err',
            textAlign: TextAlign.center,
            style: const TextStyle(color: VibeColors.dangerRed),
          ),
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.report,
    required this.onRefresh,
  });

  final ContentReportModel report;
  final VoidCallback onRefresh;

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
        return VibeColors.dangerRed;
      case 'resolved_rejected':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  String _formatStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Pendiente';
      case 'action_taken':
        return 'Sancionado';
      case 'resolved_rejected':
        return 'Desestimado';
      default:
        return status;
    }
  }

  void _showResolutionSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return _ResolutionBottomSheet(
          report: report,
          onResolved: () {
            Navigator.of(modalContext).pop();
            onRefresh();
          },
        );
      },
    );
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _formatStatusLabel(report.status),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Motivo: ${report.reason}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          if (report.details != null && report.details!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Detalles: ${report.details}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.groups_rounded, size: 16, color: VibeColors.primaryViolet),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  report.groupName != null ? 'Grupo: ${report.groupName}' : 'Grupo no disponible',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
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
          if (report.moderatorNotes != null && report.moderatorNotes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Notas del moderador: ${report.moderatorNotes}',
                style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ),
          ],
          if (report.status == 'pending') ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _showResolutionSheet(context),
                icon: const Icon(Icons.gavel_rounded, size: 18),
                label: const Text('Resolver Denuncia'),
                style: FilledButton.styleFrom(
                  backgroundColor: VibeColors.primaryViolet,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResolutionBottomSheet extends ConsumerStatefulWidget {
  const _ResolutionBottomSheet({
    required this.report,
    required this.onResolved,
  });

  final ContentReportModel report;
  final VoidCallback onResolved;

  @override
  ConsumerState<_ResolutionBottomSheet> createState() => _ResolutionBottomSheetState();
}

class _ResolutionBottomSheetState extends ConsumerState<_ResolutionBottomSheet> {
  String _selectedAction = 'dismiss';
  final _notesController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitResolution() async {
    setState(() => _isSubmitting = true);
    try {
      final safetyRepo = ref.read(safetyRepositoryProvider);
      await safetyRepo.resolveReport(
        reportId: widget.report.id,
        action: _selectedAction,
        notes: _notesController.text.trim(),
        muteHours: _selectedAction == 'mute_user' ? 24 : 0,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Acción de moderación aplicada con éxito.')),
        );
        widget.onResolved();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al resolver denuncia: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomPadding),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Resolución de Denuncia',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Selecciona la medida disciplinaria o resolución:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            Column(
              children: [
                RadioListTile<String>(
                  value: 'dismiss',
                  groupValue: _selectedAction,
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedAction = val);
                  },
                  title: const Text('Desestimar (Sin infracción)'),
                  subtitle: const Text('La denuncia es rechazada y el contenido permanece'),
                ),
                RadioListTile<String>(
                  value: 'delete_content',
                  groupValue: _selectedAction,
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedAction = val);
                  },
                  title: const Text('Eliminar Contenido'),
                  subtitle: const Text('Remueve el contenido denunciado sin sancionar al usuario'),
                ),
                RadioListTile<String>(
                  value: 'warn_user',
                  groupValue: _selectedAction,
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedAction = val);
                  },
                  title: const Text('Advertir al Usuario'),
                  subtitle: const Text('Elimina contenido y registra una advertencia'),
                ),
                RadioListTile<String>(
                  value: 'mute_user',
                  groupValue: _selectedAction,
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedAction = val);
                  },
                  title: const Text('Silenciar Usuario (24h)'),
                  subtitle: const Text('Impide que el usuario publique mensajes por 24 horas'),
                ),
                RadioListTile<String>(
                  value: 'ban_user',
                  groupValue: _selectedAction,
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedAction = val);
                  },
                  title: const Text('Banear Usuario (Permanente)'),
                  subtitle: const Text('Suspende la cuenta del usuario de forma definitiva'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Notas operativas (opcional)',
                hintText: 'Explica la decisión o justificación para el registro auditable...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _submitResolution,
                style: FilledButton.styleFrom(
                  backgroundColor: VibeColors.primaryViolet,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Confirmar Resolución', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
