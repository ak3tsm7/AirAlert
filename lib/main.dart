import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:location/location.dart';

void main() {
  runApp(AirAlertApp());
}

class AirAlertApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AirAlert',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: AirQualityScreen(),
    );
  }
}

class AirQualityScreen extends StatefulWidget {
  @override
  _AirQualityScreenState createState() => _AirQualityScreenState();
}

class _AirQualityScreenState extends State<AirQualityScreen> {
  int? aqi;
  String message = '';
  bool isLoading = true;

  final String apiKey = '1a0a8bf6dc740893af06bbc30b7b7504'; // Your API key

  @override
  void initState() {
    super.initState();
    fetchAirQuality();
  }

  Future<void> fetchAirQuality() async {
    try {
      Location location = Location();
      bool _serviceEnabled;
      PermissionStatus _permissionGranted;

      _serviceEnabled = await location.serviceEnabled();
      if (!_serviceEnabled) {
        _serviceEnabled = await location.requestService();
        if (!_serviceEnabled) {
          return;
        }
      }

      _permissionGranted = await location.hasPermission();
      if (_permissionGranted == PermissionStatus.denied) {
        _permissionGranted = await location.requestPermission();
        if (_permissionGranted != PermissionStatus.granted) {
          return;
        }
      }

      LocationData locationData = await location.getLocation();
      double lat = locationData.latitude!;
      double lon = locationData.longitude!;

      final url = 'https://api.openaq.org/v2/latest?coordinates=$lat,$lon&limit=1';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'x-api-key': apiKey,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['results'] != null && data['results'].length > 0) {
          final measurements = data['results'][0]['measurements'];

          final pm25 = measurements.firstWhere(
                (m) => m['parameter'] == 'pm25',
            orElse: () => null,
          );

          if (pm25 != null) {
            setState(() {
              aqi = (pm25['value']).toInt(); // Using PM2.5 as AQI estimate
              message = getMessage(aqi!);
              isLoading = false;
            });
          } else {
            setState(() {
              message = 'PM2.5 data not available';
              isLoading = false;
            });
          }
        } else {
          setState(() {
            message = 'No data available';
            isLoading = false;
          });
        }
      } else {
        setState(() {
          message = 'Failed to load data (API Error)';
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error: $e');
      setState(() {
        message = 'Error occurred: $e';
        isLoading = false;
      });
    }
  }

  String getMessage(int aqi) {
    if (aqi <= 12) return 'Good air quality!';
    if (aqi <= 35) return 'Moderate air quality.';
    if (aqi <= 55) return 'Unhealthy for sensitive groups.';
    if (aqi <= 150) return 'Unhealthy air quality!';
    return 'Very unhealthy air!';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('AirAlert'),
      ),
      body: Center(
        child: isLoading
            ? CircularProgressIndicator()
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'PM2.5: ${aqi ?? 'N/A'} µg/m³',
              style: TextStyle(fontSize: 32),
            ),
            SizedBox(height: 20),
            Text(
              message,
              style: TextStyle(fontSize: 24),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  isLoading = true;
                });
                fetchAirQuality();
              },
              child: Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }
}
