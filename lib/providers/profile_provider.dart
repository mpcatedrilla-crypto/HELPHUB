import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  Map<String, dynamic> _profile = const {};
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;

  Map<String, dynamic> get profile => _profile;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  bool get isVerified => _profile['status'] == 'approved';
  String get status => (_profile['status'] ?? 'pending').toString();

  Map<String, dynamic> get _metadata =>
      Map<String, dynamic>.from(_supabase.auth.currentUser?.userMetadata ?? {});

  String get fullName =>
      (_profile['full_name'] ?? _metadata['full_name'] ?? 'Resident')
          .toString();
  String get firstName => (_metadata['first_name'] ?? _splitName(0)).toString();
  String get middleName => (_metadata['middle_name'] ?? '').toString();
  String get lastName => (_metadata['last_name'] ?? _splitName(-1)).toString();
  String get gender => (_metadata['gender'] ?? '').toString();
  String get age => (_metadata['age'] ?? '').toString();
  String get birthday => (_metadata['birthday'] ?? '').toString();
  String get address =>
      (_profile['address'] ?? _metadata['address'] ?? '').toString();
  String get phone =>
      (_profile['phone'] ?? _metadata['phone'] ?? '').toString();
  String get email => (_supabase.auth.currentUser?.email ?? '').toString();
  String? get avatarUrl {
    final value = _metadata['avatar_url']?.toString();
    return value == null || value.isEmpty ? null : value;
  }

  String _splitName(int index) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '';
    return index < 0 ? (parts.length > 1 ? parts.last : '') : parts.first;
  }

  Future<void> loadProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final data = await _supabase
          .from('profiles')
          .select('id, full_name, phone, address, status, role')
          .eq('id', user.id)
          .maybeSingle();
      _profile = data == null ? const {} : Map<String, dynamic>.from(data);
    } catch (error) {
      _errorMessage = 'Unable to load your profile.';
      debugPrint('Profile load failed: $error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateProfile({
    required String firstName,
    required String middleName,
    required String lastName,
    required String gender,
    required String age,
    required String birthday,
    required String address,
    required String phone,
    File? avatar,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      String? uploadedAvatar = avatarUrl;
      if (avatar != null) {
        final extension = avatar.path.split('.').last.toLowerCase();
        final path = '${user.id}/profile.$extension';
        await _supabase.storage
            .from('avatars')
            .upload(path, avatar, fileOptions: const FileOptions(upsert: true));
        uploadedAvatar =
            '${_supabase.storage.from('avatars').getPublicUrl(path)}?v=${DateTime.now().millisecondsSinceEpoch}';
      }

      final name = [
        firstName.trim(),
        middleName.trim(),
        lastName.trim(),
      ].where((part) => part.isNotEmpty).join(' ');
      final metadata = <String, dynamic>{
        ..._metadata,
        'full_name': name,
        'first_name': firstName.trim(),
        'middle_name': middleName.trim(),
        'last_name': lastName.trim(),
        'gender': gender.trim(),
        'age': int.tryParse(age),
        'birthday': birthday.trim(),
        'address': address.trim(),
        'phone': phone.trim(),
        'avatar_url': uploadedAvatar,
      };
      await _supabase.auth.updateUser(UserAttributes(data: metadata));
      await _supabase
          .from('profiles')
          .update({
            'full_name': name,
            'phone': phone.trim().isEmpty ? null : phone.trim(),
            'address': address.trim().isEmpty ? null : address.trim(),
          })
          .eq('id', user.id);
      await loadProfile();
      return true;
    } catch (error) {
      _errorMessage = error is StorageException
          ? 'Profile photo storage is not configured yet.'
          : 'Unable to update your profile.';
      debugPrint('Profile update failed: $error');
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> requestVerification() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _supabase
          .from('profiles')
          .update({'status': 'pending'})
          .eq('id', user.id);
      await loadProfile();
      return true;
    } catch (error) {
      _errorMessage = 'Unable to submit your verification request.';
      debugPrint('Verification request failed: $error');
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
