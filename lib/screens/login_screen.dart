import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _brandIndigo = Color(0xFF2400B8);
  static const _ink = Color(0xFF111111);
  static const _muted = Color(0xFF9A9A9A);

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final provider = context.read<AuthProvider>();
    await provider.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted || provider.state != AuthState.authenticated) return;
    Navigator.pushReplacementNamed(
      context,
      provider.role == UserRole.admin ? '/admin_queue' : '/resident_home',
    );
  }

  void _showForgotPasswordPlaceholder() {
    FocusManager.instance.primaryFocus?.unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Password recovery will be available soon.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          return SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        children: [
                          const _BrandHeader(),
                          const _WelcomeBanner(),
                          Expanded(child: _buildForm(auth)),
                          const _SecurityFooter(),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildForm(AuthProvider auth) {
    final hasError =
        auth.state == AuthState.error ||
        auth.state == AuthState.denied ||
        auth.state == AuthState.sessionExpired;
    final message = auth.state == AuthState.sessionExpired
        ? 'Session expired. Please log in again.'
        : auth.errorMessage ?? 'Access denied.';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(31, 34, 31, 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasError) ...[
                _LoginMessage(message: message),
                const SizedBox(height: 14),
              ],
              const _FieldLabel('Email Address'),
              const SizedBox(height: 3),
              TextField(
                controller: _emailController,
                enabled: auth.state != AuthState.loading,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                style: const TextStyle(fontSize: 14, color: _ink),
                decoration: _fieldDecoration(
                  hintText: 'Enter your email',
                  prefixIcon: Icons.mail_outline_rounded,
                ),
              ),
              const SizedBox(height: 11),
              const _FieldLabel('Password'),
              const SizedBox(height: 3),
              TextField(
                controller: _passwordController,
                enabled: auth.state != AuthState.loading,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) {
                  if (auth.state != AuthState.loading) _handleLogin();
                },
                style: const TextStyle(fontSize: 14, color: _ink),
                decoration: _fieldDecoration(
                  hintText: 'Enter your password',
                  prefixIcon: Icons.lock_outline_rounded,
                  suffix: IconButton(
                    tooltip: _obscurePassword
                        ? 'Show password'
                        : 'Hide password',
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                      color: _ink,
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _showForgotPasswordPlaceholder,
                  style: TextButton.styleFrom(
                    foregroundColor: _brandIndigo,
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  child: const Text('Forgot Password?'),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: auth.state == AuthState.loading
                      ? null
                      : _handleLogin,
                  style: FilledButton.styleFrom(
                    backgroundColor: _brandIndigo,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _brandIndigo.withValues(
                      alpha: 0.55,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  child: auth.state == AuthState.loading
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.2,
                          ),
                        )
                      : const Text('Log in'),
                ),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: auth.state == AuthState.loading
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RegisterScreen(),
                          ),
                        );
                      },
                style: TextButton.styleFrom(
                  foregroundColor: _ink,
                  minimumSize: const Size.fromHeight(36),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                child: const Text('Create a Resident Account'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffix,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _ink, width: 1),
    );
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        color: _muted,
        fontSize: 13,
        fontWeight: FontWeight.w400,
      ),
      prefixIcon: Icon(prefixIcon, size: 22, color: _ink),
      prefixIconConstraints: const BoxConstraints(minWidth: 43),
      suffixIcon: suffix,
      suffixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 48),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
      border: border,
      enabledBorder: border,
      disabledBorder: border.copyWith(
        borderSide: const BorderSide(color: Color(0xFF777777)),
      ),
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: _brandIndigo, width: 1.7),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 115,
      child: Center(
        child: Semantics(
          label: 'HelpHub',
          header: true,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _HelpHubMark(),
              SizedBox(width: 5),
              Text(
                'HelpHub',
                style: TextStyle(
                  color: _LoginScreenState._ink,
                  fontSize: 24,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HelpHubMark extends StatelessWidget {
  const _HelpHubMark();

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 55,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(
            Icons.chat_bubble_outline_rounded,
            size: 55,
            color: _LoginScreenState._brandIndigo,
          ),
          Transform.translate(
            offset: const Offset(0, -2),
            child: const Text(
              'i',
              style: TextStyle(
                color: _LoginScreenState._brandIndigo,
                fontSize: 34,
                height: 1,
                fontWeight: FontWeight.w900,
                fontFamily: 'serif',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 108,
      color: _LoginScreenState._brandIndigo,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.all(Radius.circular(13)),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 21, vertical: 8),
              child: Text(
                'Welcome!',
                style: TextStyle(
                  color: _LoginScreenState._ink,
                  fontSize: 18,
                  height: 1,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Log in to continue helping build a better community',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              height: 1.2,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _SecurityFooter extends StatelessWidget {
  const _SecurityFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 108),
      color: _LoginScreenState._brandIndigo,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      alignment: Alignment.center,
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_user_rounded, color: Colors.white, size: 15),
          SizedBox(width: 2),
          Flexible(
            child: Text(
              'Your data is secured with us.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: _LoginScreenState._ink,
        fontSize: 12,
        height: 1.2,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _LoginMessage extends StatelessWidget {
  const _LoginMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEEEE),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF0B8B8)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFB42318)),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF8F1D16),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
