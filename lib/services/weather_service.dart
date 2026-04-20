import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class WeatherData {
  final double temp;
  final String condition;

  WeatherData({required this.temp, required this.condition});
}

class WeatherService {
  Future<WeatherData> fetchWeather() async {
    double lat = 31.9539; // Fallback to Amman
    double lon = 35.9106;

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
          Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
            timeLimit: const Duration(seconds: 5),
          );
          lat = position.latitude;
          lon = position.longitude;
        }
      }
    } catch (e) {
      print('WeatherService: Location acquisition failed, using fallback. Error: $e');
    }

    try {
      final url = 'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current_weather=true';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final current = data['current_weather'];
        return WeatherData(
          temp: (current['temperature'] as num).toDouble(),
          condition: _getWeatherDescription(current['weathercode']),
        );
      } else {
        print('WeatherService: API returned status ${response.statusCode}');
      }
    } catch (e) {
      print('WeatherService: API call failed. Error: $e');
    }

    return WeatherData(temp: 0, condition: 'Unknown');
  }

  String _getWeatherDescription(int code) {
    if (code == 0) return 'Clear';
    if (code <= 3) return 'Partly Cloudy';
    if (code <= 48) return 'Foggy';
    if (code <= 67) return 'Rainy';
    if (code <= 77) return 'Snowy';
    if (code <= 82) return 'Showers';
    if (code <= 99) return 'Thunderstorm';
    return 'Unknown';
  }
}
