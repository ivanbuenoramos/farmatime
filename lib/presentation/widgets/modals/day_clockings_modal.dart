// lib/presentation/pages/company/entries/day_clockings_modal.dart

import 'dart:async';
import 'dart:ui' as ui;

import 'package:farmatime/data/models/clock_in_out_model.dart';
import 'package:farmatime/presentation/pages/company/edit_entry/edit_entry_binding.dart';
import 'package:farmatime/presentation/pages/company/edit_entry/edit_entry_page.dart';
import 'package:farmatime/presentation/widgets/card/base_card.dart';
import 'package:farmatime/presentation/widgets/card/profile_avatar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

Future<void> showClockingsDayModal({
  required BuildContext context,
  required String employeeName,
  String? employeeEmail,
  required DateTime day,
  required List<ClockInOutModel> records,
}) async {
  if (records.isEmpty) return;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _DayClockingsSheet(
      employeeName: employeeName,
      employeeEmail: employeeEmail,
      day: day,
      records: records,
    ),
  );
}

class _DayClockingsSheet extends StatefulWidget {
  final String employeeName;
  final String? employeeEmail;
  final DateTime day;
  final List<ClockInOutModel> records;

  const _DayClockingsSheet({
    required this.employeeName,
    required this.day,
    required this.records,
    this.employeeEmail,
  });

  @override
  State<_DayClockingsSheet> createState() => _DayClockingsSheetState();
}

class _DayClockingsSheetState extends State<_DayClockingsSheet> {
  final Completer<GoogleMapController> _mapCtrl = Completer();
  final Set<Marker> _markers = {};
  LatLng? _initialTarget;
  double _initialZoom = 13;

  @override
  void initState() {
    super.initState();
    _prepareMap();
  }

  Future<void> _prepareMap() async {
    final allPoints = <LatLng>[];
    int n = 1;

    // Ordenamos por clockIn asc para numerar de forma coherente
    final shifts = [...widget.records]
      ..sort((a, b) => a.clockIn.compareTo(b.clockIn));

    for (final s in shifts) {
      final inLL = _toLatLng(s.clockInLat, s.clockInLng);
      if (inLL != null) {
        allPoints.add(inLL);
        final icon =
            await _buildNumberedMarkerIcon(number: n, color: Colors.blue);
        _markers.add(
          Marker(
            markerId: MarkerId('in_${s.id}'),
            position: inLL,
            icon: icon,
            infoWindow: const InfoWindow(title: 'Entrada'),
          ),
        );
        n++;
      }

      final outLL = _toLatLng(s.clockOutLat, s.clockOutLng);
      if (outLL != null) {
        allPoints.add(outLL);
        final icon =
            await _buildNumberedMarkerIcon(number: n, color: Colors.red);
        _markers.add(
          Marker(
            markerId: MarkerId('out_${s.id}'),
            position: outLL,
            icon: icon,
            infoWindow: const InfoWindow(title: 'Salida'),
          ),
        );
        n++;
      }
    }

    if (allPoints.isNotEmpty) {
      _initialTarget = allPoints.first;
    } else {
      // Fallback genérico (España)
      _initialTarget = const LatLng(40.4168, -3.7038);
      _initialZoom = 4;
    }

    if (allPoints.length >= 2) {
      await Future.delayed(const Duration(milliseconds: 80));
      final ctrl = await _mapCtrl.future;
      ctrl.animateCamera(
        CameraUpdate.newLatLngBounds(_bounds(allPoints), 60),
      );
    }

    if (mounted) setState(() {});
  }

