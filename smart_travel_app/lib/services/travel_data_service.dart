import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/expense.dart';
import '../models/trip_plan.dart';
import '../models/travel_memory.dart';
import '../models/travel_place.dart';
import 'location_service.dart';
import 'smart_travel_agent.dart';
import 'api_service.dart';

class TravelDataService extends ChangeNotifier {
  TravelDataService._();

  static final TravelDataService instance = TravelDataService._();

  static const String _cityKey = 'travel_city_name';
  static const String _cityLabelKey = 'travel_city_label';
  static const String _latKey = 'travel_city_latitude';
  static const String _lngKey = 'travel_city_longitude';
  static const String _placesKey = 'travel_places';
  static const String _expensesKey = 'travel_expenses';
  static const String _memoriesKey = 'travel_memories';
  static const String _tripDaysKey = 'travel_trip_days';
  static const String _tripStartKey = 'travel_trip_start';
  static const String _tripEndKey = 'travel_trip_end';
  static const String _eventsKey = 'travel_events';
  static const String _itineraryKey = 'travel_itinerary';
  static const String _tripsKey = 'travel_previous_trips';
  static const String _tripStatusKey = 'travel_trip_status';
  static const String _visitedPlacesKey = 'travel_visited_places';
  static const String _timelineKey = 'travel_trip_timeline';
  static const String _friendsKey = 'travel_trip_friends';
  static const String _shareCodeKey = 'travel_trip_share_code';
  static const String _currentLocationLatKey = 'travel_current_location_lat';
  static const String _currentLocationLngKey = 'travel_current_location_lng';
  static const String _currentTripIdKey = 'travel_current_trip_id';

  final http.Client _client = http.Client();
  final Distance _distance = Distance();
  final Random _random = Random();

  bool _initialized = false;

  String cityName = '';
  String cityLabel = '';
  LatLng? cityCenter;
  int tripDays = 3;
  DateTime? tripStartDate;
  DateTime? tripEndDate;
  List<TravelPlace> places = const [];
  List<Expense> expenses = const [];
  List<TravelMemory> memories = const [];
  List<PlannerStop> itineraryStops = const [];
  List<TravelEvent> events = const [];
  List<TravelTrip> previousTrips = const [];
  List<String> visitedPlaceIds = const [];
  List<String> timelineEntries = const [];
  List<String> friends = const [];
  String tripStatus = 'upcoming';
  String shareCode = '';
  String currentTripId = '';
  LatLng? currentLocation;
  TravelPlace? selectedPlace;
  bool loadingPlaces = false;
  String? errorMessage;

