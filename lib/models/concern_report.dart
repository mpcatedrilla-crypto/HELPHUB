class ConcernReport {
  final String id;
  final String title;
  final String category;
  final String description;
  final String residentId;
  final double latitude;
  final double longitude;
  final int affectedPopulationScale; // 1-5 scale
  final List<String> vulnerableGroups; // e.g., 'Elderly', 'PWD', 'Children', 'Pregnant'
  final DateTime submissionTime;
  
  // Backend populated/managed fields
  final String status; // Submitted, Acknowledged, Assigned, In Progress, Resolved
  final int priorityScore; // 0-100 computed score
  final bool isCriticalOverride;
  final DateTime? responseDeadline;

  ConcernReport({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.residentId,
    required this.latitude,
    required this.longitude,
    required this.affectedPopulationScale,
    required this.vulnerableGroups,
    required this.submissionTime,
    this.status = 'Submitted',
    this.priorityScore = 0,
    this.isCriticalOverride = false,
    this.responseDeadline,
  });

  factory ConcernReport.fromJson(Map<String, dynamic> json) {
    return ConcernReport(
      id: json['id'] as String,
      title: json['title'] as String,
      category: json['category'] as String,
      description: json['description'] as String,
      residentId: json['residentId'] as String,
      latitude: json['latitude'] as double,
      longitude: json['longitude'] as double,
      affectedPopulationScale: json['affectedPopulationScale'] as int,
      vulnerableGroups: List<String>.from(json['vulnerableGroups'] ?? []),
      submissionTime: DateTime.parse(json['submissionTime'] as String),
      status: json['status'] as String? ?? 'Submitted',
      priorityScore: json['priorityScore'] as int? ?? 0,
      isCriticalOverride: json['isCriticalOverride'] as bool? ?? false,
      responseDeadline: json['responseDeadline'] != null 
          ? DateTime.parse(json['responseDeadline'] as String) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'description': description,
      'residentId': residentId,
      'latitude': latitude,
      'longitude': longitude,
      'affectedPopulationScale': affectedPopulationScale,
      'vulnerableGroups': vulnerableGroups,
      'submissionTime': submissionTime.toIso8601String(),
      'status': status,
      'priorityScore': priorityScore,
      'isCriticalOverride': isCriticalOverride,
      'responseDeadline': responseDeadline?.toIso8601String(),
    };
  }
}