  LatLng? _toLatLng(double? lat, double? lng) {
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
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

    final fill = Paint()..color = color;
    canvas.drawCircle(Offset(radius, radius), radius, fill);

    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    canvas.drawCircle(Offset(radius, radius), radius - 2.5, border);

    final tp = TextPainter(
      text: TextSpan(
        text: number.toString(),
        style: const TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(radius - tp.width / 2, radius - tp.height / 2),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(diameter, diameter);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  String _formatDuration(int minutes) {
    if (minutes <= 0) return '0 min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0 && m > 0) return '${h}h ${m}min';
    if (h > 0) return '${h}h';
    return '$m min';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fDay = DateFormat('EEEE, d MMM y', 'es_ES');
    final fTime = DateFormat('HH:mm');

    final shifts = [...widget.records]
      ..sort((a, b) => a.clockIn.compareTo(b.clockIn));

    final now = DateTime.now();
    final totalMinutes = shifts.fold<int>(0, (prev, s) {
      final end = s.clockOut ?? now;
      final diff = end.difference(s.clockIn).inMinutes;
      return prev + diff.clamp(0, 24 * 60);
    });

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.6,
      maxChildSize: 0.96,
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

            // Header empleado + día
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  ProfileAvatar(
                    name: widget.employeeName,
                    size: 50,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.employeeName,
                          style: theme.textTheme.headlineMedium
                        ),
                        const SizedBox(height: 4),
                        Text(
                          fDay.format(widget.day),
                          style: theme.textTheme.bodyMedium
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: Get.theme.colorScheme.secondary),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  
                  BaseCard(
                    title: 'Resumen del día', 
                    children: [
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time_filled,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Tiempo trabajado: ${_formatDuration(totalMinutes)}',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.playlist_add_check_rounded,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Fichajes registrados: ${shifts.length}',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Card mapa ubicaciones
                  BaseCard(
                    title: 'Ubicaciones',
                    children: [
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text('Entrada',
                              style: theme.textTheme.bodySmall),
                          const SizedBox(width: 16),
                          Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text('Salida',
                              style: theme.textTheme.bodySmall),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 240,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: (_initialTarget == null ||
                                  _markers.isEmpty)
                              ? const _EmptyMapPlaceholder(
                                  message:
                                      'Sin ubicaciones registradas',
                                )
                              : GoogleMap(
                                  initialCameraPosition:
                                      CameraPosition(
                                    target: _initialTarget!,
                                    zoom: _initialZoom,
                                  ),
                                  onMapCreated: (c) => _mapCtrl.complete(c),
                                  markers: _markers,
                                  mapType: MapType.normal,
                                  myLocationButtonEnabled: false,
                                  zoomControlsEnabled: true,
                                  compassEnabled: false,
                                  mapToolbarEnabled: false,
                                  liteModeEnabled: false,
                                ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Lista de fichajes del día
                  BaseCard(
                    title: 'Fichajes',
                    actions: [Text('Pulsa para editar un fichaje')],
                    children: [
                      const SizedBox(height: 8),
                      ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: shifts.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final s = shifts[index];
                          final inTxt = fTime.format(s.clockIn);
                          final outTxt = s.clockOut == null ? '—' : fTime.format(s.clockOut!);
                          final end = s.clockOut ?? now;
                          final worked = end
                            .difference(s.clockIn)
                            .inMinutes
                            .clamp(0, 24 * 60);
                          final textTheme = Theme.of(context).textTheme;
                          final colorScheme = Theme.of(context).colorScheme;
                          return InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () async {
                              EditEntryBinding().dependencies();
                              final updated = await showModalBottomSheet<ClockInOutModel?>(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => EditEntryModal(entry: s),
                              );
                              if (updated != null) {
                                final i = widget.records.indexWhere((r) => r.id == updated.id);
                                if (i != -1) {
                                  setState(() {
                                    widget.records[i] = updated;
                                  });
                                }
                              }
                            },
                            child: Ink(
                              decoration: BoxDecoration(
                                color: colorScheme.outline.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: s.isEdited
                                      ? Colors.orange.withOpacity(0.6)
                                      : colorScheme.outline,
                                ),
                              ),
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.access_time_filled,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '$inTxt  –  $outTxt',
                                              style: textTheme.bodyMedium?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const Spacer(),
                                            if (s.isEdited)
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange.withOpacity(0.12),
                                                  borderRadius: BorderRadius.circular(999),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.edit,
                                                      size: 14,
                                                      color: Colors.orange,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      'Editado',
                                                      style: textTheme.bodySmall?.copyWith(
                                                        color: Colors.orange,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),
                                    
                                        const SizedBox(height: 6),
                                    
                                        // Duración
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.timer_outlined,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              _formatDuration(worked),
                                              style: textTheme.bodyMedium,
                                            ),
                                          ],
                                        ),
                                    
                                        // Motivo de edición
                                        if (s.isEdited && (s.editReason?.isNotEmpty ?? false)) ...[
                                          const SizedBox(height: 8),
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Icon(
                                                Icons.notes_rounded,
                                                size: 18,
                                                color: Colors.orange,
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  s.editReason!,
                                                  style: textTheme.bodySmall?.copyWith(
                                                    color:
                                                        textTheme.bodySmall?.color?.withOpacity(0.9),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Editado por ${
                                              s.editedBy == 'company' 
                                                ? 'farmacia' 
                                                : s.editedBy == 'employee'
                                                    ? 'empleado' 
                                                    : s.editedBy ?? 'desconocido' 
                                            } el ${s.editedAt != null ? DateFormat('d/M/y - HH:mm').format(s.editedAt!) : 'desconocida'}',
                                            style: textTheme.bodySmall?.copyWith(
                                              fontStyle: FontStyle.italic,
                                            ),  
                                          )
                                        ],
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.edit,
                                    color: Get.theme.colorScheme.primary,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // static String _formatLatLng(double? lat, double? lng) {
  //   if (lat == null || lng == null) return 'Sin ubicación';
  //   return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
  // }
}

class _EmptyMapPlaceholder extends StatelessWidget {
  final String message;
  const _EmptyMapPlaceholder({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surface,
      child: Center(
        child: Text(
          message,
          style: theme.textTheme.bodyMedium?.copyWith(
            color:
                theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ),
    );
  }
}