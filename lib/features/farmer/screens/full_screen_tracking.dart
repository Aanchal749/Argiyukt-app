import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;

class FullScreenTracking extends StatefulWidget {
  final String orderId;

  const FullScreenTracking({
    super.key,
    required this.orderId,
  });

  @override
  State<FullScreenTracking> createState() => _FullScreenTrackingState();
}

class _FullScreenTrackingState extends State<FullScreenTracking> {
  final _supabase = Supabase.instance.client;
  final Completer<GoogleMapController> _mapController = Completer();

  // 🔑 IMPORTANT: Ensure your Google Maps Billing is active for Routing API
  final String googleApiKey = "AIzaSyD1ioETNK6cCxUud9k98JuTH3SzoyN2Fjc";

  LatLng? _farmLocation;
  Set<Polyline> _polylines = {};
  BitmapDescriptor? _truckIcon;
  BitmapDescriptor? _farmerIcon;

  LatLng? _lastPos;
  double _lastRotation = 0.0;
  final Color _primaryGreen = const Color(0xFF1B5E20);

  @override
  void initState() {
    super.initState();
    _loadCustomIcons();
    _fetchFarmLocation(); // ✅ Now correctly fetches the Farm's location, not the current user's.
  }

  Future<void> _loadCustomIcons() async {
    _truckIcon = await _bitmapDescriptorFromIconData(
        Icons.local_shipping, Colors.blueAccent, 100);
    _farmerIcon = await _bitmapDescriptorFromIconData(
        Icons.store, Colors.brown, 100); // Changed to store icon for Farm
    if (mounted) setState(() {});
  }

  // ✅ LOGISTICS FIX: Destination is ALWAYS the Farmer's location from the Order
  Future<void> _fetchFarmLocation() async {
    try {
      final orderData = await _supabase.from('orders').select('''
          destination_lat, destination_lng,
          farmer:profiles!orders_farmer_id_fkey(latitude, longitude)
      ''').eq('id', widget.orderId).single();

      final rawFarmer = orderData['farmer'];
      final farmer = rawFarmer is Map
          ? rawFarmer
          : (rawFarmer is List && rawFarmer.isNotEmpty ? rawFarmer[0] : {});

      // Fallbacks to ensure we always have a destination
      double? fLat = (orderData['destination_lat'] as num?)?.toDouble() ??
          (farmer['latitude'] as num?)?.toDouble();
      double? fLng = (orderData['destination_lng'] as num?)?.toDouble() ??
          (farmer['longitude'] as num?)?.toDouble();

      if (fLat != null && fLng != null && mounted) {
        setState(() {
          _farmLocation = LatLng(fLat, fLng);
        });
      }
    } catch (e) {
      debugPrint("Farm Location Fetch Error: $e");
    }
  }

  // ✅ REDRAWS ROUTE LIVE: This creates the "Simulation" effect
  Future<void> _updateLiveRoute(LatLng currentPos) async {
    if (_farmLocation == null) return;

    PolylinePoints polylinePoints = PolylinePoints(apiKey: googleApiKey);
    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      request: PolylineRequest(
        origin: PointLatLng(currentPos.latitude, currentPos.longitude),
        destination:
            PointLatLng(_farmLocation!.latitude, _farmLocation!.longitude),
        mode: TravelMode.driving,
      ),
    );

