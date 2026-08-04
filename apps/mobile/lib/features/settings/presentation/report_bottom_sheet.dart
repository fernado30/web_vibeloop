import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/safety_repository.dart';

class ReportBottomSheet extends ConsumerStatefulWidget {
  const ReportBottomSheet({
    super.key,
    required this.targetType,
    required this.targetId,
    this.title,
    this.snippet,
  });

  final String targetType;
  final String targetId;
  final String? title;
  final String? snippet;

  static Future<bool?> show(
    BuildContext context, {
    required String targetType,
    required String targetId,
    String? title,
    String? snippet,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => ReportBottomSheet(
        targetType: targetType,
        targetId: targetId,
        title: title,
        snippet: snippet,
      ),
    );
  }

  @override
  ConsumerState<ReportBottomSheet> createState() => _ReportBottomSheetState();
}

class _ReportBottomSheetState extends ConsumerState<ReportBottomSheet> {
  final _detailsController = TextEditingController();
  String? _selectedReason;
  bool _isSubmitting = false;
  String? _errorMessage;

  static const _reasons = [
    'Spam o publicidad masiva',
    'Acoso, amenaza o intimidación',
    'Contenido explícito o inapropiado',
    'Discurso de odio o violencia',
    'Suicidio, autolesiones o peligro',
    'Información falsa o engaño',
    'Otro motivo',
  ];

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  String get _defaultTitle {
    switch (widget.targetType) {
      case 'message':
        return 'Denunciar mensaje';
      case 'anonymous_message':
        return 'Denunciar mensaje anónimo';
      case 'group_photo':
        return 'Denunciar foto de grupo';
      case 'group':
        return 'Denunciar grupo';
      case 'user':
        return 'Denunciar usuario';
      default:
        return 'Denunciar contenido';
    }
  }

  Future<void> _submitReport() async {
    final reason = _selectedReason;
    if (reason == null || reason.isEmpty) {
      setState(() {
        _errorMessage = 'Por favor selecciona un motivo para la denuncia.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final repository = ref.read(safetyRepositoryProvider);
      await repository.submitReport(
        targetType: widget.targetType,
        targetId: widget.targetId,
        reason: reason,
        details: _detailsController.text.trim(),
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gracias por tu denuncia. Nuestro equipo revisará este contenido en 24 horas.'),
          duration: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'No se pudo enviar la denuncia. Inténtalo de nuevo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Icon(
                  Icons.flag_rounded,
                  color: colorScheme.error,
                  size: 26,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.title ?? _defaultTitle,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
                ),
              ],
            ),
            if (widget.snippet != null && widget.snippet!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.snippet!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              '¿Por qué deseas denunciar este contenido?',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            ..._reasons.map((reason) {
              final isSelected = _selectedReason == reason;
              return InkWell(
                onTap: _isSubmitting
                    ? null
                    : () {
                        setState(() {
                          _selectedReason = reason;
                          _errorMessage = null;
                        });
                      },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Row(
                    children: [
                      Radio<String>(
                        value: reason,
                        groupValue: _selectedReason,
                        onChanged: _isSubmitting
                            ? null
                            : (val) {
                                setState(() {
                                  _selectedReason = val;
                                  _errorMessage = null;
                                });
                              },
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          reason,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 12),
            TextField(
              controller: _detailsController,
              enabled: !_isSubmitting,
              maxLines: 3,
              maxLength: 300,
              decoration: InputDecoration(
                hintText: 'Detalles adicionales opcionales...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _isSubmitting ? null : _submitReport,
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _isSubmitting
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.onError,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 20),
              label: Text(
                _isSubmitting ? 'Enviando denuncia...' : 'Enviar denuncia',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
