import 'package:farmatime/data/models/clock_audit_log_model.dart';
import 'package:farmatime/domain/usecases/clock/get_clock_audit_log_usecase.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

/// Muestra el historial completo e inmutable de cambios de un fichaje.
///
/// Cada entrada del log de auditoría se presenta como un evento cronológico
/// (creación / edición), indicando quién, cuándo, por qué y qué cambió
/// (valor anterior → valor nuevo). Pensado para cumplir y demostrar la
/// trazabilidad exigida por la normativa de registro horario.
Future<void> showClockAuditHistoryModal({
  required BuildContext context,
  required String entryId,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _ClockAuditHistorySheet(entryId: entryId),
  );
}

class _ClockAuditHistorySheet extends StatefulWidget {
  final String entryId;

  const _ClockAuditHistorySheet({required this.entryId});

  @override
  State<_ClockAuditHistorySheet> createState() =>
      _ClockAuditHistorySheetState();
}

class _ClockAuditHistorySheetState extends State<_ClockAuditHistorySheet> {
  late Future<List<ClockAuditLogModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = Get.find<GetClockAuditLogUseCase>().call(widget.entryId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) {
        return Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.history_rounded,
                      color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Historial de cambios',
                      style: theme.textTheme.headlineMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close,
                        color: theme.colorScheme.secondary),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Registro inmutable de auditoría de este fichaje.',
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: FutureBuilder<List<ClockAuditLogModel>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return _CenteredMessage(
                      icon: Icons.error_outline,
                      message: 'No se pudo cargar el historial',
                    );
                  }

                  final logs = snapshot.data ?? const [];
                  if (logs.isEmpty) {
                    return const _CenteredMessage(
                      icon: Icons.history_toggle_off,
                      message: 'Aún no hay cambios registrados',
                    );
                  }

                  return ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    itemCount: logs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      // Mostramos el más reciente arriba.
                      final log = logs[logs.length - 1 - index];
                      return _AuditEntryCard(log: log);
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AuditEntryCard extends StatelessWidget {
  final ClockAuditLogModel log;

  const _AuditEntryCard({required this.log});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fDateTime = DateFormat('d/M/y · HH:mm:ss', 'es_ES');

    final isCreation = log.action == ClockAuditAction.created;
    final accent = isCreation ? Colors.green : Colors.orange;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.outline.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCreation ? Icons.add_circle_outline : Icons.edit_outlined,
                size: 18,
                color: accent,
              ),
              const SizedBox(width: 6),
              Text(
                isCreation ? 'Fichaje creado' : 'Fichaje editado',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
              const Spacer(),
              Text(
                fDateTime.format(log.at),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Por ${_actorLabel(log)}',
            style: theme.textTheme.bodySmall?.copyWith(
              fontStyle: FontStyle.italic,
            ),
          ),
          if ((log.reason ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.notes_rounded, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    log.reason!,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ],
          if (log.changes.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...log.changes.map((c) => _ChangeRow(change: c)),
          ],
        ],
      ),
    );
  }

  static String _actorLabel(ClockAuditLogModel log) {
    final role = log.actorRole == 'company'
        ? 'farmacia'
        : log.actorRole == 'employee'
            ? 'empleado'
            : log.actorRole;
    final name = (log.actorName ?? '').trim();
    return name.isNotEmpty ? '$name ($role)' : role;
  }
}

class _ChangeRow extends StatelessWidget {
  final ClockAuditChange change;

  const _ChangeRow({required this.change});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.arrow_right_alt_rounded, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: theme.textTheme.bodySmall,
                children: [
                  TextSpan(
                    text: '${_fieldLabel(change.field)}: ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(
                    text: _formatValue(change.oldValue),
                    style: const TextStyle(
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  const TextSpan(text: '  →  '),
                  TextSpan(
                    text: _formatValue(change.newValue),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _fieldLabel(String field) {
    switch (field) {
      case 'clockIn':
        return 'Entrada';
      case 'clockOut':
        return 'Salida';
      default:
        return field;
    }
  }

  static String _formatValue(dynamic value) {
    if (value == null) return 'sin registrar';
    if (value is DateTime) {
      return DateFormat('d/M/y HH:mm').format(value);
    }
    return value.toString();
  }
}

class _CenteredMessage extends StatelessWidget {
  final IconData icon;
  final String message;

  const _CenteredMessage({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 40,
                color: theme.colorScheme.onSurface.withOpacity(0.5)),
            const SizedBox(height: 12),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
