import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  Map<String, dynamic> _profile = const {};
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  String? _loadedUserId;

  Map<String, dynamic> get profile => _profile;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  bool get isVerified => _profile['status'] == 'approved';
  String get status => (_profile['status'] ?? 'pending').toString();
  bool get isVerificationPending =>
      !isVerified &&
      status != 'rejected' &&
      (_profile['verification_requested_at'] != null ||
          _metadata['verification_submitted'] == true);
  bool get hasLoadedCurrentUser =>
      _loadedUserId != null && _loadedUserId == _supabase.auth.currentUser?.id;

  Map<String, dynamic> get _metadata =>
      Map<String, dynamic>.from(_supabase.auth.currentUser?.userMetadata ?? {});

  String get fullName =>
      (_profile['full_name'] ?? _metadata['full_name'] ?? 'Resident')
          .toString();
  String get firstName =>
      (_profile['first_name'] ?? _metadata['first_name'] ?? _splitName(0))
          .toString();
  String get middleName =>
      (_profile['middle_name'] ?? _metadata['middle_name'] ?? '').toString();
  String get lastName =>
      (_profile['last_name'] ?? _metadata['last_name'] ?? _splitName(-1))
          .toString();
  String get gender =>
      (_profile['gender'] ?? _metadata['gender'] ?? '').toString();
  String get age => (_profile['age'] ?? _metadata['age'] ?? '').toString();
  String get birthday =>
      (_profile['birthday'] ?? _metadata['birthday'] ?? '').toString();
  String get address =>
      (_profile['address'] ?? _metadata['address'] ?? '').toString();
  String get phone =>
      (_profile['phone'] ?? _metadata['phone'] ?? '').toString();
  String get email =>
      (_profile['email'] ?? _supabase.auth.currentUser?.email ?? '').toString();
  String get userId => (_supabase.auth.currentUser?.id ?? '').toString();
  String? get avatarUrl {
    final value = (_profile['avatar_url'] ?? _metadata['avatar_url'])
        ?.toString();
    return value == null || value.isEmpty ? null : value;
  }

  String _splitName(int index) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '';
    return index < 0 ? (parts.length > 1 ? parts.last : '') : parts.first;
  }

  Future<void> loadProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      _profile = const {};
      _loadedUserId = null;
      notifyListeners();
      return;
    }
    if (_loadedUserId != user.id) _profile = const {};
    _loadedUserId = user.id;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final data = await _supabase
          .from('profiles')
          .select()
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
      final basicProfile = <String, dynamic>{
        'full_name': name,
        'phone': phone.trim().isEmpty ? null : phone.trim(),
        'address': address.trim().isEmpty ? null : address.trim(),
      };
      try {
        await _supabase
            .from('profiles')
            .update({
              ...basicProfile,
              'email': email,
              'first_name': firstName.trim(),
              'middle_name': middleName.trim(),
              'last_name': lastName.trim(),
              'gender': gender.trim().isEmpty ? null : gender.trim(),
              'age': int.tryParse(age),
              'birthday': birthday.trim().isEmpty ? null : birthday.trim(),
              'avatar_url': uploadedAvatar,
            })
            .eq('id', user.id);
      } on PostgrestException {
        // Compatibility fallback until the profile-details migration is run.
        await _supabase.from('profiles').update(basicProfile).eq('id', user.id);
      }
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
    if (avatarUrl == null) {
      _errorMessage =
          'A profile photo is required before submitting verification.';
      notifyListeners();
      return false;
    }
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final requestedAt = DateTime.now().toUtc().toIso8601String();
      await _supabase.auth.updateUser(
        UserAttributes(
          data: <String, dynamic>{
            ..._metadata,
            'verification_submitted': true,
            'verification_requested_at': requestedAt,
          },
        ),
      );
      try {
        await _supabase
            .from('profiles')
            .update({
              'status': 'pending',
              'verification_requested_at': requestedAt,
              'full_name': fullName,
              'email': email,
              'first_name': firstName,
              'middle_name': middleName,
              'last_name': lastName,
              'gender': gender.isEmpty ? null : gender,
              'age': int.tryParse(age),
              'birthday': birthday.isEmpty ? null : birthday,
              'phone': phone.isEmpty ? null : phone,
              'address': address.isEmpty ? null : address,
              'avatar_url': avatarUrl,
            })
            .eq('id', user.id);
      } on PostgrestException {
        // Compatibility fallback until the profile-details migration is run.
        await _supabase
            .from('profiles')
            .update({
              'status': 'pending',
              'full_name': fullName,
              'phone': phone.isEmpty ? null : phone,
              'address': address.isEmpty ? null : address,
            })
            .eq('id', user.id);
      }
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
