import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/travel_place.dart';
import '../models/trip_plan.dart';
import '../services/travel_data_service.dart';

class MapScreen extends StatefulWidget {
  final bool embedded;

  const MapScreen({super.key, this.embedded = false});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController mapController = MapController();
  final TravelDataService travelData = TravelDataService.instance;
  static final LatLng _fallbackCenter = LatLng(20.5937, 78.9629);

  @override
  void initState() {
    super.initState();
    travelData.addListener(_handleTravelDataChanged);
    _initialize();
  }

  @override
  void dispose() {
    travelData.removeListener(_handleTravelDataChanged);
    super.dispose();
  }

  LatLng get _currentFocusCenter {
    if (travelData.itineraryStops.isNotEmpty) {
      return LatLng(
        travelData.itineraryStops.first.latitude,
        travelData.itineraryStops.first.longitude,
      );
    }
    return travelData.cityCenter ?? _fallbackCenter;
  }

  void _updateMapBounds() {
    if (travelData.itineraryStops.isEmpty) {
      final center = travelData.cityCenter ?? _fallbackCenter;
      mapController.move(center, 13);
      setState(() {});
      return;
    }

    final points = travelData.itineraryStops
        .map((stop) => LatLng(stop.latitude, stop.longitude))
        .toList();

    if (travelData.tripIsActive && travelData.currentLocation != null) {
      points.add(travelData.currentLocation!);
    }

    if (points.isNotEmpty) {
      try {
        final bounds = LatLngBounds.fromPoints(points);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          mapController.fitBounds(
            bounds,
            options: const FitBoundsOptions(padding: EdgeInsets.all(40)),
          );
        });
      } catch (e) {
        final fallback = travelData.itineraryStops.isNotEmpty
            ? LatLng(travelData.itineraryStops.first.latitude, travelData.itineraryStops.first.longitude)
            : (travelData.cityCenter ?? _fallbackCenter);
        mapController.move(fallback, 13);
      }
    }
    setState(() {});
  }

  Future<void> _initialize() async {
    await travelData.initialize();
    await travelData.refreshTripLocation();
    if (!mounted) return;
    _updateMapBounds();
  }

  void _handleTravelDataChanged() {
    if (!mounted) return;
    _updateMapBounds();
  }

  void _recenterMap() {
    _updateMapBounds();
  }

  void _selectPlace(TravelPlace place) {
    travelData.selectPlace(place);
  }

  Future<void> _launchNavigation(double lat, double lng, String placeName) async {
    final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open maps application.')),
        );
      }
    }
  }

  Color _stopColor(PlannerStop stop) {
    if (travelData.visitedPlaceIds.contains(stop.place)) {
      return const Color(0xFFF1F3F4);
    }
    return stop.category == 'event'
        ? const Color(0xFFE3A32B)
        : const Color(0xFF4285F4);
  }

  Color _cardColor(TravelPlace place) {
    switch (place.category) {
      case 'restaurant':
        return const Color(0xFF6EBE7B);
      case 'hotel':
        return const Color(0xFF5B79A5);
      case 'museum':
        return const Color(0xFFB58153);
      default:
        return const Color(0xFF4DB6AC);
    }
  }

  IconData _placeIcon(TravelPlace place) {
    switch (place.category) {
      case 'restaurant':
        return Icons.restaurant_rounded;
      case 'hotel':
        return Icons.hotel_rounded;
      case 'museum':
        return Icons.museum_rounded;
      default:
        return Icons.place_rounded;
    }
  }

  Widget _buildGemCard(TravelPlace place) {
    final selected = travelData.selectedPlace?.id == place.id;
    return GestureDetector(
      onTap: () => _selectPlace(place),
      child: Container(
        width: 178,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: selected
              ? Border.all(color: const Color(0xFF008080), width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 126,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _cardColor(place),
                      _cardColor(place).withOpacity(0.45),
                    ],
                  ),
                ),
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _placeIcon(place),
                        color: const Color(0xFF008080),
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                place.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF20252D),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    size: 12,
                    color: Color(0xFF0B8B7A),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${place.category.toUpperCase()} • ${place.distanceKm.toStringAsFixed(1)} km away',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.black.withOpacity(0.56),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final selectedPlace =
        travelData.selectedPlace ??
        (travelData.nearbyGems.isNotEmpty ? travelData.nearbyGems.first : null);

    if (travelData.loadingPlaces && travelData.places.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        // 1. Full Bleed Map
        Positioned.fill(
          child: FlutterMap(
            mapController: mapController,
          options: MapOptions(
            center: _currentFocusCenter,
            zoom: 13,
          ),
          children: [
            TileLayer(
              // Real-world satellite imagery from Esri
              urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
            ),
            TileLayer(
              // Overlay for city names, streets, and borders
              urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
              backgroundColor: Colors.transparent,
            ),
            MarkerLayer(
              markers: [
                Marker(
                  width: 44,
                  height: 44,
                  point: travelData.cityCenter ?? _fallbackCenter,
                  builder: (_) => const Icon(Icons.location_on_rounded, color: Color(0xFF008080), size: 30),
                ),
                if (travelData.currentLocation != null)
                  Marker(
                    width: 40,
                    height: 40,
                    point: travelData.currentLocation!,
                    builder: (_) => Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF22A7F0),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: const Icon(Icons.my_location_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ...travelData.places.map(
                  (place) => Marker(
                    width: 42,
                    height: 42,
                    point: LatLng(place.latitude, place.longitude),
                    builder: (_) => GestureDetector(
                      onTap: () => _selectPlace(place),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _cardColor(place),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Icon(_placeIcon(place), color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ),
                ...travelData.itineraryStops.map(
                  (stop) => Marker(
                    width: 38,
                    height: 38,
                    point: LatLng(stop.latitude, stop.longitude),
                    builder: (_) {
                      final isVisited = travelData.visitedPlaceIds.contains(stop.place);
                      return Container(
                        decoration: BoxDecoration(
                          color: _stopColor(stop),
                          shape: BoxShape.circle,
                          border: Border.all(color: isVisited ? Colors.grey : Colors.white, width: 2),
                        ),
                        child: Icon(
                          isVisited ? Icons.check_rounded : stop.category == 'event' ? Icons.celebration_rounded : Icons.route_rounded,
                          color: isVisited ? Colors.grey[700] : Colors.white,
                          size: 16,
                        ),
                      );
                    },
                  ),
                ),
                ...travelData.events.map(
                  (event) => Marker(
                    width: 34,
                    height: 34,
                    point: LatLng(event.latitude, event.longitude),
                    builder: (_) => Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3A32B),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.local_activity_rounded, color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ],
            ),
          ],
        )),

        // 2. Top App Bar Floating
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Row(
                      children: const [
                        CircleAvatar(radius: 10, backgroundColor: Color(0xFFF3B09E)),
                        SizedBox(width: 8),
                        Text('TravelPilot AI', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF008080))),
                      ],
                    ),
                  ),
                  FloatingActionButton.small(
                    heroTag: "recenterBtn",
                    onPressed: _recenterMap,
                    backgroundColor: Colors.white,
                    child: const Icon(Icons.my_location_rounded, color: Color(0xFF008080)),
                  ),
                ],
              ),
            ),
          ),
        ),

        // 3. Sliding Overlay Sheet
        DraggableScrollableSheet(
          initialChildSize: 0.4,
          minChildSize: 0.2,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, -4)),
                ],
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        travelData.itineraryStops.isEmpty 
                            ? "Today's Journey" 
                            : "Today's Journey (${travelData.visitedPlacesCount}/${travelData.itineraryStops.length} visited)",
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1F252D)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFFEDF1F5)),
                  Expanded(
                    child: travelData.itineraryStops.isEmpty
                        ? const Center(
                            child: Text(
                              "No active destinations yet.",
                              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.only(top: 8, bottom: 20),
                            itemCount: travelData.itineraryStops.length,
                            itemBuilder: (context, index) {
                              final stop = travelData.itineraryStops[index];
                              final isVisited = travelData.visitedPlaceIds.contains(stop.place);

                              return ListTile(
                                onTap: () {
                                  mapController.move(LatLng(stop.latitude, stop.longitude), 15);
                                },
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                                leading: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: isVisited ? const Color(0xFFF1F3F4) : const Color(0xFFE0F2F1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        stop.category == 'event' ? Icons.celebration_rounded : Icons.place_rounded,
                                        color: isVisited ? Colors.grey[500] : const Color(0xFF008080),
                                      ),
                                    ),
                                    if (isVisited)
                                      Positioned(
                                        top: -2,
                                        right: -2,
                                        child: Container(
                                          decoration: const BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.check_circle_rounded, color: Color(0xFF34A853), size: 16),
                                        ),
                                      ),
                                  ],
                                ),
                                title: Text(
                                  stop.place,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    color: isVisited ? Colors.grey[600] : const Color(0xFF1F252D),
                                    decoration: isVisited ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                                subtitle: Text(
                                  "Arrived at ${stop.time}",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: isVisited ? Colors.grey[400] : Colors.grey[600],
                                  ),
                                ),
                                trailing: isVisited 
                                  ? const Text("Visited", style: TextStyle(color: Color(0xFF34A853), fontSize: 12, fontWeight: FontWeight.bold))
                                  : IconButton(
                                      icon: const Icon(Icons.navigation_rounded, color: Color(0xFF008080)),
                                      onPressed: () => _launchNavigation(stop.latitude, stop.longitude, stop.place),
                                      tooltip: 'Navigate',
                                    ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return _buildBody();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(title: const Text('Map')),
      body: SafeArea(child: _buildBody()),
    );
  }
}
