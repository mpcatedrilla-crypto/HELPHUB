import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import 'register_screen.dart';

class ModernLoginScreen extends StatefulWidget {
  const ModernLoginScreen({super.key});

  @override
  State<ModernLoginScreen> createState() => _ModernLoginScreenState();
}

class _ModernLoginScreenState extends State<ModernLoginScreen> {
  static const _ink = Color(0xFF101010);
  static const _blue = Color(0xFF095BB6);
  static const _cyan = Color(0xFF58D8DF);
  static const _muted = Color(0xFFA3A3A3);

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _pageScrollController = ScrollController();
  bool _obscurePassword = true;
  bool _checkingSavedAccount = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: _blue,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreSavedAccount());
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _pageScrollController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final auth = context.read<AuthProvider>();
    await auth.login(_emailController.text.trim(), _passwordController.text);
    if (!mounted || auth.state != AuthState.authenticated) return;
    final saveAccount = await _showSaveAccountPrompt(auth.role);
    if (!mounted) return;
    await auth.setAutoSaveAccount(saveAccount);
    if (!mounted) return;
    Navigator.pushReplacementNamed(
      context,
      auth.role == UserRole.admin ? '/admin_queue' : '/resident_home',
    );
  }

  Future<void> _restoreSavedAccount() async {
    final auth = context.read<AuthProvider>();
    final restored = await auth.restoreSavedAccount();
    if (!mounted) return;
    if (restored) {
      Navigator.pushReplacementNamed(
        context,
        auth.role == UserRole.admin ? '/admin_queue' : '/resident_home',
      );
      return;
    }
    setState(() => _checkingSavedAccount = false);
  }

  Future<bool> _showSaveAccountPrompt(UserRole role) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _SaveAccountSheet(isAdministrator: role == UserRole.admin),
    );
    return result ?? false;
  }

  void _forgotPassword() {
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
      backgroundColor: _blue,
      resizeToAvoidBottomInset: false,
      body: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
              final designHeight = constraints.maxHeight < 640
                  ? 640.0
                  : constraints.maxHeight;
              final canvas = SizedBox(
                height: designHeight,
                child: CustomPaint(
                  painter: const _GeometricLoginPainter(),
                  child: Column(
                    children: [
                      const SizedBox(
                        height: 170,
                        child: SafeArea(
                          bottom: false,
                          child: Center(child: _CrestLogo()),
                        ),
                      ),
                      Expanded(child: Center(child: _loginPanel(auth))),
                      const _SecureFooter(),
                    ],
                  ),
                ),
              );
              return Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [_cyan, _blue]),
                ),
                child: SingleChildScrollView(
                  controller: _pageScrollController,
                  primary: false,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.only(bottom: keyboardInset),
                  child: canvas,
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _loginPanel(AuthProvider auth) {
    final hasError =
        auth.state == AuthState.error ||
        auth.state == AuthState.denied ||
        auth.state == AuthState.sessionExpired;
    final errorMessage = auth.state == AuthState.sessionExpired
        ? 'Session expired. Please log in again.'
        : auth.errorMessage ?? 'Access denied.';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(31, 13, 31, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Welcome!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _ink,
                  fontSize: 18,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Log in to continue helping build a better community',
                textAlign: TextAlign.center,
                style: TextStyle(color: _ink, fontSize: 11, height: 1.2),
              ),
              const SizedBox(height: 49),
              if (hasError) ...[
                _LoginError(errorMessage),
                const SizedBox(height: 10),
              ],
              const _Label('Email Address'),
              const SizedBox(height: 3),
              TextField(
                controller: _emailController,
                scrollPadding: const EdgeInsets.only(bottom: 140),
                enabled:
                    auth.state != AuthState.loading && !_checkingSavedAccount,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                style: const TextStyle(fontSize: 13, color: _ink),
                decoration: _fieldDecoration(
                  hint: 'Enter your email',
                  prefix: Icons.mail_outline_rounded,
                ),
              ),
              const SizedBox(height: 10),
              const _Label('Password'),
              const SizedBox(height: 3),
              TextField(
                controller: _passwordController,
                scrollPadding: const EdgeInsets.only(bottom: 140),
                enabled:
                    auth.state != AuthState.loading && !_checkingSavedAccount,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) {
                  if (auth.state != AuthState.loading &&
                      !_checkingSavedAccount) {
                    _login();
                  }
                },
                style: const TextStyle(fontSize: 13, color: _ink),
                decoration: _fieldDecoration(
                  hint: 'Enter your password',
                  prefix: Icons.lock_outline_rounded,
                  suffix: IconButton(
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    tooltip: _obscurePassword
                        ? 'Show password'
                        : 'Hide password',
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 19,
                      color: _ink,
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _forgotPassword,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF2400B8),
                    minimumSize: const Size(0, 31),
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  child: const Text('Forgot Password?'),
                ),
              ),
              const SizedBox(height: 12),
              _GradientLoginButton(
                loading:
                    auth.state == AuthState.loading || _checkingSavedAccount,
                onPressed: _login,
              ),
              TextButton(
                onPressed:
                    auth.state == AuthState.loading || _checkingSavedAccount
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RegisterScreen(),
                        ),
                      ),
                style: TextButton.styleFrom(
                  foregroundColor: _ink,
                  minimumSize: const Size.fromHeight(36),
                  textStyle: const TextStyle(
                    fontSize: 11,
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
    required String hint,
    required IconData prefix,
    Widget? suffix,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _ink),
    );
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _muted, fontSize: 12),
      prefixIcon: Icon(prefix, size: 21, color: _ink),
      prefixIconConstraints: const BoxConstraints(minWidth: 42),
      suffixIcon: suffix,
      suffixIconConstraints: const BoxConstraints(minWidth: 43, minHeight: 48),
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 15),
      enabledBorder: border,
      disabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: _blue, width: 1.6),
      ),
    );
  }
}

