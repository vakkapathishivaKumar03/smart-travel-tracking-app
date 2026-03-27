import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'smart_travel_agent.dart';
import 'travel_data_service.dart';

class TrackingAgent {
  static final TrackingAgent instance = TrackingAgent._();
  TrackingAgent._();

  StreamSubscription<Position>? _positionStream;
  final ValueNotifier<bool> isSimulating = ValueNotifier(false);

  void toggleSimulation() {
    if (isSimulating.value) {
      stopSimulation();
    } else {
      startSimulation();
    }
  }

  Future<void> startSimulation() async {
    isSimulating.value = true;
    
    // Request permissions before starting
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      isSimulating.value = false;
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        isSimulating.value = false;
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      isSimulating.value = false;
      return;
    }

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      _processLocationUpdate(position);
    });
    
    SmartTravelAgent.instance.reminders.triggerSuggestion("GPS Live Tracking Started...");
  }

  void stopSimulation() {
    isSimulating.value = false;
    _positionStream?.cancel();
    _positionStream = null;
    SmartTravelAgent.instance.reminders.triggerSuggestion("GPS Live Tracking Stopped.");
  }

  void _processLocationUpdate(Position position) {
    final travelData = TravelDataService.instance;
    final stops = travelData.itineraryStops;
    
    if (stops.isEmpty) return;

    final currentLoc = LatLng(position.latitude, position.longitude);
    travelData.updateCurrentLocation(currentLoc);

    for (int i = 0; i < stops.length; i++) {
      final stop = stops[i];
      if (!travelData.visitedPlaceIds.contains(stop.place)) {
        final stopLoc = LatLng(stop.latitude, stop.longitude);
        final distanceMeters = const Distance().as(LengthUnit.Meter, currentLoc, stopLoc);
        
        // Mark as visited if within 100 meters
        if (distanceMeters <= 100) {
          travelData.markVisitedByOrder(i);
        }
      }
    }
  }
}
