import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReportProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  bool _isLoading = false;
  String? _errorMessage;

  List<Map<String, dynamic>> _myReports = [];
  List<Map<String, dynamic>> _allReports = [];
  List<Map<String, dynamic>> _concernTypes = [];

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<Map<String, dynamic>> get myReports => _myReports;
  List<Map<String, dynamic>> get allReports => _allReports;
  List<Map<String, dynamic>> get concernTypes => _concernTypes;

  // Derived metrics for Dashboard
  int get activeReportsCount => _myReports.where((r) => r['status'] != 'resolved').length;
  int get resolvedReportsCount => _myReports.where((r) => r['status'] == 'resolved').length;

  Future<void> fetchConcernTypes() async {
    try {
      final response = await _supabase
          .from('concern_types')
          .select('id, category_name')
          .order('category_name');
      _concernTypes = List<Map<String, dynamic>>.from(response);
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching concern types: $e');
    }
  }

  Future<void> fetchMyReports() async {
    _setLoading(true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await _supabase
          .from('reports')
          .select('*, concern_types(category_name), report_evidence(storage_path)')
          .eq('resident_id', userId)
          .order('created_at', ascending: false);
      
      _myReports = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      _errorMessage = 'Failed to load reports: $e';
    } finally {
      _setLoading(false);
    }
  }

  Future<void> fetchAllReports() async {
    _setLoading(true);
    try {
      // Order by priority score descending, then created_at
      final response = await _supabase
          .from('reports')
          .select('*, concern_types(category_name), profiles(full_name), report_evidence(storage_path)')
          .order('is_critical_override', ascending: false)
          .order('priority_score', ascending: false)
          .order('created_at', ascending: true);
      
      _allReports = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      _errorMessage = 'Failed to load queue: $e';
    } finally {
      _setLoading(false);
    }
  }

  String getEvidenceUrl(String storagePath) {
    return _supabase.storage.from('evidence').getPublicUrl(storagePath);
  }

  Future<bool> submitReport({
    required String typeId,
    required String title,
    required String description,
    required int populationScale,
    required List<String> vulnerableGroups,
    bool isEmergency = false,
    double? latitude,
    double? longitude,
    String? addressNotes,
    List<File>? evidenceImages,
  }) async {
    _setLoading(true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Not logged in');

      // Basic local priority calculation
      int score = isEmergency ? 100 : (populationScale * 10);

      // Insert report and get the generated ID
      final reportRes = await _supabase.from('reports').insert({
        'resident_id': userId,
        'concern_type_id': typeId,
        'title': title,
        'description': description,
        'resident_declared_urgency': populationScale,
        'affected_people_count': populationScale,
        'vulnerable_groups': vulnerableGroups,
        'is_critical_override': isEmergency,
        'priority_score': score,
        'status': 'submitted',
        'address_notes': addressNotes, // Optional textual address
      }).select('id').single();

      final reportId = reportRes['id'];

      // If we have GPS coordinates, insert them into report_locations
      if (latitude != null && longitude != null) {
        await _supabase.from('report_locations').insert({
          'report_id': reportId,
          'latitude': latitude,
          'longitude': longitude,
          'accuracy': 10.0, // Mock accuracy
        });
      }

      // Upload Evidence Images
      if (evidenceImages != null && evidenceImages.isNotEmpty) {
        for (var i = 0; i < evidenceImages.length; i++) {
          final file = evidenceImages[i];
          final fileExt = file.path.split('.').last;
          final fileName = '${DateTime.now().millisecondsSinceEpoch}_$i.$fileExt';
          final storagePath = '$userId/$reportId/$fileName';
          
          // Upload to Supabase Storage
          await _supabase.storage.from('evidence').upload(storagePath, file);
          
          // Link in database
          await _supabase.from('report_evidence').insert({
            'report_id': reportId,
            'storage_path': storagePath,
          });
        }
      }
      
      // Refresh list
      await fetchMyReports();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to submit: $e';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateReportStatus(String reportId, String newStatus) async {
    try {
      await _supabase
          .from('reports')
          .update({'status': newStatus})
          .eq('id', reportId);
      
      // Refresh queue
      await fetchAllReports();
      return true;
    } catch (e) {
      _errorMessage = 'Update failed: $e';
      notifyListeners();
      return false;
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
