// Modal de detalle de un día del calendario del empleado (vista empresa).
// - Día futuro: muestra solo lo PREVISTO (tipo de día y horario).
// - Día pasado/hoy: compara lo PREVISTO con lo REALIZADO según fichajes.

import 'dart:async';
import 'dart:ui' as ui;

import 'package:farmatime/data/models/clock_in_out_model.dart';
import 'package:farmatime/data/models/schedule/day_entry.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

/// Estilo (color, icono, etiqueta) por tipo de día. Coincide con la paleta
/// del calendario y la pantalla de calendario del empleado.
({Color color, IconData icon, String label}) _styleForType(DayType t) {
  switch (t) {
    case DayType.work:
      return (
        color: const Color(0xff1971FF),
        icon: Icons.work_history_rounded,
        label: 'Jornada laboral',
      );
    case DayType.vacation:
      return (
        color: const Color(0xffE53935),
        icon: Icons.beach_access_rounded,
        label: 'Vacaciones',
      );
    case DayType.personal:
      return (
        color: const Color(0xff8E24AA),
        icon: Icons.event_note_rounded,
        label: 'Asuntos propios',
      );
    case DayType.off:
      return (
        color: const Color(0xffA5A5A5),
        icon: Icons.weekend_rounded,
        label: 'Día libre',
      );
  }
}

Future<void> showEmployeeDayDetailModal({
  required BuildContext context,
  required DateTime day,
  required DayEntry? expected,
  required List<ClockInOutModel> records,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _DayDetailSheet(
      day: day,
      expected: expected,
      records: records,
    ),
  );
}

// ── Helpers de formato ──────────────────────────────────────
String _fmtDuration(int minutes) {
  final m = minutes.abs();
  final h = m ~/ 60;
  final mm = m % 60;
  if (h > 0 && mm > 0) return '${h}h ${mm}min';
  if (h > 0) return '${h}h';
  return '$mm min';
}

