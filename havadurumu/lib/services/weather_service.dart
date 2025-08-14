import 'package:dio/dio.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:havadurumu/models/weather_model.dart';

class WeatherService {
  Future<String> _getLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission must be granted');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permission is permanently denied');
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    final placemarks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );

    if (placemarks.isEmpty) {
      throw Exception('Could not resolve placemark');
    }

    // Bazı cihazlarda şehir "locality"de, bazılarında "administrativeArea"da olur
    final pm = placemarks.first;
    final city = pm.locality?.trim().isNotEmpty == true
        ? pm.locality!
        : (pm.subAdministrativeArea?.trim().isNotEmpty == true
              ? pm.subAdministrativeArea!
              : (pm.administrativeArea ?? ''));

    if (city.trim().isEmpty) {
      throw Exception('City not found from placemark');
    }
    return city;
  }

  Future<List<WeatherModel>> getWeatherData() async {
    final String city = await _getLocation();

    final String url =
        'https://api.collectapi.com/weather/getWeather?lang=tr&city=$city';

    const Map<String, dynamic> headers = {
      "authorization": "apikey 4DEI0cx9nXvnVAEW9VnBok:6ARDxMuSLgmeNKclJfOEwX",
      "content-type": "application/json",
    };

    final dio = Dio();

    final response = await dio.get(url, options: Options(headers: headers));

    if (response.statusCode != 200) {
      return Future.error('Failed to load weather data');
    }

    final data = response.data;
    final List<dynamic> list = data is List
        ? data
        : (data is Map<String, dynamic> && data['result'] is List
              ? data['result'] as List<dynamic>
              : []);

    return list.map((e) {
      final newMap = Map<String, dynamic>.from(e);
      newMap['city'] = city;
      return WeatherModel.fromJson(newMap);
    }).toList();
  }
}
