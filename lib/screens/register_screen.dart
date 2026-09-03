import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _passwordController = TextEditingController();

  void _register() {
    if (_formKey.currentState!.validate()) {
      if (_emailController.text.isEmpty && _phoneController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please provide either an Email or Phone Number')),
        );
        return;
      }

      String contactInfo = _emailController.text.isNotEmpty 
          ? _emailController.text 
          : '\@helphub.local';

      Provider.of<AuthProvider>(context, listen: false).register(
        contactInfo,
        _passwordController.text,
        _nameController.text,
        _phoneController.text,
        _addressController.text,
      ).then((success) {
         if (success) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registration submitted! Wait for admin approval.')));
           Navigator.pop(context);
         }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: auth.state == AuthState.loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Resident Registration', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                    const SizedBox(height: 8),
                    const Text('Please fill out the form to request an account. An administrator will verify your residency.'),
                    const SizedBox(height: 24),
                    
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Full Name *', prefixIcon: Icon(Icons.person)),
                      validator: (value) => value!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'Email Address (Optional)', prefixIcon: Icon(Icons.email)),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(labelText: 'Phone Number (Optional)', prefixIcon: Icon(Icons.phone)),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(labelText: 'Home Address (Street, Purok/Block) *', prefixIcon: Icon(Icons.home)),
                      maxLines: 2,
                      validator: (value) => value!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(labelText: 'Password *', prefixIcon: Icon(Icons.lock)),
                      obscureText: true,
                      validator: (value) => value!.length < 6 ? 'Minimum 6 characters' : null,
                    ),
                    const SizedBox(height: 24),
                    
                    if (auth.errorMessage != null && auth.state == AuthState.error)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(auth.errorMessage!, style: const TextStyle(color: AppTheme.sosRed, fontWeight: FontWeight.bold)),
                      ),
                      
                    ElevatedButton(
                      onPressed: _register,
                      child: const Text('Submit Registration'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
