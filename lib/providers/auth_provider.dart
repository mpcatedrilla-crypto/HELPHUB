import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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
  final _supabase = Supabase.instance.client;

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
        // Fetch role from profiles table
        final profile = await _supabase
            .from('profiles')
            .select()
            .eq('id', user.id)
            .single();

        if (profile['status'] != 'approved') {
          _errorMessage = 'Account is pending verification or rejected.';
          await _supabase.auth.signOut();
          _setState(AuthState.denied);
          return;
        }

        if (profile['role'] == 'admin') {
          _role = UserRole.admin;
        } else {
          _role = UserRole.resident;
        }

        _userName = profile['full_name'] ?? email;
        _setState(AuthState.authenticated);
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
        // Update profile
        await _supabase
            .from('profiles')
            .update({
              'full_name': fullName,
              'phone': phone.isEmpty ? null : phone,
              'address': address.isEmpty ? null : address,
              'status': 'pending',
            })
            .eq('id', res.user!.id);

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
    _role = UserRole.guest;
    _userName = null;
    _setState(AuthState.initial);
  }

  void _setState(AuthState newState) {
    _state = newState;
    notifyListeners();
  }
}
