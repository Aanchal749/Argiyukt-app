import 'dart:async';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_fonts/google_fonts.dart'; // ✅ Added typography
import 'dart:math' as math;
import '../../common/screens/chat_screen.dart';

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

  // 🔑 API KEY
  final String googleApiKey = "AIzaSyABWOOnvnWa9bcZPfnXABYZWrd5VBj3LkY";

  // State
  LatLng? _farmLocation;
  Set<Polyline> _polylines = {};
  List<LatLng> _routeCoords = [];

  // Custom Icons
  BitmapDescriptor? _truckIcon;
  BitmapDescriptor? _farmerIcon;

  // Rotation Tracking
  LatLng? _lastPos;
  double _lastRotation = 0.0;

  // Theme Color
  final Color _primaryGreen = const Color(0xFF1B5E20);

  @override
  void initState() {
    super.initState();
    _loadCustomIcons();
    _loadInitialData();
  }

  // 🎨 CREATE CUSTOM ICONS
  Future<void> _loadCustomIcons() async {
    final truck = await _bitmapDescriptorFromIconData(
        Icons.local_shipping, Colors.blueAccent, 100);
    final farmer = await _bitmapDescriptorFromIconData(
        Icons.person_pin_circle, Colors.green, 100);
    setState(() {
      _truckIcon = truck;
      _farmerIcon = farmer;
    });
  }

  Future<BitmapDescriptor> _bitmapDescriptorFromIconData(
      IconData iconData, Color color, double size) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Paint paint = Paint()..color = color;
    final TextPainter textPainter =
        TextPainter(textDirection: TextDirection.ltr);
    final double radius = size / 2;
    canvas.drawCircle(Offset(radius, radius), radius, paint);
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
    final ui.Image image = await pictureRecorder
        .endRecording()
        .toImage(size.toInt(), size.toInt());
    final ByteData? byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  // 1. Load Initial Data
  Future<void> _loadInitialData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final profile = await _supabase
          .from('profiles')
          .select('latitude, longitude')
          .eq('id', user.id)
          .single();
      final order = await _supabase
          .from('orders')
          .select('buyer_lat, buyer_lng')
          .eq('id', widget.orderId)
          .single();

      if (mounted) {
        setState(() {
          double? fLat = (profile['latitude'] as num?)?.toDouble();
          double? fLng = (profile['longitude'] as num?)?.toDouble();
          if (fLat != null && fLng != null) {
            _farmLocation = LatLng(fLat, fLng);
          }

          double? bLat = (order['buyer_lat'] as num?)?.toDouble();
          double? bLng = (order['buyer_lng'] as num?)?.toDouble();
          if (bLat != null && bLng != null && _farmLocation != null) {
            _getRoutePolyline(LatLng(bLat, bLng), _farmLocation!);
          }
        });
      }
    } catch (e) {
      debugPrint("Init Error: $e");
    }
  }

  // 2. Fetch Route
  Future<void> _getRoutePolyline(LatLng start, LatLng dest) async {
    PolylinePoints polylinePoints = PolylinePoints(apiKey: googleApiKey);
    try {
      PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
        request: PolylineRequest(
          origin: PointLatLng(start.latitude, start.longitude),
          destination: PointLatLng(dest.latitude, dest.longitude),
          mode: TravelMode.driving,
        ),
      );

      if (result.points.isNotEmpty) {
        List<LatLng> polylineCoordinates =
            result.points.map((p) => LatLng(p.latitude, p.longitude)).toList();
        if (mounted) {
          setState(() {
            _routeCoords = polylineCoordinates;
            _polylines = {
              Polyline(
                polylineId: const PolylineId('real_route'),
                color: Colors.blueAccent,
                points: polylineCoordinates,
                width: 6,
                jointType: JointType.round,
              ),
            };
          });
        }
      }
    } catch (e) {
      debugPrint("Route Error: $e");
    }
  }

  // 3. Camera Animation
  void _animateCamera(LatLng pos, double rotation) async {
    final GoogleMapController controller = await _mapController.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(target: pos, zoom: 18, bearing: rotation, tilt: 60),
    ));
  }

  // Math Helper
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
        // ⚡ PURE REAL-TIME LISTENER
        stream: _supabase
            .from('orders')
            .stream(primaryKey: ['id']).eq('id', widget.orderId),
        builder: (context, snapshot) {
          LatLng currentPos = const LatLng(0, 0);
          bool hasData = false;
          String buyerName = "Logistics Partner";
          String status = "In Transit";
          String buyerId = "";

          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            final data = snapshot.data!.first;
            double? lat = (data['buyer_lat'] as num?)?.toDouble();
            double? lng = (data['buyer_lng'] as num?)?.toDouble();
            buyerName = data['buyer_name'] ?? "Logistics Partner";
            status = data['tracking_status'] ?? "In Transit";
            buyerId = data['buyer_id'] ?? "";

            if (lat != null && lng != null) {
              currentPos = LatLng(lat, lng);
              hasData = true;
            }
          }

          if (!hasData) return const Center(child: CircularProgressIndicator());

          // ⚡ ROTATION & ANIMATION LOGIC
          double rotation = _lastRotation;
          if (_lastPos != null &&
              (currentPos.latitude != _lastPos!.latitude ||
                  currentPos.longitude != _lastPos!.longitude)) {
            // Position Changed! Calculate new angle
            rotation = _calculateBearing(_lastPos!, currentPos);
            _lastRotation = rotation;

            // 🎥 FORCE CAMERA MOVE
            Future.delayed(
                Duration.zero, () => _animateCamera(currentPos, rotation));
          }
          _lastPos = currentPos;

          // ⚡ BUILD MARKERS
          Set<Marker> markers = {};
          if (_farmLocation != null) {
            markers.add(Marker(
              markerId: const MarkerId('farm'),
              position: _farmLocation!,
              icon: _farmerIcon ??
                  BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueGreen),
              infoWindow: const InfoWindow(title: "Farm Location"),
            ));
          }
          markers.add(Marker(
            markerId: const MarkerId('buyer'),
            position: currentPos,
            icon: _truckIcon ??
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
            rotation: rotation,
            anchor: const Offset(0.5, 0.5),
            flat: true,
            infoWindow: InfoWindow(title: buyerName),
          ));

          return Stack(
            children: [
              GoogleMap(
                mapType: MapType.normal,
                initialCameraPosition:
                    CameraPosition(target: currentPos, zoom: 15),
                markers: markers,
                polylines: _polylines,
                buildingsEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                compassEnabled: false,
                onMapCreated: (c) => _mapController.complete(c),
              ),
              Positioned(
                top: 50,
                left: 20,
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black),
                      onPressed: () => Navigator.pop(context)),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(25)),
                    boxShadow: [
                      BoxShadow(color: Colors.black12, blurRadius: 15)
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.local_shipping,
                              color: Colors.blue, size: 28),
                          const SizedBox(width: 15),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(buyerName,
                                  style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18)),
                              Text("Logistics Partner",
                                  style: GoogleFonts.poppins(
                                      color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(20)),
                            child: Text(status,
                                style: GoogleFonts.poppins(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold)),
                          )
                        ],
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                    targetUserId: buyerId,
                                    targetName: buyerName,
                                    orderId: widget.orderId,
                                    cropName: "Logistics",
                                    orderStatus: status))),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryGreen,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12))),
                        child: Text("Message Buyer",
                            style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
