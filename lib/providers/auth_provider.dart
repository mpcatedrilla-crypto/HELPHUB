import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum AuthState { initial, loading, authenticated, error, denied, sessionExpired }
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
      _errorMessage = 'Database connection failure. Have you run the SQL script?';
      _setState(AuthState.error);
    }
  }

  Future<bool> register(String emailOrPhoneEmail, String password, String fullName, String phone, String address) async {
    _setState(AuthState.loading);
    try {
      final AuthResponse res = await _supabase.auth.signUp(
        email: emailOrPhoneEmail,
        password: password,
      );
      
      if (res.user != null) {
        // Update profile
        await _supabase.from('profiles').update({
          'full_name': fullName,
          'phone': phone.isEmpty ? null : phone,
          'address': address.isEmpty ? null : address,
        }).eq('id', res.user!.id);
        
        _errorMessage = 'Registration successful! Wait for admin approval to log in.';
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

  Future<void> logout() async {
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
