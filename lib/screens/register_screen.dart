import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const _brand = Color(0xFF095BB6);
  static const _cyan = Color(0xFF58D8DF);
  static const _ink = Color(0xFF111111);
  static const _muted = Color(0xFF9A9A9A);

  final _personalKey = GlobalKey<FormState>();
  final _accountKey = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _middle = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _age = TextEditingController();
  final _birthdayText = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();

  int _step = 0;
  DateTime? _birthday;
  bool _hidePassword = true;
  bool _hideConfirmation = true;

  @override
  void dispose() {
    for (final controller in [
      _first,
      _last,
      _middle,
      _email,
      _address,
      _age,
      _birthdayText,
      _phone,
      _password,
      _confirmation,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _next() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_personalKey.currentState?.validate() ?? false) {
      setState(() => _step = 1);
    }
  }

  void _back() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _step = 0);
  }

  Future<void> _pickBirthday() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(now.year - 120),
      lastDate: now,
      helpText: 'Select birthday',
    );
    if (date == null || !mounted) return;
    setState(() {
      _birthday = date;
      _birthdayText.text =
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.day.toString().padLeft(2, '0')}/${date.year}';
    });
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_accountKey.currentState?.validate() ?? false)) return;
    final fullName = [
      _first.text.trim(),
      _middle.text.trim(),
      _last.text.trim(),
    ].where((part) => part.isNotEmpty).join(' ');
    final auth = context.read<AuthProvider>();
    final success = await auth.register(
      _email.text.trim(),
      _password.text,
      fullName,
      _phone.text.trim(),
      _address.text.trim(),
      firstName: _first.text.trim(),
      middleName: _middle.text.trim(),
      lastName: _last.text.trim(),
      age: int.tryParse(_age.text),
      birthday: _birthday,
    );
    if (!mounted || !success) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Registration submitted! Wait for admin approval.'),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _step == 1) _back();
      },
      child: Scaffold(
        backgroundColor: _brand,
        resizeToAvoidBottomInset: true,
        body: Consumer<AuthProvider>(
          builder: (context, auth, _) {
            return LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: CustomPaint(
                        painter: _RegistrationBackgroundPainter(
                          showFooter: _step == 1,
                        ),
                        child: Column(
                          children: [
                            const SizedBox(
                              height: 170,
                              child: SafeArea(
                                bottom: false,
                                child: Center(child: _RegistrationCrest()),
                              ),
                            ),
                            Expanded(
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 520,
                                  ),
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 260),
                                    transitionBuilder: (child, animation) {
                                      return FadeTransition(
                                        opacity: animation,
                                        child: SlideTransition(
                                          position:
                                              Tween<Offset>(
                                                begin: Offset(
                                                  _step == 1 ? .06 : -.06,
                                                  0,
                                                ),
                                                end: Offset.zero,
                                              ).animate(
                                                CurvedAnimation(
                                                  parent: animation,
                                                  curve: Curves.easeOutCubic,
                                                ),
                                              ),
                                          child: child,
                                        ),
                                      );
                                    },
                                    child: _step == 0
                                        ? _personalStep(auth)
                                        : _accountStep(auth),
                                  ),
                                ),
                              ),
                            ),
                            if (_step == 1) const SizedBox(height: 41),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _personalStep(AuthProvider auth) {
    return Form(
      key: _personalKey,
      child: Padding(
        key: const ValueKey('personal'),
        padding: const EdgeInsets.fromLTRB(35, 9, 33, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Column(
                children: [
                  Text(
                    'Create account',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Log in to continue helping build a better community',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _ink, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 39),
            _Field(
              label: 'First Name',
              required: true,
              controller: _first,
              hint: 'Enter your first name',
              action: TextInputAction.next,
              autofillHints: const [AutofillHints.givenName],
              validator: _required,
            ),
            _Field(
              label: 'Last Name',
              required: true,
              controller: _last,
              hint: 'Enter your last name',
              action: TextInputAction.next,
              autofillHints: const [AutofillHints.familyName],
              validator: _required,
            ),
            _Field(
              label: 'Middle Name',
              controller: _middle,
              hint: 'Enter your middle name',
              action: TextInputAction.next,
              autofillHints: const [AutofillHints.middleName],
            ),
            _Field(
              label: 'Email Address',
              controller: _email,
              hint: 'Enter your email address',
              keyboard: TextInputType.emailAddress,
              action: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              validator: (value) {
                final email = value?.trim() ?? '';
                if (email.isEmpty) return null;
                return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)
                    ? null
                    : 'Enter a valid email address';
              },
            ),
            _Field(
              label: 'Home Address',
              required: true,
              controller: _address,
              hint: '(Street, Purok/Block)',
              action: TextInputAction.done,
              autofillHints: const [AutofillHints.fullStreetAddress],
              validator: _required,
              onSubmitted: (_) => _next(),
            ),
            const SizedBox(height: 15),
            _GradientRegistrationButton(
              width: 55,
              height: 40,
              label: 'Next',
              loading: false,
              onPressed: auth.state == AuthState.loading ? null : _next,
            ),
          ],
        ),
      ),
    );
  }

  Widget _accountStep(AuthProvider auth) {
    final showError =
        auth.state == AuthState.error && auth.errorMessage != null;
    return Form(
      key: _accountKey,
      child: Padding(
        key: const ValueKey('account'),
        padding: const EdgeInsets.fromLTRB(34, 10, 34, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Create account',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _ink,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Join and be part of a stronger community',
              textAlign: TextAlign.center,
              style: TextStyle(color: _ink, fontSize: 11),
            ),
            const SizedBox(height: 18),
            _Field(
              label: 'Age',
              required: true,
              controller: _age,
              hint: 'Enter your age',
              keyboard: TextInputType.number,
              action: TextInputAction.next,
              formatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) {
                final age = int.tryParse(value?.trim() ?? '');
                if (age == null) return 'Age is required';
                return age < 1 || age > 120 ? 'Enter a valid age' : null;
              },
            ),
            _Field(
              label: 'Birthday',
              required: true,
              controller: _birthdayText,
              hint: '(MM/DD/YYYY)',
              readOnly: true,
              onTap: _pickBirthday,
              suffix: const Icon(
                Icons.calendar_today_outlined,
                size: 18,
                color: _ink,
              ),
              validator: (_) =>
                  _birthday == null ? 'Birthday is required' : null,
            ),
            _Field(
              label: 'Phone Number',
              required: true,
              controller: _phone,
              hint: 'Enter your phone number',
              keyboard: TextInputType.phone,
              action: TextInputAction.next,
              autofillHints: const [AutofillHints.telephoneNumber],
              formatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+ -]')),
              ],
              validator: (value) {
                final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
                if (digits.isEmpty) return 'Phone number is required';
                return digits.length < 10 || digits.length > 15
                    ? 'Enter a valid phone number'
                    : null;
              },
            ),
            _Field(
              label: 'Password',
              required: true,
              controller: _password,
              hint: 'Enter password',
              obscure: _hidePassword,
              action: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              suffix: _visibility(_hidePassword, () {
                setState(() => _hidePassword = !_hidePassword);
              }),
              validator: (value) =>
                  (value?.length ?? 0) < 6 ? 'Use at least 6 characters' : null,
            ),
            _Field(
              label: 'Confirm Password',
              required: true,
              controller: _confirmation,
              hint: 'Confirm password',
              obscure: _hideConfirmation,
              action: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              suffix: _visibility(_hideConfirmation, () {
                setState(() => _hideConfirmation = !_hideConfirmation);
              }),
              validator: (value) {
                if (value?.isEmpty ?? true) return 'Confirm your password';
                return value != _password.text
                    ? 'Passwords do not match'
                    : null;
              },
              onSubmitted: (_) {
                if (auth.state != AuthState.loading) _submit();
              },
            ),
            if (showError) ...[
              const SizedBox(height: 6),
              _ErrorMessage(auth.errorMessage!),
            ],
            const SizedBox(height: 14),
            _GradientRegistrationButton(
              width: 246,
              height: 41,
              label: 'Submit Registration',
              loading: auth.state == AuthState.loading,
              onPressed: auth.state == AuthState.loading ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }

  String? _required(String? value) =>
      (value?.trim().isEmpty ?? true) ? 'This field is required' : null;

  Widget _visibility(bool hidden, VoidCallback onPressed) {
    return IconButton(
      onPressed: onPressed,
      tooltip: hidden ? 'Show password' : 'Hide password',
      icon: Icon(
        hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        size: 19,
        color: _ink,
      ),
    );
  }
}

class _RegistrationBackgroundPainter extends CustomPainter {
  const _RegistrationBackgroundPainter({required this.showFooter});

  final bool showFooter;

  @override
  void paint(Canvas canvas, Size size) {
    final gradient = Paint()
      ..shader = const LinearGradient(
        colors: [_RegisterScreenState._cyan, _RegisterScreenState._brand],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, gradient);

    final upperBlue = Path()
      ..moveTo(size.width * .63, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, 170)
      ..lineTo(size.width * .23, 170)
      ..close();
    canvas.drawPath(upperBlue, Paint()..color = const Color(0xFF1167BA));

    final white = Path()
      ..moveTo(size.width * .23, 170)
      ..lineTo(size.width * .81, 170)
      ..lineTo(size.width, 274);
    if (showFooter) {
      final footerTop = size.height - 41;
      white
        ..lineTo(size.width, footerTop - 74)
        ..lineTo(size.width * .81, footerTop)
        ..lineTo(size.width * .17, footerTop)
        ..lineTo(0, footerTop - 59);
    } else {
      white
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height);
    }
    white
      ..lineTo(0, 272)
      ..close();
    canvas.drawPath(white, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _RegistrationBackgroundPainter oldDelegate) {
    return oldDelegate.showFooter != showFooter;
  }
}

class _RegistrationCrest extends StatelessWidget {
  const _RegistrationCrest();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      label: 'HelpHub',
      child: SizedBox(
        width: 125,
        height: 125,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            const Positioned(
              top: 7,
              child: Text(
                'HelpHub',
                style: TextStyle(
                  color: Color(0xFFD0D0D0),
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .3,
                  shadows: [
                    Shadow(
                      color: Color(0x66000000),
                      blurRadius: 2,
                      offset: Offset(1, 2),
                    ),
                  ],
                ),
              ),
            ),
            const Positioned(
              top: 28,
              child: CustomPaint(
                size: Size(105, 94),
                painter: _RegistrationCrestPainter(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegistrationCrestPainter extends CustomPainter {
  const _RegistrationCrestPainter();

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
    canvas.drawPath(
      Path()
        ..moveTo(size.width * .44, 89)
        ..cubicTo(size.width * .18, 80, 7, 61, 8, 35),
      line,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width * .56, 89)
        ..cubicTo(size.width * .82, 80, size.width - 7, 61, size.width - 8, 35),
      line,
    );
    final leaf = Paint()
      ..color = const Color(0xFF0755B6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (var i = 0; i < 6; i++) {
      final y = 39 + i * 7.3;
      final spread = 10 + i * 3.1;
      _leaf(canvas, Offset(spread, y), -.75, leaf);
      _leaf(canvas, Offset(spread + 7, y + 4), .55, leaf);
      _leaf(canvas, Offset(size.width - spread, y), .75, leaf);
      _leaf(canvas, Offset(size.width - spread - 7, y + 4), -.55, leaf);
    }
  }

  void _leaf(Canvas canvas, Offset center, double rotation, Paint paint) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.drawOval(const Rect.fromLTWH(-2.2, -5, 4.4, 10), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GradientRegistrationButton extends StatelessWidget {
  const _GradientRegistrationButton({
    required this.width,
    required this.height,
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  final double width;
  final double height;
  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: label == 'Next' ? Alignment.centerLeft : Alignment.center,
      child: SizedBox(
        width: width,
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: onPressed == null
                  ? const [Color(0x9958D8DF), Color(0x99095BB6)]
                  : const [
                      _RegisterScreenState._cyan,
                      _RegisterScreenState._brand,
                    ],
            ),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
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
                    : Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    this.required = false,
    this.keyboard,
    this.action,
    this.autofillHints,
    this.formatters,
    this.validator,
    this.obscure = false,
    this.readOnly = false,
    this.onTap,
    this.onSubmitted,
    this.suffix,
  });

  final String label;
  final bool required;
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboard;
  final TextInputAction? action;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? formatters;
  final FormFieldValidator<String>? validator;
  final bool obscure;
  final bool readOnly;
  final VoidCallback? onTap;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _RegisterScreenState._ink),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: const TextStyle(
                color: _RegisterScreenState._ink,
                fontSize: 11,
                fontWeight: FontWeight.w400,
              ),
              children: [
                TextSpan(text: label),
                if (required)
                  const TextSpan(
                    text: ' *',
                    style: TextStyle(color: Color(0xFFE53935)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          TextFormField(
            controller: controller,
            keyboardType: keyboard,
            textInputAction: action,
            autofillHints: autofillHints,
            inputFormatters: formatters,
            validator: validator,
            obscureText: obscure,
            readOnly: readOnly,
            onTap: onTap,
            onFieldSubmitted: onSubmitted,
            style: const TextStyle(
              color: _RegisterScreenState._ink,
              fontSize: 13,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: _RegisterScreenState._muted,
                fontSize: 12,
              ),
              suffixIcon: suffix,
              suffixIconConstraints: const BoxConstraints(
                minWidth: 42,
                minHeight: 34,
              ),
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 9,
              ),
              enabledBorder: border,
              focusedBorder: border.copyWith(
                borderSide: const BorderSide(
                  color: _RegisterScreenState._brand,
                  width: 1.5,
                ),
              ),
              errorBorder: border.copyWith(
                borderSide: const BorderSide(color: Color(0xFFD32F2F)),
              ),
              focusedErrorBorder: border.copyWith(
                borderSide: const BorderSide(
                  color: Color(0xFFD32F2F),
                  width: 1.5,
                ),
              ),
              errorStyle: const TextStyle(fontSize: 10, height: 1.05),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Color(0xFFB71C1C),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
