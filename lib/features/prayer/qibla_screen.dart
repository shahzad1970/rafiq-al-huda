import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/prayer/prayer_schedule.dart';
import '../../core/prayer/qibla.dart';

const qiblaChannel = EventChannel('org.quranteacher/qibla');

class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key, this.location, this.readings});
  final PrayerLocation? location;
  // Injectable sensor stream for UI tests, never simulated by production code.
  final Stream<dynamic>? readings;
  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> with WidgetsBindingObserver {
  StreamSubscription<dynamic>? subscription;
  Timer? timer;
  final filter = HeadingFilter();
  CompassSample? sample;
  String status = 'Compass is off';
  bool requested = false;
  int generation = 0;
  String? orientation;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_start());
  }

  Future<void> _start() async {
    final token = ++generation;
    await subscription?.cancel();
    if (!mounted || token != generation) return;
    setState(() {
      requested = true;
      sample = null;
      filter.reset();
      status = 'Finding true north…';
    });
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    subscription = (widget.readings ?? qiblaChannel.receiveBroadcastStream())
        .listen(
          (event) {
            if (!mounted || token != generation) return;
            try {
              final data = event as Map;
              if (data['state'] != 'reading') {
                setState(() {
                  sample = null;
                  filter.reset();
                  status = data['message'] as String? ?? 'Waiting for compass…';
                });
                return;
              }
              final next = CompassSample.fromMap(data);
              setState(() {
                if (sample == null ||
                    !sample!.usable(DateTime.now()) ||
                    orientation != data['orientation']) {
                  filter.reset();
                }
                orientation = data['orientation'] as String?;
                sample = next;
                if (next.usable(DateTime.now())) {
                  filter.update(next.heading);
                } else {
                  filter.reset();
                }
                status = 'Move away from metal or magnetic cases and gently move the phone in a figure eight.';
              });
            } catch (_) {
              setState(() {
                sample = null;
                filter.reset();
                status = 'Compass data unavailable. Try again.';
              });
            }
          },
          onError: (_) {
            if (mounted && token == generation) {
              setState(() {
                sample = null;
                status = 'Compass unavailable. A physical iPhone and location permission are required.';
              });
            }
          },
        );
  }

  void _stop({bool keepRequested = false}) {
    generation++;
    unawaited(subscription?.cancel());
    subscription = null;
    timer?.cancel();
    timer = null;
    sample = null;
    filter.reset();
    if (!keepRequested) requested = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _stop(keepRequested: true);
    }
    if (state == AppLifecycleState.resumed && requested) {
      _start();
    }
  }

  @override
  void dispose() {
    _stop();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final usable = sample?.usable(now) == true && filter.value != null;
    final direction = usable
        ? QiblaDirection.from(sample!.latitude, sample!.longitude)
        : widget.location == null
        ? null
        : QiblaDirection.from(
            widget.location!.latitude,
            widget.location!.longitude,
          );
    final reliable =
        usable &&
        direction != null &&
        direction.distanceMeters > math.max(100, sample!.locationAccuracy * 5);
    final delta = reliable
        ? shortestTurn(filter.value!, direction.bearing)
        : null;
    final aligned =
        reliable &&
        delta!.abs() <= 5 &&
        sample!.accuracy <= 15 &&
        shortestTurn(sample!.heading, direction.bearing).abs() <= 5;
    final colors = Theme.of(context).colorScheme;
    String message;
    if (!requested) {
      message = 'Find your Qibla';
    } else if (usable && !reliable) {
      message = 'Too close to the Kaaba or location uncertainty is too large for a reliable direction.';
    } else if (!usable) {
      message =
          sample != null && now.difference(sample!.headingTime).inSeconds > 10
          ? 'Compass reading is stale. Move the phone gently or restart.'
          : status;
    } else if (aligned) {
      message = 'Approximately aligned with Qibla';
    } else {
      message =
          'Turn ${delta! >= 0 ? 'right' : 'left'} ${delta.abs().round()}°';
    }
    return PopScope<void>(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) _stop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Qibla Compass'),
          actions: [
            IconButton(
              tooltip: 'Compass help',
              icon: const Icon(Icons.info_outline_rounded),
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                showDragHandle: true,
                useSafeArea: true,
                isScrollControlled: true,
                builder: (context) => SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 36),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Using the compass',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Hold your phone flat. When the arrow points straight up, face the direction of the phone’s top edge.\n\nKeep away from magnets, speakers and metal. If readings are unreliable, gently move the phone in a figure eight.\n\nThe direction uses true north and your current location, without changing your saved prayer location. Compass and location stop when you leave. No readings are saved or uploaded.',
                        style: TextStyle(fontSize: 17, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                usable
                    ? 'Current location'
                    : widget.location?.name ?? 'Current location',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(color: colors.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                direction == null
                    ? (sample == null ? '—' : 'Direction unavailable here')
                    : '${direction.bearing.round() % 360}°',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displaySmall
                    ?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -1),
              ),
              const SizedBox(height: 24),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Semantics(
                      label: reliable
                          ? 'Qibla: $message'
                          : 'Compass arrow unavailable',
                      child: CustomPaint(
                        painter: _CompassPainter(
                          heading: reliable ? filter.value : null,
                          turn: delta,
                          color: colors.primary,
                          muted: colors.outline.withValues(alpha: 0.65),
                          surface: colors.surfaceContainerLow,
                          labelStyle: Theme.of(context).textTheme.bodyLarge!
                              .copyWith(
                                color: colors.outline,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                aligned ? 'Facing Qibla' : message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: aligned ? colors.primary : colors.onSurface,
                ),
              ),
              if (reliable)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${aligned ? 'Approximate · ' : ''}±${sample!.accuracy.round()}° accuracy',
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 24),
              if (requested && !reliable)
                TextButton(onPressed: _start, child: const Text('Try again')),
              const SizedBox(height: 16),
              Text(
                'Hold your phone flat',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompassPainter extends CustomPainter {
  const _CompassPainter({
    required this.heading,
    required this.turn,
    required this.color,
    required this.muted,
    required this.surface,
    required this.labelStyle,
  });
  final double? heading, turn;
  final Color color, muted, surface;
  final TextStyle labelStyle;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero),
        radius = size.shortestSide / 2 - 12;
    canvas.drawCircle(center, radius, Paint()..color = surface);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = muted.withValues(alpha: 0.20)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawCircle(
      center,
      radius * 0.70,
      Paint()..color = color.withValues(alpha: 0.06),
    );
    final paint = Paint()
      ..color = muted
      ..strokeWidth = 1.5;
    for (var i = 0; i < 72; i++) {
      final angle = (i * 5 - (heading ?? 0) - 90) * math.pi / 180;
      Offset point(double r) =>
          center + Offset(math.cos(angle) * r, math.sin(angle) * r);
      canvas.drawLine(
        point(radius - 5),
        point(radius - (i % 6 == 0 ? 18 : 10)),
        paint,
      );
    }
    if (heading != null) {
      for (var i = 0; i < 4; i++) {
        final angle = (i * 90 - heading! - 90) * math.pi / 180;
        final label = TextPainter(
          text: TextSpan(text: ['N', 'E', 'S', 'W'][i], style: labelStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        label.paint(
          canvas,
          center +
              Offset(
                math.cos(angle) * (radius - 36),
                math.sin(angle) * (radius - 36),
              ) -
              Offset(label.width / 2, label.height / 2),
        );
      }
    }
    // Fixed top-edge indicator. No directional arrow without usable real sensors.
    canvas.drawLine(
      Offset(center.dx, 0),
      Offset(center.dx, 15),
      Paint()
        ..color = color
        ..strokeWidth = 4,
    );
    if (turn != null) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(turn! * math.pi / 180);
      final path = Path()
        ..moveTo(0, -radius * 0.60)
        ..lineTo(23, 10)
        ..lineTo(0, -1)
        ..lineTo(-23, 10)
        ..close();
      canvas.drawPath(path, Paint()..color = color);
      canvas.drawLine(
        const Offset(0, 4),
        Offset(0, radius * 0.37),
        Paint()
          ..color = color
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round,
      );
      canvas.restore();
    } else {
      canvas.drawCircle(center, 7, Paint()..color = muted);
    }
  }

  @override
  bool shouldRepaint(covariant _CompassPainter old) =>
      labelStyle != old.labelStyle ||
      heading != old.heading ||
      turn != old.turn ||
      color != old.color ||
      muted != old.muted ||
      surface != old.surface;
}
