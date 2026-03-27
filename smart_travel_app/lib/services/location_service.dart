import 'package:geolocator/geolocator.dart';

class LocationPoint {
  final double latitude;
  final double longitude;

  const LocationPoint({required this.latitude, required this.longitude});
}

class LocationService {
  static final List<LocationPoint> _mockRoute = [
    LocationPoint(latitude: 17.3850, longitude: 78.4867),
    LocationPoint(latitude: 17.3862, longitude: 78.4891),
    LocationPoint(latitude: 17.3878, longitude: 78.4922),
    LocationPoint(latitude: 17.3895, longitude: 78.4950),
    LocationPoint(latitude: 17.3910, longitude: 78.4976),
  ];

  static int _mockIndex = 0;

  static Future<LocationPoint?> getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return _nextMockLocation();
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return _nextMockLocation();
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      return LocationPoint(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (_) {
      return _nextMockLocation();
    }
  }

  static LocationPoint _nextMockLocation() {
    final point = _mockRoute[_mockIndex % _mockRoute.length];
    _mockIndex += 1;
    return point;
  }
}
