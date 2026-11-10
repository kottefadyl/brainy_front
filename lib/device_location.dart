import 'package:geolocator/geolocator.dart';

/// Why a device position could not be read.
enum LocationFailure { serviceOff, denied, deniedForever, timeout, unavailable }

class DeviceLocation {
  const DeviceLocation.found(this.latitude, this.longitude, this.accuracy) : failure = null;
  const DeviceLocation.failed(this.failure) : latitude = 0, longitude = 0, accuracy = 0;

  final double latitude;
  final double longitude;

  /// Metres, as reported by the device.
  final double accuracy;
  final LocationFailure? failure;
}

/// Reads the device position once (T38/3). Product rule 13: only called
/// when the person presses "Use my location"; permission is asked then.
typedef LocateDevice = Future<DeviceLocation> Function();

Future<DeviceLocation> locateDevice() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return const DeviceLocation.failed(LocationFailure.serviceOff);
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.deniedForever) return const DeviceLocation.failed(LocationFailure.deniedForever);
    if (permission == LocationPermission.denied || permission == LocationPermission.unableToDetermine) return const DeviceLocation.failed(LocationFailure.denied);
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)),
    );
    return DeviceLocation.found(position.latitude, position.longitude, position.accuracy);
  } on LocationServiceDisabledException {
    return const DeviceLocation.failed(LocationFailure.serviceOff);
  } on PermissionDeniedException {
    return const DeviceLocation.failed(LocationFailure.denied);
  } catch (error) {
    return DeviceLocation.failed(error.runtimeType.toString().contains('Timeout') ? LocationFailure.timeout : LocationFailure.unavailable);
  }
}