    if (result.points.isNotEmpty && mounted) {
      setState(() {
        _polylines = {
          Polyline(
            polylineId: const PolylineId('live_route'),
            color: Colors.blueAccent,
            points: result.points
                .map((p) => LatLng(p.latitude, p.longitude))
                .toList(),
            width: 6,
            jointType: JointType.round,
          ),
        };
      });
    }
  }

  void _animateCamera(LatLng pos, double rotation) async {
    final controller = await _mapController.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(target: pos, zoom: 17, bearing: rotation, tilt: 45),
    ));
  }

  double _calculateBearing(LatLng start, LatLng end) {
    double lat1 = start.latitude * (math.pi / 180.0);
    double lon1 = start.longitude * (math.pi / 180.0);
    double lat2 = end.latitude * (math.pi / 180.0);
    double lon2 = end.longitude * (math.pi / 180.0);
    double dLon = lon2 - lon1;
    double y = math.sin(dLon) * math.cos(lat2);
    double x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return (math.atan2(y, x) * (180.0 / math.pi) + 360.0) % 360.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _supabase
            .from('orders')
            .stream(primaryKey: ['id']).eq('id', widget.orderId),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.first;

          // ✅ LOGISTICS FIX: The Buyer is driving, so the moving truck is always buyer_lat/lng
          double? lat = (data['buyer_lat'] as num?)?.toDouble() ??
              (data['transport_lat'] as num?)?.toDouble();
          double? lng = (data['buyer_lng'] as num?)?.toDouble() ??
              (data['transport_lng'] as num?)?.toDouble();
          String status =
              data['tracking_status'] ?? data['status'] ?? "In Transit";

          if (lat == null || lng == null || lat == 0.0 || lng == 0.0) {
            return Center(
                child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.satellite_alt_rounded,
                    size: 50, color: Colors.grey),
                const SizedBox(height: 16),
                Text("Waiting for Buyer's GPS signal...",
                    style: GoogleFonts.poppins(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600)),
              ],
            ));
          }

          LatLng currentPos = LatLng(lat, lng);

          // Trigger map and polyline logic only when position significantly changes
          if (_lastPos == null || _lastPos != currentPos) {
            double rotation = _lastPos != null
                ? _calculateBearing(_lastPos!, currentPos)
                : _lastRotation;
            _lastRotation = rotation;
            _lastPos = currentPos;

            // Updates polyline and camera safely after the build phase
            Future.microtask(() {
              _updateLiveRoute(currentPos);
              _animateCamera(currentPos, rotation);
            });
          }

          return Stack(
            children: [
              GoogleMap(
                initialCameraPosition:
                    CameraPosition(target: currentPos, zoom: 15),
                markers: {
                  if (_farmLocation != null)
                    Marker(
                        markerId: const MarkerId('farm'),
                        position: _farmLocation!,
                        icon: _farmerIcon ?? BitmapDescriptor.defaultMarker),
                  Marker(
                    markerId: const MarkerId('truck'),
                    position: currentPos,
                    icon: _truckIcon ?? BitmapDescriptor.defaultMarker,
                    rotation: _lastRotation,
                    anchor: const Offset(0.5, 0.5),
                    flat: true,
                  ),
                },
                polylines: _polylines,
                onMapCreated: (c) => _mapController.complete(c),
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
              ),

              // UI Overlay (Back Button)
              Positioned(
                top: 50,
                left: 20,
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.black),
                      onPressed: () => Navigator.pop(context)),
                ),
              ),

              // UI Overlay (Status Panel)
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 10)
                      ]),
                  child: Row(
                    children: [
                      const Icon(Icons.sensors, color: Colors.redAccent),
                      const SizedBox(width: 15),
                      Text("Live Delivery Status",
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const Spacer(),
                      Chip(
                        label: Text(status.toUpperCase(),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                        backgroundColor: _primaryGreen,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 0),
                      )
                    ],
                  ),
                ),
              )
            ],
          );
        },
      ),
    );
  }

  // Icon Generation Helper
  Future<BitmapDescriptor> _bitmapDescriptorFromIconData(
      IconData iconData, Color color, double size) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Paint paint = Paint()..color = color;
    final double radius = size / 2;
    canvas.drawCircle(Offset(radius, radius), radius, paint);
    TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
        text: String.fromCharCode(iconData.codePoint),
        style: TextStyle(
            fontSize: size * 0.6,
            fontFamily: iconData.fontFamily,
            color: Colors.white));
    textPainter.layout();
    textPainter.paint(
        canvas,
        Offset(
            radius - textPainter.width / 2, radius - textPainter.height / 2));
    final image = await pictureRecorder
        .endRecording()
        .toImage(size.toInt(), size.toInt());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
  }
}
