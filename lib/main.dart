import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:open_route_service/open_route_service.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'كنائس الخريطة',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: ChurchMapScreen(),
    );
  }
}

class ChurchMapScreen extends StatefulWidget {
  const ChurchMapScreen({super.key});

  @override
  State<ChurchMapScreen> createState() => _ChurchMapScreenState();
}

class _ChurchMapScreenState extends State<ChurchMapScreen>
    with TickerProviderStateMixin {
  final OpenRouteService ors = OpenRouteService(
    apiKey:
        'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6IjA2NWQ0MjMwMDg0ZDQ1MGQ4MTU3OGJjOWNiZDYwNWRlIiwiaCI6Im11cm11cjY0In0=',
  );
  late StreamSubscription<Position> _positionStream;
  List<Map>? _churches = [];
  List<Marker> markerslocation = [];
  bool Locate = false;
  late AnimatedMapController ControllerMap;
  LatLng _currentLocation = LatLng(30.0444, 31.2357);
  PolylineLayer? _routePolyline; // ⬅️ متغير الخط

  @override
  void initState() {
    super.initState();
    ControllerMap = AnimatedMapController(vsync: this);
    _getcurrentlocation();
  }

  _getcurrentlocation() async {
    bool enable = await Geolocator.isLocationServiceEnabled();
    if (!enable) {
      await Geolocator.openLocationSettings();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        return;
      }
    }
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
      ControllerMap.animateTo(
        dest: _currentLocation,
        zoom: 16.0,
        duration: const Duration(seconds: 1),
        curve: Curves.easeInOut,
      );
      Locate = true;
    });
  }

  getChrushlocation() async {
    final url = Uri.parse(
      'https://overpass-api.de/api/interpreter?data=[out:json];node["amenity"="place_of_worship"]["religion"="christian"](30.0,31.1,30.2,31.3);out;',
    );
    final respones = await http.get(url);
    if (respones.statusCode == 200) {
      final data = jsonDecode(respones.body);
      final datamemory = data['elements'];
      _churches!.clear(); // ⬅️ حذف القديم
      List<Marker> markers =
          datamemory.map<Marker>((e) {
            double lat = e['lat'];
            double lon = e['lon'];
            String Name = e['tags']['name'] ?? 'Unknown';
            final spacehelp = Geolocator.distanceBetween(
              _currentLocation.latitude,
              _currentLocation.longitude,
              lat,
              lon,
            );

            if (Name.isNotEmpty) {
              _churches!.add({
                'name': Name,
                'lat': lat,
                'lon': lon,
                'distance': (spacehelp / 1000).floor(),
              });
            }
            return Marker(
              point: LatLng(lat, lon),
              height: 20,
              width: 20,
              child: Icon(Icons.church, color: Colors.blue, size: 30),
            );
          }).toList();
      setState(() {
        markerslocation = markers;
      });
    }
  }

  void _trackLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        return;
      }
    }

    _positionStream = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 2, // يتحرك كل 2 متر مثلاً
      ),
    ).listen((Position position) {
      final newLocation = LatLng(position.latitude, position.longitude);
      setState(() {
        _currentLocation = newLocation;
        Locate = true;
      });

      // تحريك الخريطة معاك
      ControllerMap.animateTo(
        dest: newLocation,
        zoom: 16.0,
        duration: Duration(milliseconds: 500),
        curve: Curves.linear,
      );
    });
  }

  showbuttonsheet() async {
    await showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          height: 400,
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  color: Colors.blue,
                ),
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20.0),
                  child: Center(
                    child: Text(
                      "اقرب الكنائس",
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _churches!.length,
                  itemBuilder: (context, index) {
                    final church = _churches![index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15.0,
                        vertical: 5.0,
                      ),
                      child: ListTile(
                        leading: Icon(
                          Icons.church,
                          color: Colors.blue,
                          size: 30,
                        ),
                        title: Text(
                          church['name'],
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        trailing: Text(
                          '${church['distance']} km',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onTap: () {
                          ControllerMap.animateTo(
                            dest: LatLng(church['lat'], church['lon']),
                            zoom: 18.0,
                            duration: Duration(
                              seconds: (church['distance'] + 2).clamp(
                                1,
                                10,
                              ), // 👈
                            ),
                            curve: Curves.easeInOut,
                          );
                          Navigator.pop(context);
                          artlineplace(
                            church['lat'],
                            church['lon'],
                            _currentLocation,
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> artlineplace(
    double lat,
    double lon,
    LatLng currentPerson,
  ) async {
    setState(() {
      _routePolyline = null; // ⬅️ يمسح الخط القديم أولًا
    });

    final ORSCoordinate start = ORSCoordinate(
      latitude: currentPerson.latitude,
      longitude: currentPerson.longitude,
    );
    final ORSCoordinate end = ORSCoordinate(latitude: lat, longitude: lon);

    final List<ORSCoordinate> route = await ors.directionsMultiRouteCoordsPost(
      coordinates: [start, end],
      profileOverride: ORSProfile.footWalking,
    );

    List<LatLng> polylinePoints =
        route.map((point) => LatLng(point.latitude, point.longitude)).toList();

    setState(() {
      _routePolyline = PolylineLayer(
        polylines: [
          Polyline(
            points: polylinePoints,
            color: Colors.blue,
            strokeWidth: 4.0,
          ),
        ],
      );
    });
  }

  // Future<void> artlineplace(double lat, double lon, LatLng currentPerson) async {
  //   final ORSCoordinate start = ORSCoordinate(
  //     latitude: currentPerson.latitude,
  //     longitude: currentPerson.longitude,
  //   );
  //   final ORSCoordinate end = ORSCoordinate(latitude: lat, longitude: lon);

  //   final List<ORSCoordinate> route = await ors.directionsMultiRouteCoordsPost(
  //     coordinates: [start, end],
  //     profileOverride: ORSProfile.footWalking,
  //   );

  //   List<LatLng> polylinePoints = route
  //       .map((point) => LatLng(point.latitude, point.longitude))
  //       .toList();

  //   setState(() {
  //     _routePolyline = PolylineLayer(
  //       polylines: [
  //         Polyline(
  //           points: polylinePoints,
  //           color: Colors.blue,
  //           strokeWidth: 4.0,
  //         ),
  //       ],
  //     );
  //   });
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'كنائس الخريطة',
          style: TextStyle(fontSize: 30, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: ControllerMap.mapController,
            options: MapOptions(
              initialCenter: _currentLocation,
              initialZoom: 12.0,
              interactionOptions: InteractionOptions(
                flags: ~InteractiveFlag.rotate, // ⬅️ تمنع الدوران نهائيًا
              ),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: ['a', 'b', 'c'],
                userAgentPackageName: 'com.example.kenesa',
              ),
              if (_routePolyline != null) _routePolyline!, // ⬅️ عرض الخط
              MarkerLayer(
                markers: [
                  ...markerslocation,
                  Marker(
                    point: _currentLocation,
                    width: 40,
                    height: 40,
                    child: Icon(Icons.location_on, color: Colors.red, size: 40),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            top: 70,
            right: 20,
            child: GestureDetector(
              onTap: () {
                ControllerMap.animateTo(
                  dest: _currentLocation,
                  zoom: 16.0,
                  duration: const Duration(seconds: 5),
                  curve: Curves.easeInOut,
                );
              },
              child: Container(
                height: 50,
                width: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 10,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(Icons.my_location, color: Colors.blue, size: 30),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: GestureDetector(
              onTap: () async {
                if (_churches!.isEmpty) {
                  await getChrushlocation();
                }
                showbuttonsheet();
                ControllerMap.animateTo(
                  dest: _currentLocation,
                  zoom: 12.0,
                  duration: const Duration(seconds: 5),
                  curve: Curves.easeInOut,
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.5),
                        spreadRadius: 3,
                        blurRadius: 1,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Text(
                        "اظهار الكنائس القريبة",
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
