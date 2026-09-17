import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static const _blue = Color(0xFF095BB6);
  static const _indigo = Color(0xFF2400B8);

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  bool _sending = false;
  bool _sent = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail.trim());
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendRecoveryEmail() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _sending = true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        _emailController.text.trim(),
        redirectTo: 'helphub://reset-password',
      );
      if (!mounted) return;
      setState(() => _sent = true);
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyRecoveryError(error.message))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'We could not send the recovery email. Check your connection and try again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _friendlyRecoveryError(String message) {
    final normalized = message.toLowerCase();
    if (normalized.contains('rate') || normalized.contains('seconds')) {
      return 'Please wait a moment before requesting another recovery email.';
    }
    return 'We could not send the recovery email. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          const Positioned.fill(child: _RecoveryBackground()),
          SafeArea(
            child: Column(
              children: [
                _RecoveryHeader(
                  title: _sent ? 'Check Your Email' : 'Forgot Password',
                  onBack: () => Navigator.maybePop(context),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(24, 34, 24, 36),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 240),
                          child: _sent ? _sentPanel() : _requestPanel(),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _requestPanel() {
    return _RecoveryCard(
      key: const ValueKey('request'),
      icon: Icons.lock_reset_rounded,
      title: 'Recover your account',
      description: 'Enter the email connected to your HelpHub account. We will send you a secure link to create a new password.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Email Address',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 7),
            TextFormField(
              controller: _emailController,
              autofocus: widget.initialEmail.isEmpty,
              enabled: !_sending,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.email],
              onFieldSubmitted: (_) => _sendRecoveryEmail(),
              decoration: const InputDecoration(
                hintText: 'Enter your registered email',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
              validator: (value) {
                final email = value?.trim() ?? '';
                if (email.isEmpty) return 'Email address is required.';
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                  return 'Enter a valid email address.';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _sending ? null : _sendRecoveryEmail,
              style: FilledButton.styleFrom(
                backgroundColor: _indigo,
                minimumSize: const Size.fromHeight(50),
              ),
              icon: _sending
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 19),
              label: Text(_sending ? 'Sending…' : 'Send Recovery Link'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _sending ? null : () => Navigator.maybePop(context),
              child: const Text('Return to Log in'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sentPanel() {
    final email = _emailController.text.trim();
    return _RecoveryCard(
      key: const ValueKey('sent'),
      icon: Icons.mark_email_read_rounded,
      title: 'Recovery link sent',
      description:
          'If an account is registered to $email, a password recovery link has been sent. Open it on this phone to continue.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF6FF),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, color: _blue, size: 21),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Check your inbox and spam folder. For your security, the recovery link can only be used for a limited time.',
                    style: TextStyle(fontSize: 12, height: 1.45),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () =>
                Navigator.popUntil(context, (route) => route.isFirst),
            style: FilledButton.styleFrom(
              backgroundColor: _indigo,
              minimumSize: const Size.fromHeight(50),
            ),
            child: const Text('Return to Log in'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _sending ? null : () => setState(() => _sent = false),
            child: const Text('Use a different email'),
          ),
        ],
      ),
    );
  }
}

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  static const _indigo = Color(0xFF2400B8);

  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _saving = false;
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (Supabase.instance.client.auth.currentSession == null) {
      _showExpiredMessage();
      return;
    }

    setState(() => _saving = true);
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _passwordController.text),
      );
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password updated. You can now log in securely.'),
        ),
      );
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to update your password. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showExpiredMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'This recovery link is invalid or expired. Request a new link.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasRecoverySession =
        Supabase.instance.client.auth.currentSession != null;
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          const Positioned.fill(child: _RecoveryBackground()),
          SafeArea(
            child: Column(
              children: [
                _RecoveryHeader(
                  title: 'Create New Password',
                  onBack: () => Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/login',
                    (_) => false,
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(24, 34, 24, 36),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: _RecoveryCard(
                          icon: hasRecoverySession
                              ? Icons.password_rounded
                              : Icons.link_off_rounded,
                          title: hasRecoverySession
                              ? 'Choose a secure password'
                              : 'Recovery link unavailable',
                          description: hasRecoverySession
                              ? 'Use at least eight characters. A combination of letters, numbers, and symbols is recommended.'
                              : 'This recovery link is invalid or has expired. Return to the login page and request a new one.',
                          child: hasRecoverySession
                              ? _passwordForm()
                              : FilledButton(
                                  onPressed: () =>
                                      Navigator.pushNamedAndRemoveUntil(
                                        context,
                                        '/forgot-password',
                                        (_) => false,
                                      ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _indigo,
                                    minimumSize: const Size.fromHeight(50),
                                  ),
                                  child: const Text('Request a New Link'),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _passwordForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _passwordController,
            enabled: !_saving,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            decoration: InputDecoration(
              labelText: 'New Password',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
            ),
            validator: (value) {
              final password = value ?? '';
              if (password.isEmpty) return 'New password is required.';
              if (password.length < 8) {
                return 'Use at least eight characters.';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _confirmPasswordController,
            enabled: !_saving,
            obscureText: _obscureConfirmation,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            onFieldSubmitted: (_) => _updatePassword(),
            decoration: InputDecoration(
              labelText: 'Confirm New Password',
              prefixIcon: const Icon(Icons.lock_reset_rounded),
              suffixIcon: IconButton(
                onPressed: () => setState(
                  () => _obscureConfirmation = !_obscureConfirmation,
                ),
                tooltip: _obscureConfirmation
                    ? 'Show password'
                    : 'Hide password',
                icon: Icon(
                  _obscureConfirmation
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
            ),
            validator: (value) {
              if ((value ?? '').isEmpty) {
                return 'Please confirm your new password.';
              }
              if (value != _passwordController.text) {
                return 'Passwords do not match.';
              }
              return null;
            },
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _saving ? null : _updatePassword,
            style: FilledButton.styleFrom(
              backgroundColor: _indigo,
              minimumSize: const Size.fromHeight(50),
            ),
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.check_circle_outline_rounded, size: 20),
            label: Text(_saving ? 'Updating…' : 'Update Password'),
          ),
        ],
      ),
    );
  }
}

class _RecoveryHeader extends StatelessWidget {
  const _RecoveryHeader({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            color: Colors.white,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _RecoveryCard extends StatelessWidget {
  const _RecoveryCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFDCE8F3)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A0B3D70),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF58D8DF), Color(0xFF095BB6)],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 35),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF10243E),
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF5F6F89),
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }
}

class _RecoveryBackground extends StatelessWidget {
  const _RecoveryBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _RecoveryBackgroundPainter());
  }
}

class _RecoveryBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gradient = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF58D8DF), Color(0xFF095BB6)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, gradient);

    final panel = Path()
      ..moveTo(0, 152)
      ..lineTo(size.width * .16, 108)
      ..lineTo(size.width * .84, 108)
      ..lineTo(size.width, 152)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(panel, Paint()..color = const Color(0xFFF7FAFD));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
