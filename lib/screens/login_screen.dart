import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  void _handleLogin() async {
    final provider = Provider.of<AuthProvider>(context, listen: false);
    await provider.login(_usernameController.text, _passwordController.text);
    
    if (!mounted) return;
    
    if (provider.state == AuthState.authenticated) {
      if (provider.role == UserRole.admin) {
        Navigator.pushReplacementNamed(context, '/admin_queue');
      } else {
        Navigator.pushReplacementNamed(context, '/resident_home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<AuthProvider>(
        builder: (context, auth, child) {
          return SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.shield, size: 64, color: AppTheme.primaryBlue),
                  const SizedBox(height: 16),
                  const Text(
                    'HelpHub Entry',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                  ),
                  const SizedBox(height: 48),
                  
                  if (auth.state == AuthState.error || auth.state == AuthState.denied)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.sosRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        auth.errorMessage ?? 'Access Denied',
                        style: const TextStyle(color: AppTheme.sosRed),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    
                  if (auth.state == AuthState.sessionExpired)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.statusHigh.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Session Expired. Please log in again.',
                        style: TextStyle(color: AppTheme.statusHigh),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  TextField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  ElevatedButton(
                    onPressed: auth.state == AuthState.loading ? null : _handleLogin,
                    child: auth.state == AuthState.loading
                        ? const SizedBox(
                            width: 24, height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Login'),
                  ),
                  
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterScreen()));
                    },
                    child: const Text('Create a Resident Account'),
                  ),
                  const Text(
                    'Ensure you have run the Supabase SQL script first!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  )
                ],
              ),
            ),
          ));
        }
      ),
    );
  }
}