String _fmtTime(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

String _fmtTimeDt(DateTime d) => DateFormat('HH:mm').format(d);

int? _expectedMinutes(DayEntry? e) {
  if (e == null || e.type != DayType.work) return null;
  if (e.start == null || e.end == null) return null;
  final s = e.start!.hour * 60 + e.start!.minute;
  final en = e.end!.hour * 60 + e.end!.minute;
  final mins = en >= s ? en - s : (24 * 60 - s + en);
  return mins <= 0 ? null : mins;
}

class _DayDetailSheet extends StatefulWidget {
  final DateTime day;
  final DayEntry? expected;
  final List<ClockInOutModel> records;

  const _DayDetailSheet({
    required this.day,
    required this.expected,
    required this.records,
  });

  @override
  State<_DayDetailSheet> createState() => _DayDetailSheetState();
}

class _DayDetailSheetState extends State<_DayDetailSheet> {
  final Completer<GoogleMapController> _mapCtrl = Completer();
  final Set<Marker> _markers = {};
  LatLng? _initialTarget;
  final double _initialZoom = 14;

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  bool get _isFuture {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(widget.day.year, widget.day.month, widget.day.day);
    return d.isAfter(today);
  }

  bool get _hasLocations => widget.records.any((r) =>
      (r.clockInLat != null && r.clockInLng != null) ||
      (r.clockOutLat != null && r.clockOutLng != null));

  /// Puntos (entradas/salidas) del día, ya ordenados. Se calcula de forma
  /// síncrona para poder montar el mapa desde el primer frame.
  final List<LatLng> _points = [];

  @override
  void initState() {
    super.initState();
    if (!_isFuture && _hasLocations) {
      _collectPoints();
      // El target inicial es inmediato; los iconos se construyen aparte.
      _initialTarget = _points.isNotEmpty ? _points.first : null;
      _buildMarkers();
    }
  }

  LatLng? _toLatLng(double? lat, double? lng) {
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  void _collectPoints() {
    final shifts = [...widget.records]
      ..sort((a, b) => a.clockIn.compareTo(b.clockIn));
    for (final s in shifts) {
      final inLL = _toLatLng(s.clockInLat, s.clockInLng);
      if (inLL != null) _points.add(inLL);
      final outLL = _toLatLng(s.clockOutLat, s.clockOutLng);
      if (outLL != null) _points.add(outLL);
    }
  }

  /// Construye los iconos numerados (async) y los aplica con setState.
  Future<void> _buildMarkers() async {
    final markers = <Marker>{};
    int n = 1;

    final shifts = [...widget.records]
      ..sort((a, b) => a.clockIn.compareTo(b.clockIn));

    for (final s in shifts) {
      final inLL = _toLatLng(s.clockInLat, s.clockInLng);
      if (inLL != null) {
        final icon = await _buildNumberedMarkerIcon(
            number: n, color: const Color(0xff1971FF));
        markers.add(Marker(
          markerId: MarkerId('in_${s.id}'),
          position: inLL,
          icon: icon,
          infoWindow: const InfoWindow(title: 'Entrada'),
        ));
        n++;
      }

      final outLL = _toLatLng(s.clockOutLat, s.clockOutLng);
      if (outLL != null) {
        final icon = await _buildNumberedMarkerIcon(
            number: n, color: const Color(0xffE53935));
        markers.add(Marker(
          markerId: MarkerId('out_${s.id}'),
          position: outLL,
          icon: icon,
          infoWindow: const InfoWindow(title: 'Salida'),
        ));
        n++;
      }
    }

    if (!mounted) return;
    setState(() {
      _markers
        ..clear()
        ..addAll(markers);
    });
  }

  /// Encuadra todos los puntos cuando el mapa ya está creado.
  Future<void> _onMapCreated(GoogleMapController controller) async {
    if (!_mapCtrl.isCompleted) _mapCtrl.complete(controller);
    if (_points.length >= 2) {
      await Future.delayed(const Duration(milliseconds: 120));
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(_bounds(_points), 60),
      );
    }
  }

  LatLngBounds _bounds(List<LatLng> pts) {
    double minLat = pts.first.latitude, maxLat = pts.first.latitude;
    double minLng = pts.first.longitude, maxLng = pts.first.longitude;
    for (final p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  Future<BitmapDescriptor> _buildNumberedMarkerIcon({
    required int number,
    required Color color,
    int diameter = 74,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final radius = diameter / 2.0;

    canvas.drawCircle(Offset(radius, radius), radius, Paint()..color = color);
    canvas.drawCircle(
      Offset(radius, radius),
      radius - 2.5,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );

    final tp = TextPainter(
      text: TextSpan(
        text: '$number',
        style: const TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(radius - tp.width / 2, radius - tp.height / 2));

    final image =
        await recorder.endRecording().toImage(diameter, diameter);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final type = widget.expected?.type ?? DayType.off;
    final dateLabel = _capitalize(
      DateFormat("EEEE, d 'de' MMMM y", 'es_ES').format(widget.day),
    );

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.62,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, scrollController) {
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: [
            // Cabecera con fecha + chip futuro/pasado
            Row(
              children: [
                Expanded(
                  child: Text(
                    dateLabel,
                    style: theme.textTheme.headlineSmall?.copyWith(fontSize: 16),
                  ),
                ),
                _Badge(
                  label: _isFuture ? 'Previsto' : 'Resumen',
                  color: theme.colorScheme.tertiary,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Estado del día (tipo)
            _DayTypeBanner(type: type, expected: widget.expected),
            const SizedBox(height: 16),

            if (type == DayType.work) ...[
              if (_isFuture)
                _PlannedOnly(expected: widget.expected)
              else
                _PlannedVsActual(
                  expected: widget.expected,
                  records: widget.records,
                ),
            ] else if (!_isFuture && widget.records.isNotEmpty) ...[
              // Día no laborable pero con fichajes (p. ej. trabajó en su día libre)
              Text(
                'Fichajes de ese día',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.tertiary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              _ActualBlock(records: widget.records),
            ],

            // Mapa de ubicaciones (solo días pasados/hoy con coordenadas)
            if (!_isFuture && _hasLocations) ...[
              const SizedBox(height: 16),
              _LocationsCard(
                markers: _markers,
                initialTarget: _initialTarget,
                initialZoom: _initialZoom,
                onMapCreated: _onMapCreated,
              ),
            ],
          ],
        );
      },
    );
  }
}

// ── Tarjeta de ubicaciones (mapa) ───────────────────────────
class _LocationsCard extends StatelessWidget {
  final Set<Marker> markers;
  final LatLng? initialTarget;
  final double initialZoom;
  final void Function(GoogleMapController) onMapCreated;

  const _LocationsCard({
    required this.markers,
    required this.initialTarget,
    required this.initialZoom,
    required this.onMapCreated,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Ubicaciones',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.tertiary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            _LegendDot(color: theme.colorScheme.primary, label: 'Entrada'),
            const SizedBox(width: 12),
            _LegendDot(color: theme.colorScheme.error, label: 'Salida'),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 220,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: (initialTarget == null)
                ? Container(
                    color: theme.colorScheme.outline.withValues(alpha: 0.20),
                    child: const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: initialTarget!,
                      zoom: initialZoom,
                    ),
                    onMapCreated: onMapCreated,
                    markers: markers,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: true,
                    compassEnabled: false,
                    mapToolbarEnabled: false,
                  ),
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.secondary,
          ),
        ),
      ],
    );
  }
}

// ── Banner de tipo de día ───────────────────────────────────
class _DayTypeBanner extends StatelessWidget {
  final DayType type;
  final DayEntry? expected;
  const _DayTypeBanner({required this.type, required this.expected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = _styleForType(type);

    String subtitle;
    if (type == DayType.work) {
      if (expected?.start != null && expected?.end != null) {
        subtitle =
            'Horario previsto: ${_fmtTime(expected!.start!)} – ${_fmtTime(expected!.end!)}';
      } else {
        subtitle = 'Sin horario definido';
      }
    } else {
      switch (type) {
        case DayType.vacation:
          subtitle = 'Día de vacaciones';
          break;
        case DayType.personal:
          subtitle = 'Día de asuntos propios';
          break;
        default:
          subtitle = 'No tiene turno asignado';
      }
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: s.color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: s.color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: s.color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(s.icon, size: 22, color: s.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: s.color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.tertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Solo previsto (día futuro laboral) ──────────────────────
class _PlannedOnly extends StatelessWidget {
  final DayEntry? expected;
  const _PlannedOnly({required this.expected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mins = _expectedMinutes(expected);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Previsto',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.tertiary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        if (expected?.start != null && expected?.end != null)
          _InfoRow(
            icon: Icons.schedule_rounded,
            label: 'Horario',
            value:
                '${_fmtTime(expected!.start!)} – ${_fmtTime(expected!.end!)}',
          ),
        if (mins != null) ...[
          const SizedBox(height: 10),
          _InfoRow(
            icon: Icons.timelapse_rounded,
            label: 'Duración prevista',
            value: _fmtDuration(mins),
          ),
        ],
      ],
    );
  }
}

// ── Previsto vs realizado (día pasado/hoy laboral) ──────────
class _PlannedVsActual extends StatelessWidget {
  final DayEntry? expected;
  final List<ClockInOutModel> records;
  const _PlannedVsActual({required this.expected, required this.records});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plannedMin = _expectedMinutes(expected) ?? 0;
    final workedMin = records.fold<int>(0, (prev, r) {
      final end = r.clockOut ?? DateTime.now();
      return prev + end.difference(r.clockIn).inMinutes.clamp(0, 24 * 60);
    });
    final diff = workedMin - plannedMin; // + de más, - faltan

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Comparación previsto vs realizado
        Row(
          children: [
            Expanded(
              child: _CompareTile(
                label: 'Previsto',
                value: plannedMin > 0 ? _fmtDuration(plannedMin) : '—',
                color: theme.colorScheme.secondary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _CompareTile(
                label: 'Trabajado',
                value: _fmtDuration(workedMin),
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _DiffBanner(diffMinutes: diff, hasPlanned: plannedMin > 0),

        const SizedBox(height: 16),
        Text(
          records.isEmpty ? 'Fichajes' : 'Fichajes de ese día',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.tertiary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        if (records.isEmpty)
          _NoClockings()
        else
          _ActualBlock(records: records),
      ],
    );
  }
}

class _CompareTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _CompareTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.tertiary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiffBanner extends StatelessWidget {
  final int diffMinutes;
  final bool hasPlanned;
  const _DiffBanner({required this.diffMinutes, required this.hasPlanned});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!hasPlanned) {
      return _banner(
        theme,
        color: theme.colorScheme.tertiary,
        icon: Icons.info_outline_rounded,
        text: 'No había horario previsto para comparar.',
      );
    }
    if (diffMinutes == 0) {
      return _banner(
        theme,
        color: const Color(0xff16A34A),
        icon: Icons.check_circle_outline_rounded,
        text: 'Cumplió exactamente el horario previsto.',
      );
    }
    if (diffMinutes > 0) {
      return _banner(
        theme,
        color: const Color(0xff16A34A),
        icon: Icons.trending_up_rounded,
        text: 'Trabajó ${_fmtDuration(diffMinutes)} de más respecto a lo previsto.',
      );
    }
    return _banner(
      theme,
      color: theme.colorScheme.error,
      icon: Icons.trending_down_rounded,
      text: 'Faltaron ${_fmtDuration(diffMinutes)} respecto a lo previsto.',
    );
  }

  Widget _banner(ThemeData theme,
      {required Color color, required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Lista de turnos reales (fichajes) ───────────────────────
class _ActualBlock extends StatelessWidget {
  final List<ClockInOutModel> records;
  const _ActualBlock({required this.records});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: List.generate(records.length, (i) {
        final r = records[i];
        final isOpen = r.clockOut == null;
        final mins = (r.clockOut ?? DateTime.now())
            .difference(r.clockIn)
            .inMinutes
            .clamp(0, 24 * 60);

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outline),
          ),
          child: Row(
            children: [
              Icon(Icons.login_rounded,
                  size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                _fmtTimeDt(r.clockIn),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.secondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 10),
              Icon(Icons.arrow_forward_rounded,
                  size: 14, color: theme.colorScheme.tertiary),
              const SizedBox(width: 10),
              Icon(Icons.logout_rounded,
                  size: 16, color: theme.colorScheme.error),
              const SizedBox(width: 6),
              Text(
                isOpen ? 'En curso' : _fmtTimeDt(r.clockOut!),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isOpen
                      ? theme.colorScheme.tertiary
                      : theme.colorScheme.secondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                _fmtDuration(mins),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.tertiary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _NoClockings extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(Icons.do_not_disturb_on_outlined,
            size: 18, color: theme.colorScheme.tertiary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'No registró ningún fichaje ese día.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.tertiary,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Componentes pequeños ────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.tertiary),
        const SizedBox(width: 8),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.tertiary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.secondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
