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
          .select('*, concern_types(category_name)')
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
          .select('*, concern_types(category_name), profiles(full_name)')
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

  Future<bool> submitReport({
    required String typeId,
    required String title,
    required String description,
    required int populationScale,
    required List<String> vulnerableGroups,
    bool isEmergency = false,
  }) async {
    _setLoading(true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Not logged in');

      // Basic local priority calculation (Backend priority_engine will override this in reality, 
      // but for frontend UX we assign a base score to show up on admin queue immediately).
      int score = isEmergency ? 100 : (populationScale * 10);

      await _supabase.from('reports').insert({
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
      });
      
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