class _GeometricLoginPainter extends CustomPainter {
  const _GeometricLoginPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()
      ..shader = const LinearGradient(
        colors: [_ModernLoginScreenState._cyan, _ModernLoginScreenState._blue],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, background);

    final upperBlue = Path()
      ..moveTo(size.width * .63, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, 170)
      ..lineTo(size.width * .23, 170)
      ..close();
    canvas.drawPath(upperBlue, Paint()..color = const Color(0xFF1167BA));

    final footerTop = size.height - 108;
    final whitePanel = Path()
      ..moveTo(size.width * .23, 170)
      ..lineTo(size.width * .81, 170)
      ..lineTo(size.width, 274)
      ..lineTo(size.width, footerTop)
      ..lineTo(0, footerTop)
      ..lineTo(0, 272)
      ..close();
    canvas.drawPath(whitePanel, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CrestLogo extends StatelessWidget {
  const _CrestLogo();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      label: 'HelpHub',
      child: Image.asset(
        'assets/images/helphub_crest.png',
        width: 122,
        height: 128,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) =>
            const CustomPaint(size: Size(105, 94), painter: _CrestPainter()),
      ),
    );
  }
}

class _CrestPainter extends CustomPainter {
  const _CrestPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = const Color(0xFF0755B6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    final shield = Path()
      ..moveTo(size.width * .5, 6)
      ..cubicTo(size.width * .38, 15, size.width * .3, 11, size.width * .22, 7)
      ..lineTo(size.width * .18, 39)
      ..cubicTo(size.width * .2, 60, size.width * .34, 73, size.width * .5, 82)
      ..cubicTo(size.width * .66, 73, size.width * .8, 60, size.width * .82, 39)
      ..lineTo(size.width * .78, 7)
      ..cubicTo(size.width * .7, 11, size.width * .62, 15, size.width * .5, 6)
      ..close();
    canvas.drawPath(shield, line);
    canvas.drawPath(
      Path()
        ..moveTo(size.width * .5, 12)
        ..cubicTo(
          size.width * .39,
          19,
          size.width * .31,
          17,
          size.width * .26,
          14,
        )
        ..lineTo(size.width * .23, 39)
        ..cubicTo(
          size.width * .25,
          56,
          size.width * .36,
          66,
          size.width * .5,
          74,
        )
        ..cubicTo(
          size.width * .64,
          66,
          size.width * .75,
          56,
          size.width * .77,
          39,
        )
        ..lineTo(size.width * .74, 14)
        ..cubicTo(
          size.width * .69,
          17,
          size.width * .61,
          19,
          size.width * .5,
          12,
        ),
      line,
    );

    final leftStem = Path()
      ..moveTo(size.width * .44, 89)
      ..cubicTo(size.width * .18, 80, 7, 61, 8, 35);
    final rightStem = Path()
      ..moveTo(size.width * .56, 89)
      ..cubicTo(size.width * .82, 80, size.width - 7, 61, size.width - 8, 35);
    canvas.drawPath(leftStem, line);
    canvas.drawPath(rightStem, line);

    final leaf = Paint()
      ..color = const Color(0xFF0755B6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (var i = 0; i < 6; i++) {
      final y = 39 + i * 7.3;
      final spread = 10 + i * 3.1;
      _drawLeaf(canvas, Offset(spread, y), -.75, leaf);
      _drawLeaf(canvas, Offset(spread + 7, y + 4), .55, leaf);
      _drawLeaf(canvas, Offset(size.width - spread, y), .75, leaf);
      _drawLeaf(canvas, Offset(size.width - spread - 7, y + 4), -.55, leaf);
    }
  }

  void _drawLeaf(Canvas canvas, Offset center, double rotation, Paint paint) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.drawOval(const Rect.fromLTWH(-2.2, -5, 4.4, 10), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GradientLoginButton extends StatelessWidget {
  const _GradientLoginButton({required this.loading, required this.onPressed});

  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 245,
        height: 39,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: loading
                  ? const [Color(0x9958D8DF), Color(0x99095BB6)]
                  : const [
                      _ModernLoginScreenState._cyan,
                      _ModernLoginScreenState._blue,
                    ],
            ),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: loading ? null : onPressed,
              borderRadius: BorderRadius.circular(9),
              child: Center(
                child: loading
                    ? const SizedBox.square(
                        dimension: 17,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Log in',
                        style: TextStyle(color: Colors.white, fontSize: 11),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SaveAccountSheet extends StatelessWidget {
  const _SaveAccountSheet({required this.isAdministrator});

  final bool isAdministrator;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              margin: const EdgeInsets.only(bottom: 22),
              decoration: BoxDecoration(
                color: const Color(0xFFD3D6DB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Container(
              width: 68,
              height: 68,
              decoration: const BoxDecoration(
                color: Color(0xFFE9F7FC),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isAdministrator
                    ? Icons.admin_panel_settings_rounded
                    : Icons.account_circle_rounded,
                color: _ModernLoginScreenState._blue,
                size: 44,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Save this account?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _ModernLoginScreenState._ink,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isAdministrator
                  ? 'Stay signed in on this trusted phone for faster access to the priority queue, SOS alerts, and administrator tools.'
                  : 'Stay signed in on this phone for faster access to SOS, reports, and community updates.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF5F646B),
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    color: _ModernLoginScreenState._blue,
                    size: 19,
                  ),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'HelpHub will not store your password.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF4E535A)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.check_circle_outline_rounded, size: 19),
                label: const Text('Save Account'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2400B8),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF5D6269),
                minimumSize: const Size.fromHeight(42),
              ),
              child: const Text('Not now'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecureFooter extends StatelessWidget {
  const _SecureFooter();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 108,
      child: SafeArea(
        top: false,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified_user_rounded, color: Colors.white, size: 14),
              SizedBox(width: 2),
              Text(
                'Your data is secured with us.',
                style: TextStyle(color: Colors.white, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: _ModernLoginScreenState._ink,
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _LoginError extends StatelessWidget {
  const _LoginError(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEEEE),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFFF0B8B8)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFB42318),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF8F1D16),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
