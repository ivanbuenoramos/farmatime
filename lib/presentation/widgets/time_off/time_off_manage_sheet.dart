import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/core/services/toast_service.dart';
import 'package:farmatime/core/utils/leave_dates_utils.dart';
import 'package:farmatime/data/models/schedule/time_off_model.dart';
import 'package:farmatime/domain/repositories/time_off_repository.dart';
import 'package:farmatime/domain/usecases/time_off/decide_time_off_usecase.dart';
import 'package:farmatime/domain/usecases/time_off/find_time_off_overlaps_usecase.dart';

/// Hoja modal que permite a la empresa gestionar una solicitud:
/// aprobar, rechazar o proponer fechas alternativas. Muestra un aviso
/// informativo de solapamientos con otros empleados.
///
/// Reutilizable desde el detalle de empleado y desde la pantalla global.
class TimeOffManageSheet extends StatefulWidget {
  const TimeOffManageSheet({
    super.key,
    required this.request,
    required this.employeeName,
    required this.decideUseCase,
    required this.overlapsUseCase,
    required this.decidedBy,
  });

  final TimeOffModel request;
  final String employeeName;
  final DecideTimeOffUseCase decideUseCase;
  final FindTimeOffOverlapsUseCase overlapsUseCase;
  final String decidedBy;

  /// Abre la hoja. Devuelve true si se realizó alguna acción.
  static Future<bool?> show(
    BuildContext context, {
    required TimeOffModel request,
    required String employeeName,
    required DecideTimeOffUseCase decideUseCase,
    required FindTimeOffOverlapsUseCase overlapsUseCase,
    required String decidedBy,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => TimeOffManageSheet(
        request: request,
        employeeName: employeeName,
        decideUseCase: decideUseCase,
        overlapsUseCase: overlapsUseCase,
        decidedBy: decidedBy,
      ),
    );
  }

  @override
  State<TimeOffManageSheet> createState() => _TimeOffManageSheetState();
}

class _TimeOffManageSheetState extends State<TimeOffManageSheet> {
  final ToastService _toast = ToastService();
  final Brain _brain = Get.find<Brain>();

  bool _loadingOverlaps = true;
  List<TimeOffOverlap> _overlaps = const [];
  bool _busy = false;

  final TextEditingController _noteCtrl = TextEditingController();
  List<String> _proposedDates = const [];

  TimeOffModel get _req => widget.request;

