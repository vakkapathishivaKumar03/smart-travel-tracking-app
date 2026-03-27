class TravelMemory {
  final String id;
  final String description;
  final String mediaType;
  final String timestamp;
  final String? mediaPath;
  final String? mediaBytes;

  const TravelMemory({
    required this.id,
    required this.description,
    required this.mediaType,
    required this.timestamp,
    this.mediaPath,
    this.mediaBytes,
  });

  factory TravelMemory.fromJson(Map<String, dynamic> json) {
    return TravelMemory(
      id: json['id']?.toString() ?? '',
      description: json['description']?.toString() ?? 'Travel memory',
      mediaType: json['mediaType']?.toString() ?? 'image',
      timestamp: json['timestamp']?.toString() ?? DateTime.now().toIso8601String(),
      mediaPath: json['mediaPath']?.toString(),
      mediaBytes: json['mediaBytes']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'description': description,
      'mediaType': mediaType,
      'timestamp': timestamp,
      'mediaPath': mediaPath,
      'mediaBytes': mediaBytes,
    };
  }
}
