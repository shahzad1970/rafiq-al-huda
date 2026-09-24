import 'dart:math' as math;

/// Initial great-circle bearing toward the Kaaba, clockwise from true north.
class QiblaDirection {
  const QiblaDirection(this.bearing, this.distanceMeters);
  final double bearing, distanceMeters;
  static QiblaDirection? from(double latitude, double longitude) {
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude.abs() > 90 ||
        longitude.abs() > 180) {
      throw ArgumentError('Invalid coordinates');
    }
    final lat = latitude * math.pi / 180, target = 21.422487 * math.pi / 180;
    final difference = (39.826206 - longitude) * math.pi / 180;
    final y = math.sin(difference) * math.cos(target);
    final x =
        math.cos(lat) * math.sin(target) -
        math.sin(lat) * math.cos(target) * math.cos(difference);
    final a =
        math.pow(math.sin((target - lat) / 2), 2) +
        math.cos(lat) *
            math.cos(target) *
            math.pow(math.sin(difference / 2), 2);
    final distance = 6371008.8 * 2 * math.asin(math.sqrt(a.clamp(0, 1)));
    // Coincident/antipodal points have no unique initial bearing.
    if (x * x + y * y < 1e-16) return null;
    return QiblaDirection((math.atan2(y, x) * 180 / math.pi) % 360, distance);
  }
}

double shortestTurn(double from, double to) => (to - from + 540) % 360 - 180;

class CompassSample {
  const CompassSample({
    required this.heading,
    required this.accuracy,
    required this.latitude,
    required this.longitude,
    required this.locationAccuracy,
    required this.headingTime,
    required this.locationTime,
  });
  final double heading, accuracy, latitude, longitude, locationAccuracy;
  final DateTime headingTime, locationTime;
  factory CompassSample.fromMap(Map<dynamic, dynamic> data) => CompassSample(
    heading: (data['heading'] as num).toDouble(),
    accuracy: (data['accuracy'] as num).toDouble(),
    latitude: (data['latitude'] as num).toDouble(),
    longitude: (data['longitude'] as num).toDouble(),
    locationAccuracy: (data['locationAccuracy'] as num).toDouble(),
    headingTime: DateTime.fromMillisecondsSinceEpoch(
      (data['headingTime'] as num).round(),
    ),
    locationTime: DateTime.fromMillisecondsSinceEpoch(
      (data['locationTime'] as num).round(),
    ),
  );
  bool usable(DateTime now) =>
      [
        heading,
        accuracy,
        latitude,
        longitude,
        locationAccuracy,
      ].every((n) => n.isFinite) &&
      heading >= 0 &&
      heading < 360 &&
      accuracy >= 0 &&
      accuracy <= 25 &&
      latitude.abs() <= 90 &&
      longitude.abs() <= 180 &&
      locationAccuracy >= 0 &&
      locationAccuracy <= 5000 &&
      now.difference(headingTime).inMilliseconds >= -2000 &&
      now.difference(headingTime).inSeconds <= 10 &&
      now.difference(locationTime).inMilliseconds >= -2000 &&
      now.difference(locationTime).inSeconds <= 120;
}

/// Circular smoothing avoids a full turn when crossing 359°/0°.
class HeadingFilter {
  double? value;
  double update(double heading) {
    value = value == null
        ? heading
        : value! + shortestTurn(value!, heading) * 0.3;
    return value!;
  }

  void reset() {
    value = null;
  }
}
