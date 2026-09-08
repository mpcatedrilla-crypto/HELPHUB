import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum AuthState {
  initial,
  loading,
  authenticated,
  error,
  denied,
  sessionExpired,
}

enum UserRole { guest, resident, admin }

class AuthProvider extends ChangeNotifier {
  static const _autoSaveAccountKey = 'helphub_auto_save_account';

  final _supabase = Supabase.instance.client;
  final _preferences = SharedPreferencesAsync();

  AuthState _state = AuthState.initial;
  UserRole _role = UserRole.guest;
  String? _errorMessage;
  String? _userName;

  AuthState get state => _state;
  UserRole get role => _role;
  String? get errorMessage => _errorMessage;
  String? get userName => _userName;

  Future<void> login(String email, String password) async {
    _setState(AuthState.loading);
    try {
      final AuthResponse res = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = res.user;
      if (user != null) {
        await _loadAuthenticatedUser(user, fallbackName: email);
      }
    } on AuthException catch (e) {
      _errorMessage = e.message;
      _setState(AuthState.error);
    } catch (e) {
      _errorMessage =
          'Database connection failure. Have you run the SQL script?';
      _setState(AuthState.error);
    }
  }

  Future<bool> restoreSavedAccount() async {
    final enabled = await _preferences.getBool(_autoSaveAccountKey) ?? false;
    if (!enabled) return false;

    final user = _supabase.auth.currentUser;
    if (user == null) {
      await _preferences.remove(_autoSaveAccountKey);
      return false;
    }

    _setState(AuthState.loading);
    try {
      await _loadAuthenticatedUser(
        user,
        fallbackName: user.email ?? 'Resident',
      );
      return _state == AuthState.authenticated;
    } catch (_) {
      await _preferences.remove(_autoSaveAccountKey);
      _errorMessage = 'Your saved session expired. Please log in again.';
      _setState(AuthState.sessionExpired);
      return false;
    }
  }

  Future<void> setAutoSaveAccount(bool enabled) async {
    await _preferences.setBool(_autoSaveAccountKey, enabled);
  }

  Future<void> _loadAuthenticatedUser(
    User user, {
    required String fallbackName,
  }) async {
    final profile = await _supabase
        .from('profiles')
        .select()
        .eq('id', user.id)
        .single();

    if (profile['status'] == 'rejected') {
      _errorMessage = 'This account verification request was rejected.';
      await _preferences.remove(_autoSaveAccountKey);
      await _supabase.auth.signOut();
      _setState(AuthState.denied);
      return;
    }

    _role = profile['role'] == 'admin' ? UserRole.admin : UserRole.resident;
    _userName = profile['full_name'] ?? fallbackName;
    _errorMessage = null;
    _setState(AuthState.authenticated);
  }

  Future<bool> register(
    String email,
    String password,
    String fullName,
    String phone,
    String address, {
    String? firstName,
    String? middleName,
    String? lastName,
    int? age,
    DateTime? birthday,
  }) async {
    _setState(AuthState.loading);
    try {
      final metadata =
          <String, dynamic>{
            'full_name': fullName,
            'first_name': firstName,
            'middle_name': middleName,
            'last_name': lastName,
            'age': age,
            'birthday': birthday?.toIso8601String().split('T').first,
            'phone': phone,
            'address': address,
          }..removeWhere(
            (key, value) => value == null || (value is String && value.isEmpty),
          );

      final trimmedEmail = email.trim();
      final AuthResponse res;
      if (trimmedEmail.isNotEmpty) {
        res = await _supabase.auth.signUp(
          email: trimmedEmail,
          password: password,
          data: metadata,
        );
      } else {
        res = await _supabase.auth.signUp(
          phone: _normalizePhilippinePhone(phone),
          password: password,
          data: metadata,
        );
      }

      if (res.user != null) {
        final basicProfile = <String, dynamic>{
          'full_name': fullName,
          'phone': phone.isEmpty ? null : phone,
          'address': address.isEmpty ? null : address,
          'status': 'pending',
        };
        try {
          await _supabase
              .from('profiles')
              .update({
                ...basicProfile,
                'email': trimmedEmail.isEmpty ? null : trimmedEmail,
                'first_name': firstName,
                'middle_name': middleName,
                'last_name': lastName,
                'age': age,
                'birthday': birthday?.toIso8601String().split('T').first,
              })
              .eq('id', res.user!.id);
        } on PostgrestException {
          // Compatibility fallback until the profile-details migration is run.
          await _supabase
              .from('profiles')
              .update(basicProfile)
              .eq('id', res.user!.id);
        }

        _errorMessage =
            'Registration successful! Wait for admin approval to log in.';
        _setState(AuthState.error); // Show message on login screen
        return true;
      }
      return false;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      _setState(AuthState.error);
      return false;
    } catch (e) {
      _errorMessage = 'Error: $e';
      _setState(AuthState.error);
      return false;
    }
  }

  String _normalizePhilippinePhone(String value) {
    final trimmed = value.trim();
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (trimmed.startsWith('+')) return '+$digits';
    if (digits.startsWith('09')) return '+63${digits.substring(1)}';
    if (digits.startsWith('9')) return '+63$digits';
    if (digits.startsWith('63')) return '+$digits';
    return '+$digits';
  }

  Future<void> logout() async {
    // Remove this device while the authenticated RLS context still exists.
    // This prevents signed-out admins from continuing to receive SOS alerts.
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _supabase.from('admin_push_tokens').delete().eq('token', token);
      }
    } catch (error) {
      debugPrint('Unable to unregister push token during logout: $error');
    }
    await _supabase.auth.signOut();
    await _preferences.remove(_autoSaveAccountKey);
    _role = UserRole.guest;
    _userName = null;
    _setState(AuthState.initial);
  }

  void _setState(AuthState newState) {
    _state = newState;
    notifyListeners();
  }
}
