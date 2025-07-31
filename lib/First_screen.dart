import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ChurchFinder extends StatefulWidget {
  const ChurchFinder({super.key});

  @override
  State<ChurchFinder> createState() => _ChurchFinderState();
}

class _ChurchFinderState extends State<ChurchFinder> {
  LatLng? _currentLocation;
  List<Marker> _markers = [];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    LocationPermission permission = await Geolocator.checkPermission();

    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return;
    }

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        return;
      }
    }

    final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
    });

    _searchNearbyChurches();
  }

  Future<void> _searchNearbyChurches() async {
    final lat = _currentLocation!.latitude;
    final lon = _currentLocation!.longitude;

    final url = 'https://overpass-api.de/api/interpreter';
    final query = '''
    [out:json];
    (
      node["amenity"="place_of_worship"]["religion"="christian"](around:3000, $lat, $lon);
      way["amenity"="place_of_worship"]["religion"="christian"](around:3000, $lat, $lon);
      relation["amenity"="place_of_worship"]["religion"="christian"](around:3000, $lat, $lon);
    );
    out center 20;
    ''';

    final response = await http.post(
      Uri.parse(url),
      body: {'data': query},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      List<Marker> newMarkers = [];

      for (var element in data['elements']) {
        double? lat = element['lat'] ?? element['center']?['lat'];
        double? lon = element['lon'] ?? element['center']?['lon'];
        String name = element['tags']?['name'] ?? 'كنيسة';

        if (lat != null && lon != null) {
          newMarkers.add(
            Marker(
              point: LatLng(lat, lon),
              child: Tooltip(
                message: name,
                child: const Icon(Icons.location_on, color: Colors.red),
              ),
            ),
          );
        }
      }

      setState(() {
        _markers = newMarkers;
      });
    } else {
      print("فشل في جلب الكنائس: ${response.statusCode}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("أقرب كنيسة"),
        backgroundColor: Colors.blue,
      ),
      body: _currentLocation == null
          ? const Center(child: CircularProgressIndicator())
          : FlutterMap(
              options: MapOptions(
                initialCenter: _currentLocation!,
                initialZoom: 9.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://api.maptiler.com/maps/streets/{z}/{x}/{y}.png?key=2SlsloJHrHAHj9ioBiJW',
                  subdomains: const ['a', 'b', 'c'],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentLocation!,
                      child: const Icon(Icons.person_pin_circle, color: Colors.blue, size: 40),
                    ),
                    ..._markers,
                  ],
                ),
              ],
            ),
    );
  }
}