  @override
  void initState() {
    super.initState();
    _proposedDates = _req.effectiveDates;
    _loadOverlaps();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  String _nameFor(String employeeId) {
    final emp = _brain.companyEmployees
        .firstWhereOrNull((e) => e.uid == employeeId);
    return emp?.name ?? 'Otro empleado';
  }

  Future<void> _loadOverlaps() async {
    final res = await widget.overlapsUseCase.call(
      companyId: _req.companyId,
      excludeEmployeeId: _req.employeeId,
      dates: _req.effectiveDates,
    );
    if (!mounted) return;
    setState(() {
      _overlaps = res.success ? res.data : const [];
      _loadingOverlaps = false;
    });
  }

  Future<void> _approve() async {
    setState(() => _busy = true);
    final res = await widget.decideUseCase.companyApprove(
      request: _req,
      decidedBy: widget.decidedBy,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (res.success) {
      _toast.show(
        title: 'Solicitud aprobada',
        message: 'Los días se han marcado en el calendario del empleado.',
        type: ToastType.success,
      );
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _reject() async {
    setState(() => _busy = true);
    final note = _noteCtrl.text.trim();
    final res = await widget.decideUseCase.companyReject(
      request: _req,
      decidedBy: widget.decidedBy,
      companyNote: note.isEmpty ? null : note,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (res.success) {
      _toast.show(
        title: 'Solicitud rechazada',
        type: ToastType.info,
      );
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _propose() async {
    if (_proposedDates.isEmpty) {
      _toast.show(
        title: 'Sin fechas',
        message: 'Selecciona al menos un día para proponer.',
        type: ToastType.warning,
      );
      return;
    }
    setState(() => _busy = true);
    final note = _noteCtrl.text.trim();
    final res = await widget.decideUseCase.companyPropose(
      request: _req,
      proposedDates: _proposedDates,
      decidedBy: widget.decidedBy,
      companyNote: note.isEmpty ? null : note,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (res.success) {
      _toast.show(
        title: 'Propuesta enviada',
        message: 'El empleado deberá aceptarla o rechazarla.',
        type: ToastType.success,
      );
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _editProposedDates() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // No se proponen fechas en el pasado. Si la propuesta previa tenía días ya
    // pasados, los acotamos a hoy para que el picker no reviente.
    DateTime clampToday(DateTime d) => d.isBefore(today) ? today : d;
    final initial = _proposedDates.isNotEmpty
        ? clampToday(DateTime.parse(_proposedDates.first))
        : today;
    final last = _proposedDates.isNotEmpty
        ? clampToday(DateTime.parse(_proposedDates.last))
        : initial;

    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: initial, end: last),
      firstDate: today,
      lastDate: DateTime(now.year + 2, 12, 31),
      helpText: 'Propón un rango de fechas',
      saveText: 'Aceptar',
      locale: const Locale('es', 'ES'),
    );
    if (picked != null) {
      setState(() => _proposedDates = expandRange(picked.start, picked.end));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canActAsCompany = _req.awaitingCompany;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _req.type == TimeOffType.vacation
                      ? Icons.beach_access_rounded
                      : Icons.event_available_rounded,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_req.type.label} · ${widget.employeeName}',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            _kv(theme, 'Fechas solicitadas', formatDatesSummary(_req.dates)),
            if (_req.note != null && _req.note!.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              _kv(theme, 'Nota del empleado', '“${_req.note!.trim()}”'),
            ],

            const SizedBox(height: 16),

            // Aviso de solapamientos
            _OverlapsBanner(
              loading: _loadingOverlaps,
              overlaps: _overlaps,
              nameResolver: _nameFor,
            ),

            const SizedBox(height: 16),

            if (canActAsCompany) ...[
              Text('Contrapropuesta (opcional)',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              InkWell(
                onTap: _busy ? null : _editProposedDates,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.dividerColor),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.date_range, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          formatDatesSummary(_proposedDates),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      const Icon(Icons.edit, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Mensaje para el empleado (opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              if (_busy)
                const Center(child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: CircularProgressIndicator(),
                ))
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                          side: BorderSide(color: theme.colorScheme.error),
                        ),
                        onPressed: _reject,
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('Rechazar'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _propose,
                        icon: const Icon(Icons.swap_horiz_rounded),
                        label: const Text('Proponer'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _approve,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Aprobar'),
                  ),
                ),
              ],
            ] else ...[
              // No requiere acción de la empresa (p.ej. esperando al empleado)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _req.awaitingEmployee
                      ? 'Has propuesto fechas alternativas. Esperando la respuesta del empleado.'
                      : 'Esta solicitud ya está ${_req.status.label.toLowerCase()}.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _kv(ThemeData theme, String k, String v) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(k,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant)),
          Text(v, style: theme.textTheme.bodyMedium),
        ],
      );
}

class _OverlapsBanner extends StatelessWidget {
  final bool loading;
  final List<TimeOffOverlap> overlaps;
  final String Function(String employeeId) nameResolver;

  const _OverlapsBanner({
    required this.loading,
    required this.overlaps,
    required this.nameResolver,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (loading) {
      return Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text('Comprobando solapamientos…',
              style: theme.textTheme.bodySmall),
        ],
      );
    }

    if (overlaps.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xffD7F0E8),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline,
                size: 18, color: Color(0xff35B58D)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Ningún otro empleado tiene ausencias en estas fechas.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: const Color(0xff1E7E63)),
              ),
            ),
          ],
        ),
      );
    }

    // Agrupar por empleado para un resumen legible.
    final byEmployee = <String, List<TimeOffOverlap>>{};
    for (final o in overlaps) {
      byEmployee.putIfAbsent(o.employeeId, () => []).add(o);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xffFFECD5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  size: 18, color: Color(0xffFF9F2E)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Coincide con ausencias de otros empleados:',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xff8A4B00),
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...byEmployee.entries.map((e) {
            final dates = e.value.map((o) => o.date).toList()..sort();
            final type = e.value.first.type.label;
            final pendiente = e.value.any((o) => o.status != TimeOffStatus.approved);
            return Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '• ${nameResolver(e.key)} · $type${pendiente ? ' (pendiente)' : ''} · ${formatDatesSummary(dates)}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: const Color(0xff8A4B00)),
              ),
            );
          }),
        ],
      ),
    );
  }
}