  bool get hasSelectedCity =>
      cityName.trim().isNotEmpty &&
      cityLabel.trim().isNotEmpty &&
      cityCenter != null;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await _loadLocalState();
    notifyListeners();
  }

  List<TravelPlace> get topPicks {
    final preferred = places.where(
      (place) => place.category == 'attraction' || place.category == 'museum',
    );
    final picks = preferred.isNotEmpty ? preferred.toList() : places.toList();
    return picks.take(6).toList();
  }

  List<TravelPlace> get nearbyGems => places.take(8).toList();

  List<TravelPlace> get restaurantPlaces =>
      places.where((place) => place.category == 'restaurant').toList();

  List<TravelPlace> get museumPlaces =>
      places.where((place) => place.category == 'museum').toList();

  List<TravelPlace> get landmarkPlaces =>
      places.where((place) => place.category == 'attraction').toList();

  List<List<PlannerStop>> get itineraryByDay {
    return List<List<PlannerStop>>.generate(tripDays, (index) {
      final items =
          itineraryStops.where((stop) => stop.dayIndex == index).toList()
            ..sort((a, b) => a.time.compareTo(b.time));
      return items;
    });
  }

  TravelTrip? get latestTrip =>
      previousTrips.isEmpty ? null : previousTrips.first;
  TravelTrip? get activeTrip => _tripByStatus('active');
  TravelTrip? get upcomingTrip => _tripByStatus('upcoming');
  List<TravelTrip> get pastTrips =>
      previousTrips.where((trip) => trip.status == 'completed').toList();

  bool get tripIsActive => tripStatus == 'active';
  bool get tripIsCompleted => tripStatus == 'completed';
  bool get tripIsUpcoming => tripStatus == 'upcoming';

  double get estimatedBudget {
    final breakdown = estimatedBudgetBreakdown;
    return breakdown.values.fold(0.0, (sum, val) => sum + val);
  }

  double get remainingBudget {
    return (estimatedBudget - totalExpense)
        .clamp(0, double.infinity)
        .toDouble();
  }

  double get spentPercentage {
    if (estimatedBudget <= 0) return 0;
    return (totalExpense / estimatedBudget) * 100;
  }

  int get memoriesCreatedCount => memories.length;
  int get visitedPlacesCount => visitedPlaceIds.length;

  Map<String, double> get estimatedBudgetBreakdown {
    if (itineraryStops.isEmpty) {
      return {
        'Hotel': 0.0,
        'Transport': 0.0,
        'Food': 0.0,
        'Activities': 0.0,
      };
    }
    final int safeDays = tripDays > 0 ? tripDays : 1;
    final int nights = safeDays > 1 ? safeDays - 1 : 1;
    final int activityCount = itineraryStops.where((s) => s.category != 'restaurant' && s.category != 'hotel').length;
    
    // Transport: Distance-based calculation
    double totalDistanceKm = itineraryStops.fold(0.0, (sum, stop) => sum + stop.distanceKm);
    double transportCost = totalDistanceKm * 15.0; // ₹15 per km
    // Base fallback just in case distance is 0 or very small
    if (transportCost < safeDays * 200.0) {
      transportCost = safeDays * 200.0;
    }
    
    return {
      'Hotel': (nights * 2500).toDouble(), // Accommodation per night
      'Transport': transportCost,          // Transport distance-based
      'Food': (safeDays * 1200).toDouble(), // Food per day
      'Activities': (activityCount * 500).toDouble(), // Entry fees per place
    };
  }

  List<String> get hotelSuggestions => const [
    'Budget Stay',
    'Mid Range Hotel',
    'Luxury Suite',
  ];

  List<String> get transportSuggestions => const [
    'Flight',
    'Train',
    'Bus',
    'Local Metro',
  ];

  List<String> get activeReminders {
    if (!tripIsActive) return const [];
    final nextStop = itineraryStops
        .where((stop) => !visitedPlaceIds.contains(stop.place))
        .map((stop) => stop.place)
        .cast<String?>()
        .firstWhere((place) => place != null, orElse: () => null);
    return [
      if (nextStop != null) 'Visit next place: $nextStop',
      'Lunch time reminder',
      'Check-in reminder',
      if (spentPercentage > 75) 'Budget alert',
    ];
  }

  List<Expense> get currentTripExpenses => expenses;

  double get totalExpense =>
      expenses.fold<double>(0, (sum, expense) => sum + expense.amount);

  Future<void> createTrip({
    required String destination,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final safeEndDate = endDate.isBefore(startDate) ? startDate : endDate;
    tripStartDate = startDate;
    tripEndDate = safeEndDate;
    tripDays = safeEndDate.difference(startDate).inDays + 1;
    tripStatus = 'upcoming';
    currentTripId = _buildTripId(destination.trim(), startDate, safeEndDate);
    visitedPlaceIds = [];
    timelineEntries = ['Trip created for ${destination.trim()}'];
    currentLocation = null;
    friends = [];
    shareCode = _generateShareCode(destination);
    places = const [];
    itineraryStops = const [];
    events = const [];
    expenses = const [];
    memories = const [];
    selectedPlace = null;
    await searchCity(destination, notifyOnStart: false);
    _generateItineraryFromPlaces();
    await _loadEvents();
    _saveCurrentTrip();
    await _persistTravelState();
    notifyListeners();
  }

  Future<void> searchCity(String query, {bool notifyOnStart = true}) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return;

    if (notifyOnStart) {
      loadingPlaces = true;
      errorMessage = null;
      notifyListeners();
    } else {
      loadingPlaces = true;
      errorMessage = null;
    }

    try {
      final cityResult = await _geocodeCity(normalized);
      final fetchedPlaces = await _fetchNearbyPlaces(
        latitude: cityResult.latitude,
        longitude: cityResult.longitude,
      );

      cityName = normalized;
      cityLabel = cityResult.label;
      cityCenter = LatLng(cityResult.latitude, cityResult.longitude);
      places = fetchedPlaces;
      selectedPlace = fetchedPlaces.isEmpty ? null : fetchedPlaces.first;
      _generateItineraryFromPlaces();
      await _loadEvents();
      _saveCurrentTrip();
      errorMessage = null;

      await _persistTravelState();
    } catch (error) {
      final cityResult = await _safeGeocodeFallback(normalized);
      cityName = normalized;
      cityLabel = cityResult.label;
      cityCenter = LatLng(cityResult.latitude, cityResult.longitude);
      places = _fallbackPlacesFor(cityResult.label, cityResult.latitude, cityResult.longitude);
      selectedPlace = places.isEmpty ? null : places.first;
      _generateItineraryFromPlaces();
      await _loadEvents();
      _saveCurrentTrip();
      errorMessage = null;
      await _persistTravelState();
    } finally {
      loadingPlaces = false;
      notifyListeners();
    }
  }

  Future<void> refreshSelectedCity() async {
    await autoCompleteTripIfNeeded();
    if (!hasSelectedCity) {
      errorMessage = 'Search for a city to begin';
      notifyListeners();
      return;
    }
    await searchCity(cityName);
  }

  Future<void> openPreviousTrip(TravelTrip trip) async {
    final parsedStart = DateTime.tryParse(trip.startDate);
    final parsedEnd = DateTime.tryParse(trip.endDate);
    tripStartDate = parsedStart;
    tripEndDate = parsedEnd;
    tripDays = trip.tripDays;
    tripStatus = trip.status;
    shareCode = trip.shareCode;
    friends = trip.friends;
    currentTripId = trip.id;
    await searchCity(trip.destination, notifyOnStart: false);
  }

  Future<void> addExpense({
    required double amount,
    required String category,
    String note = '',
    String date = '',
  }) async {
    SmartTravelAgent.instance.expenses.detectOverspending(amount, remainingBudget);
    final nextId = _nextExpenseId();
    expenses = [
      Expense(
        id: nextId,
        amount: amount,
        category: category,
        note: note,
        date: date,
        tripId: currentTripId,
      ),
      ...expenses,
    ];
    await _persistExpenses();
    if (note.isNotEmpty) {
      _appendTimeline('Expense added: $note');
    } else {
      _appendTimeline('Expense added: $category');
    }
    notifyListeners();
  }

  Future<int> importDemoSmsExpenses() async {
    final now = DateTime.now();
    final samples = <({double amount, String category, String note})>[
      (amount: 250, category: 'Dining', note: 'Street food meal'),
      (amount: 1200, category: 'Stay', note: 'Hotel booking payment'),
      (amount: 350, category: 'Transport', note: 'Cab ride'),
      (amount: 780, category: 'Transport', note: 'Train ticket'),
      (amount: 420, category: 'Dining', note: 'Cafe bill'),
      (amount: 650, category: 'Activities', note: 'Museum entry'),
    ];
    final shuffled = [...samples]..shuffle(_random);
    final baseId = _nextExpenseId();
    final count = 3 + _random.nextInt(2);
    final demoExpenses = List<Expense>.generate(count, (index) {
      final sample = shuffled[index];
      final date = now.subtract(
        Duration(
          days: _random.nextInt(4),
          hours: _random.nextInt(20),
          minutes: _random.nextInt(60),
        ),
      );
      return Expense(
        id: baseId + index,
        amount: sample.amount,
        category: sample.category,
        note: sample.note,
        date: date.toIso8601String(),
      );
    });

    expenses = [...demoExpenses, ...expenses];
    await _persistExpenses();
    notifyListeners();
    return demoExpenses.length;
  }

  Future<String> addMemory({
    required String description,
    XFile? file,
    String mediaType = 'image',
  }) async {
    String? mediaBytes;
    List<int>? rawBytes;
    if (file != null) {
      rawBytes = await file.readAsBytes();
      if (mediaType == 'image') {
        mediaBytes = base64Encode(rawBytes);
      }
    }

    final memoryId = DateTime.now().microsecondsSinceEpoch.toString();
    
    try {
      final api = ApiService();
      await api.uploadMemory(
        description: description,
        filePath: file?.path,
        fileBytes: rawBytes,
        fileName: file?.name ?? 'upload',
        mediaType: mediaType,
        tripId: activeTrip != null ? int.tryParse(activeTrip!.id) : null,
      );
    } catch (_) {
      // Ignore backend errors in local-first design
    }

    memories = [
      TravelMemory(
        id: memoryId,
        description: description,
        mediaType: mediaType,
        timestamp: DateTime.now().toIso8601String(),
        mediaPath: file?.path,
        mediaBytes: mediaBytes,
      ),
      ...memories,
    ];

    await _persistMemories();
    notifyListeners();
    return memoryId;
  }

  Future<void> addTripMemories(List<XFile> files) async {
    final city = cityName.isEmpty ? 'your trip' : cityName;
    final existingKeys = memories
        .map((memory) => memory.mediaPath ?? memory.mediaBytes ?? '')
        .where((value) => value.isNotEmpty)
        .toSet();

    for (final file in files.take(3)) {
      if (!existingKeys.add(file.path)) continue;
      await addMemory(
        description: 'Trip Memory\nCaptured during your trip to $city',
        file: file,
        mediaType: 'image',
      );
    }
  }

  Future<void> startTrip() async {
    tripStatus = 'active';
    _appendTimeline('Trip started');
    _saveCurrentTrip();
    await _persistTravelState();
    await _persistExpenses();
    await _persistMemories();
    notifyListeners();
  }

  Future<void> endTrip() async {
    tripStatus = 'completed';
    _appendTimeline('Trip completed');
    _saveCurrentTrip();
    await _persistTravelState();
    notifyListeners();
  }

  Future<void> autoCompleteTripIfNeeded() async {
    if (tripEndDate == null || tripIsCompleted) return;
    if (DateTime.now().isAfter(tripEndDate!)) {
      await endTrip();
    }
  }

  Future<void> refreshTripLocation() async {
    await autoCompleteTripIfNeeded();
    if (!tripIsActive) return;
    final point = await LocationService.getCurrentLocation();
    if (point == null) return;

    currentLocation = LatLng(point.latitude, point.longitude);
    await _detectVisitedPlaces();
    await _persistTravelState();
    notifyListeners();
  }

  void updateCurrentLocation(LatLng loc) {
    currentLocation = loc;
    notifyListeners();
  }

  // AGENTIC LOGIC: TripMonitoring (Jury Feature Simulation)
  void simulateTimeSpent(String placeName, Duration duration) {

  }

  Future<void> addFriend(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    if (friends.contains(trimmed)) return;
    friends = [...friends, trimmed];
    _appendTimeline('$trimmed joined the trip');
    _saveCurrentTrip();
    await _persistTravelState();
    notifyListeners();
  }

  String buildShareSummary() {
    final destination = cityName.isEmpty ? 'your trip' : cityName;
    final topPlaces = itineraryStops
        .take(4)
        .map((stop) => stop.place)
        .join(', ');
    return 'TravelPilot AI trip\nDestination: $destination\nDays: $tripDays\nShare code: $shareCode\nPlaces: $topPlaces';
  }

  void selectPlace(TravelPlace place) {
    selectedPlace = place;
    notifyListeners();
  }

  List<List<TravelPlace>> buildItinerary() {
    return itineraryByDay
        .map(
          (day) => day
              .map(
                (stop) => TravelPlace(
                  id: stop.id,
                  name: stop.place,
                  category: stop.category,
                  subcategory: stop.category,
                  address: stop.notes,
                  latitude: stop.latitude,
                  longitude: stop.longitude,
                  distanceKm: stop.distanceKm,
                ),
              )
              .toList(),
        )
        .toList();
  }

  Future<void> addStop({
    required int dayIndex,
    required String place,
    required String time,
    required String notes,
    String status = 'PLANNED',
    String category = 'attraction',
    double? latitude,
    double? longitude,
    double? distanceKm,
  }) async {
    itineraryStops = [
      ...itineraryStops,
      PlannerStop(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        dayIndex: dayIndex,
        place: place,
        time: time,
        notes: notes,
        status: status,
        category: category,
        latitude: latitude ?? cityCenter?.latitude ?? 0,
        longitude: longitude ?? cityCenter?.longitude ?? 0,
        distanceKm: distanceKm ?? 0,
      ),
    ];
    await _persistTravelState();
    notifyListeners();
  }

  Future<void> updateStop(PlannerStop updatedStop) async {
    itineraryStops = itineraryStops
        .map((stop) => stop.id == updatedStop.id ? updatedStop : stop)
        .toList();
    await _persistTravelState();
    notifyListeners();
  }

  Future<void> deleteStop(String stopId) async {
    itineraryStops = itineraryStops.where((stop) => stop.id != stopId).toList();
    await _persistTravelState();
    notifyListeners();
  }

  Future<void> addEventToItinerary(
    TravelEvent event, {
    int dayIndex = 0,
  }) async {
    await addStop(
      dayIndex: dayIndex,
      place: event.name,
      time: '07:30 PM',
      notes: '${event.category} event • ${event.date}',
      status: 'EVENT',
      category: 'event',
      latitude: event.latitude,
      longitude: event.longitude,
      distanceKm: event.distanceKm,
    );
    _appendTimeline('Added event: ${event.name}');
  }

  Future<void> updateMemory({
    required String memoryId,
    required String description,
  }) async {
    memories = memories
        .map(
          (memory) => memory.id == memoryId
              ? TravelMemory(
                  id: memory.id,
                  description: description,
                  mediaType: memory.mediaType,
                  timestamp: memory.timestamp,
                  mediaPath: memory.mediaPath,
                  mediaBytes: memory.mediaBytes,
                )
              : memory,
        )
        .toList();
    await _persistMemories();
    notifyListeners();
  }

  Future<void> deleteMemory(String memoryId) async {
    memories = memories.where((memory) => memory.id != memoryId).toList();
    await _persistMemories();
    notifyListeners();
  }

  Future<void> markVisitedByOrder(int visitIndex) async {
    if (visitIndex < 0 || visitIndex >= itineraryStops.length) return;
    final stop = itineraryStops[visitIndex];
    if (visitedPlaceIds.contains(stop.place)) return;
    visitedPlaceIds = [...visitedPlaceIds, stop.place];
    currentLocation = LatLng(stop.latitude, stop.longitude);
    _appendTimeline('Visited ${stop.place}');
    await addMemory(
      description: 'Trip Memory\nVisited ${stop.place}',
      mediaType: 'image',
    );
    
    // Trigger Cooperative Smart Agent Logic
    SmartTravelAgent.instance.trip.onPlaceVisited(stop.place);
    
    await _persistTravelState();
    notifyListeners();
  }

  Future<_CityResult> _geocodeCity(String city) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': city,
      'format': 'jsonv2',
      'limit': '1',
    });

    final response = await _client.get(
      uri,
      headers: {'User-Agent': 'smart-travel-app-demo/1.0'},
    );

    if (response.statusCode != 200) {
      throw Exception('Geocoding failed');
    }

    final body = jsonDecode(response.body);
    if (body is! List || body.isEmpty) {
      throw Exception('City not found');
    }

    final first = body.first as Map<String, dynamic>;
    return _CityResult(
      label: first['display_name']?.toString() ?? city,
      latitude: double.parse(first['lat'].toString()),
      longitude: double.parse(first['lon'].toString()),
    );
  }

  Future<List<TravelPlace>> _fetchNearbyPlaces({
    required double latitude,
    required double longitude,
  }) async {
    final query =
        '''
[out:json][timeout:25];
(
  node(around:3500,$latitude,$longitude)[amenity=restaurant];
  way(around:3500,$latitude,$longitude)[amenity=restaurant];
  relation(around:3500,$latitude,$longitude)[amenity=restaurant];
  node(around:3500,$latitude,$longitude)[tourism=hotel];
  way(around:3500,$latitude,$longitude)[tourism=hotel];
  relation(around:3500,$latitude,$longitude)[tourism=hotel];
  node(around:3500,$latitude,$longitude)[tourism=museum];
  way(around:3500,$latitude,$longitude)[tourism=museum];
  relation(around:3500,$latitude,$longitude)[tourism=museum];
  node(around:3500,$latitude,$longitude)[tourism=attraction];
  way(around:3500,$latitude,$longitude)[tourism=attraction];
  relation(around:3500,$latitude,$longitude)[tourism=attraction];
);
out center 80;
''';
    final expandedQuery =
        '''
[out:json][timeout:25];
(
  node(around:3500,$latitude,$longitude)[amenity=restaurant];
  way(around:3500,$latitude,$longitude)[amenity=restaurant];
  node(around:3500,$latitude,$longitude)[amenity=place_of_worship];
  node(around:3500,$latitude,$longitude)[shop];
  node(around:3500,$latitude,$longitude)[tourism=museum];
  node(around:3500,$latitude,$longitude)[tourism=attraction];
  node(around:3500,$latitude,$longitude)[tourism=viewpoint];
  node(around:3500,$latitude,$longitude)[tourism=hotel];
  node(around:3500,$latitude,$longitude)[leisure=park];
  way(around:3500,$latitude,$longitude)[leisure=park];
);
out center 120;
''';

    final response = await _client.post(
      Uri.parse('https://overpass-api.de/api/interpreter'),
      headers: {'Content-Type': 'text/plain'},
      body: expandedQuery,
    );

    if (response.statusCode != 200) {
      throw Exception('Overpass lookup failed');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final elements = body['elements'] as List<dynamic>? ?? const [];
    final seen = <String>{};
    final parsed = <TravelPlace>[];

    for (final rawMap in elements.whereType<Map>()) {
      final raw = Map<String, dynamic>.from(rawMap);
      final tags = raw['tags'] as Map<String, dynamic>? ?? const {};
      final name = tags['name']?.toString();
      if (name == null || name.trim().isEmpty) {
        continue;
      }

      final lat =
          (raw['lat'] as num?)?.toDouble() ??
          (raw['center']?['lat'] as num?)?.toDouble();
      final lng =
          (raw['lon'] as num?)?.toDouble() ??
          (raw['center']?['lon'] as num?)?.toDouble();

      if (lat == null || lng == null) continue;

      final category = _categoryFromTags(tags);
      final id = '${category}_${name.toLowerCase()}_${lat.toStringAsFixed(4)}';
      if (!seen.add(id)) continue;

      final addressParts =
          [tags['addr:street'], tags['addr:suburb'], tags['addr:city']]
              .whereType<Object>()
              .map((part) => part.toString())
              .where((part) => part.isNotEmpty);

      parsed.add(
        TravelPlace(
          id: id,
          name: name,
          category: category,
          subcategory:
              tags['tourism']?.toString() ?? tags['amenity']?.toString() ?? '',
          address: addressParts.join(', '),
          latitude: lat,
          longitude: lng,
          distanceKm: _distance.as(
            LengthUnit.Kilometer,
            LatLng(latitude, longitude),
            LatLng(lat, lng),
          ),
        ),
      );
    }

    parsed.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return parsed;
  }

  String _categoryFromTags(Map<String, dynamic> tags) {
    final tourism = tags['tourism']?.toString().toLowerCase();
    final amenity = tags['amenity']?.toString().toLowerCase();

    if (amenity == 'restaurant') return 'restaurant';
    if (amenity == 'place_of_worship') return 'temple';
    if (tags['shop'] != null) return 'shopping';
    if (tags['leisure']?.toString().toLowerCase() == 'park') return 'park';
    if (tourism == 'hotel') return 'hotel';
    if (tourism == 'museum') return 'museum';
    if (tourism == 'viewpoint') return 'viewpoint';
    return 'attraction';
  }

  Future<void> _loadLocalState() async {
    final prefs = await SharedPreferences.getInstance();
    cityName = prefs.getString(_cityKey) ?? cityName;
    cityLabel = prefs.getString(_cityLabelKey) ?? cityLabel;
    tripDays = prefs.getInt(_tripDaysKey) ?? tripDays;
    tripStatus = prefs.getString(_tripStatusKey) ?? tripStatus;
    shareCode = prefs.getString(_shareCodeKey) ?? shareCode;
    currentTripId = prefs.getString(_currentTripIdKey) ?? currentTripId;
    final storedTripStart = prefs.getString(_tripStartKey);
    final storedTripEnd = prefs.getString(_tripEndKey);
    tripStartDate = storedTripStart == null
        ? null
        : DateTime.tryParse(storedTripStart);
    tripEndDate = storedTripEnd == null
        ? null
        : DateTime.tryParse(storedTripEnd);
    final storedLat = prefs.getDouble(_latKey);
    final storedLng = prefs.getDouble(_lngKey);
    if (storedLat != null && storedLng != null) {
      cityCenter = LatLng(storedLat, storedLng);
    }
    final storedCurrentLat = prefs.getDouble(_currentLocationLatKey);
    final storedCurrentLng = prefs.getDouble(_currentLocationLngKey);
    if (storedCurrentLat != null && storedCurrentLng != null) {
      currentLocation = LatLng(storedCurrentLat, storedCurrentLng);
    }

    final placesRaw = prefs.getString(_placesKey);
    if (placesRaw != null && placesRaw.isNotEmpty) {
      final decoded = jsonDecode(placesRaw) as List<dynamic>;
      places = decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .map(TravelPlace.fromJson)
          .toList();
      if (places.isNotEmpty) {
        selectedPlace = places.first;
      }
    }

    final expensesRaw = prefs.getString(_expensesKey);
    if (expensesRaw != null && expensesRaw.isNotEmpty) {
      final decoded = jsonDecode(expensesRaw) as List<dynamic>;
      expenses = decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .map(Expense.fromJson)
          .toList();
    } else {
      expenses = [];
    }

    final memoriesRaw = prefs.getString(_memoriesKey);
    if (memoriesRaw != null && memoriesRaw.isNotEmpty) {
      final decoded = jsonDecode(memoriesRaw) as List<dynamic>;
      memories = decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .map(TravelMemory.fromJson)
          .toList();
    }

    final eventsRaw = prefs.getString(_eventsKey);
    if (eventsRaw != null && eventsRaw.isNotEmpty) {
      final decoded = jsonDecode(eventsRaw) as List<dynamic>;
      events = decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .map(TravelEvent.fromJson)
          .toList();
    }

    final itineraryRaw = prefs.getString(_itineraryKey);
    if (itineraryRaw != null && itineraryRaw.isNotEmpty) {
      final decoded = jsonDecode(itineraryRaw) as List<dynamic>;
      itineraryStops = decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .map(PlannerStop.fromJson)
          .toList();
    }

    final tripsRaw = prefs.getString(_tripsKey);
    if (tripsRaw != null && tripsRaw.isNotEmpty) {
      final decoded = jsonDecode(tripsRaw) as List<dynamic>;
      previousTrips = decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .map(TravelTrip.fromJson)
          .toList();
    }

    final visitedRaw = prefs.getStringList(_visitedPlacesKey);
    if (visitedRaw != null) {
      visitedPlaceIds = visitedRaw;
    }

    final timelineRaw = prefs.getStringList(_timelineKey);
    if (timelineRaw != null) {
      timelineEntries = timelineRaw;
    }

    final friendsRaw = prefs.getStringList(_friendsKey);
    if (friendsRaw != null) {
      friends = friendsRaw;
    }

    await autoCompleteTripIfNeeded();
  }

  Future<void> _persistTravelState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cityKey, cityName);
    await prefs.setString(_cityLabelKey, cityLabel);
    await prefs.setInt(_tripDaysKey, tripDays);
    await prefs.setString(_tripStatusKey, tripStatus);
    await prefs.setString(_shareCodeKey, shareCode);
    await prefs.setString(_currentTripIdKey, currentTripId);
    await prefs.setStringList(_visitedPlacesKey, visitedPlaceIds);
    await prefs.setStringList(_timelineKey, timelineEntries);
    await prefs.setStringList(_friendsKey, friends);
    if (tripStartDate != null) {
      await prefs.setString(_tripStartKey, tripStartDate!.toIso8601String());
    }
    if (tripEndDate != null) {
      await prefs.setString(_tripEndKey, tripEndDate!.toIso8601String());
    }
    if (cityCenter != null) {
      await prefs.setDouble(_latKey, cityCenter!.latitude);
      await prefs.setDouble(_lngKey, cityCenter!.longitude);
    }
    if (currentLocation != null) {
      await prefs.setDouble(_currentLocationLatKey, currentLocation!.latitude);
      await prefs.setDouble(_currentLocationLngKey, currentLocation!.longitude);
    }
    await prefs.setString(
      _placesKey,
      jsonEncode(places.map((place) => place.toJson()).toList()),
    );
    await prefs.setString(
      _itineraryKey,
      jsonEncode(itineraryStops.map((stop) => stop.toJson()).toList()),
    );
    await prefs.setString(
      _eventsKey,
      jsonEncode(events.map((event) => event.toJson()).toList()),
    );
    await prefs.setString(
      _tripsKey,
      jsonEncode(previousTrips.map((trip) => trip.toJson()).toList()),
    );
  }

  Future<void> _persistExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _expensesKey,
      jsonEncode(expenses.map((expense) => expense.toJson()).toList()),
    );
  }

  Future<void> _persistMemories() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _memoriesKey,
      jsonEncode(memories.map((memory) => memory.toJson()).toList()),
    );
  }

  int _nextExpenseId() {
    return expenses.isEmpty
        ? 1
        : expenses
                  .map((expense) => expense.id)
                  .reduce((a, b) => a > b ? a : b) +
              1;
  }

  void _generateItineraryFromPlaces() {
    if (places.isEmpty) {
      itineraryStops = const [];
      return;
    }

    final attractionQueue = [...topPicks, ...landmarkPlaces];
    final cultureQueue = [...museumPlaces, ...restaurantPlaces];
    final mixedQueue = [...places];
    final dayThemes = List<String>.generate(
      tripDays,
      (index) => index == 0
          ? 'attraction'
          : index % 3 == 1
          ? 'culture'
          : 'mixed',
    );
    final timeSlots = ['08:30 AM', '11:00 AM', '01:30 PM', '04:30 PM'];
    final builtStops = <PlannerStop>[];
    final usedIds = <String>{};

    for (var dayIndex = 0; dayIndex < tripDays; dayIndex++) {
      final theme = dayThemes[dayIndex];
      final source = theme == 'attraction'
          ? attractionQueue
          : theme == 'culture'
          ? cultureQueue
          : mixedQueue;

      // Select 3 unique places for this day
      final dailyPlaces = <TravelPlace>[];
      
      // Attempt 1: From preferred source and NOT used before
      for (final p in source) {
        if (!usedIds.contains(p.id)) {
          dailyPlaces.add(p);
          usedIds.add(p.id);
          if (dailyPlaces.length >= 3) break;
        }
      }

      // Attempt 2: Fill remaining from any source and NOT used before
      if (dailyPlaces.length < 3) {
        for (final p in mixedQueue) {
          if (!usedIds.contains(p.id)) {
            dailyPlaces.add(p);
            usedIds.add(p.id);
            if (dailyPlaces.length >= 3) break;
          }
        }
      }

      // Attempt 3: If still not enough, then and only then repeat from previous days
      if (dailyPlaces.length < 3) {
        for (final p in mixedQueue) {
          if (!dailyPlaces.contains(p)) {
            dailyPlaces.add(p);
            if (dailyPlaces.length >= 3) break;
          }
        }
      }

      for (var stopIndex = 0; stopIndex < dailyPlaces.length; stopIndex++) {
        final place = dailyPlaces[stopIndex];
        builtStops.add(
          PlannerStop(
            id: '${dayIndex}_${place.id}',
            dayIndex: dayIndex,
            place: place.name,
            time: timeSlots[stopIndex % timeSlots.length],
            notes: place.address.isEmpty
                ? '${place.category.toUpperCase()} • ${place.distanceKm.toStringAsFixed(1)} km away'
                : '${place.category.toUpperCase()} • ${place.distanceKm.toStringAsFixed(1)} km away • ${place.address}',
            status: stopIndex == 0
                ? 'CONFIRMED'
                : stopIndex == 1
                ? 'PENDING'
                : 'RESERVED',
            category: place.category,
            latitude: place.latitude,
            longitude: place.longitude,
            distanceKm: place.distanceKm,
          ),
        );
      }

      builtStops.add(
        PlannerStop(
          id: '${dayIndex}_hotel',
          dayIndex: dayIndex,
          place: '${cityName.isEmpty ? 'City' : cityName} ${hotelSuggestions[dayIndex % hotelSuggestions.length]}',
          time: '06:30 PM',
          notes: 'Stay: hotel suggestion for this day',
          status: 'SUGGESTED',
          category: 'hotel',
          latitude: (cityCenter?.latitude ?? 0) + (0.001 * (dayIndex + 1)),
          longitude: (cityCenter?.longitude ?? 0) + (0.001 * (dayIndex + 1)),
          distanceKm: 0.4 + (dayIndex * 0.2),
        ),
      );
    }

    itineraryStops = builtStops;
  }

  Future<void> _loadEvents() async {
    if (cityCenter == null) {
      events = const [];
      return;
    }

    final baseDate = tripStartDate ?? DateTime.now();
    final labels = [
      ('Night Market Walk', 'Food'),
      ('Riverside Live Music', 'Music'),
      ('Art District Pop-up', 'Art'),
      ('City Lights Festival', 'Festival'),
    ];

    events = List<TravelEvent>.generate(labels.length, (index) {
      final item = labels[index];
      return TravelEvent(
        id: '${cityName}_${item.$1}_$index',
        name: '${cityName.isEmpty ? 'City' : cityName} ${item.$1}',
        date: baseDate.add(Duration(days: index % tripDays)).toIso8601String(),
        category: item.$2,
        latitude: cityCenter!.latitude + (0.008 * (index + 1)),
        longitude: cityCenter!.longitude - (0.006 * (index + 1)),
        distanceKm: 0.8 + (index * 0.7),
      );
    });
  }

  void _saveCurrentTrip() {
    if (!hasSelectedCity || tripStartDate == null || tripEndDate == null) {
      return;
    }

    final tripId =
        _buildTripId(cityName, tripStartDate!, tripEndDate!);
    final trip = TravelTrip(
      id: tripId,
      destination: cityName,
      cityLabel: cityLabel,
      startDate: tripStartDate!.toIso8601String(),
      endDate: tripEndDate!.toIso8601String(),
      tripDays: tripDays,
      status: tripStatus,
      shareCode: shareCode,
      friends: friends,
    );

    previousTrips = [
      trip,
      ...previousTrips.where((existingTrip) => existingTrip.id != tripId),
    ].take(6).toList();
  }

  Future<void> _detectVisitedPlaces() async {
    if (currentLocation == null) return;

    for (final stop in itineraryStops) {
      final stopPoint = LatLng(stop.latitude, stop.longitude);
      final distanceKm = _distance.as(
        LengthUnit.Kilometer,
        currentLocation!,
        stopPoint,
      );

      if (distanceKm <= 0.2 && !visitedPlaceIds.contains(stop.place)) {
        visitedPlaceIds = [...visitedPlaceIds, stop.place];
        _appendTimeline('Visited ${stop.place}');
        await addMemory(
          description:
              'Auto memory\nVisited ${stop.place} during your trip to $cityName',
          mediaType: 'image',
        );
      }
    }
  }

  void _appendTimeline(String entry) {
    if (timelineEntries.contains(entry)) return;
    timelineEntries = [...timelineEntries, entry];
  }

  String _generateShareCode(String destination) {
    final letters = destination.trim().toUpperCase().replaceAll(' ', '');
    final prefix = letters.isEmpty
        ? 'TRIP'
        : letters.substring(0, letters.length < 4 ? letters.length : 4);
    return '$prefix-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
  }

  String _buildTripId(String destination, DateTime startDate, DateTime endDate) {
    return '${destination.trim()}_${startDate.toIso8601String()}_${endDate.toIso8601String()}';
  }

  Future<_CityResult> _safeGeocodeFallback(String query) async {
    return _CityResult(
      label: query,
      latitude: cityCenter?.latitude ?? 20.5937,
      longitude: cityCenter?.longitude ?? 78.9629,
    );
  }

  List<TravelPlace> _fallbackPlacesFor(String label, double latitude, double longitude) {
    final baseName = label.split(',').first.trim();
    final entries = [
      ('Popular Attraction', 'attraction', 0.8),
      ('City Museum', 'museum', 1.1),
      ('Central Park', 'park', 1.4),
      ('Local Market', 'shopping', 1.7),
      ('View Point', 'viewpoint', 2.0),
      ('Heritage Temple', 'temple', 2.2),
      ('Old Town Square', 'attraction', 2.5),
      ('National Library', 'library', 2.8),
      ('Botanical Garden', 'park', 3.1),
      ('Luxury Shopping Mall', 'shopping', 3.4),
      ('Sky Deck', 'viewpoint', 3.7),
      ('Historic Church', 'temple', 4.0),
    ];
    return entries.asMap().entries.map((entry) {
      final item = entry.value;
      return TravelPlace(
        id: 'fallback_${entry.key}_$baseName',
        name: '$baseName ${item.$1}',
        category: item.$2,
        subcategory: item.$2,
        address: '$baseName center',
        latitude: latitude + (0.004 * (entry.key + 1)),
        longitude: longitude - (0.004 * (entry.key + 1)),
        distanceKm: item.$3,
      );
    }).toList();
  }

  TravelTrip? _tripByStatus(String status) {
    for (final trip in previousTrips) {
      if (trip.status == status) {
        return trip;
      }
    }
    return null;
  }
}

class _CityResult {
  final String label;
  final double latitude;
  final double longitude;

  const _CityResult({
    required this.label,
    required this.latitude,
    required this.longitude,
  });
}
