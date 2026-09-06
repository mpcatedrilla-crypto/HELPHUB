import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _blue = Color(0xFF075EB8);
  static const _cyan = Color(0xFF55D8DD);
  static const _purple = Color(0xFF2400B8);
  static const _ink = Color(0xFF111111);

  final _formKey = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _middle = TextEditingController();
  final _gender = TextEditingController();
  final _age = TextEditingController();
  final _birthday = TextEditingController();
  final _address = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _picker = ImagePicker();
  final _pageScrollController = ScrollController();

  bool _editing = false;
  File? _selectedAvatar;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final profile = context.read<ProfileProvider>();
    await profile.loadProfile();
    if (!mounted) return;
    _syncFields(profile);
  }

  void _syncFields(ProfileProvider profile) {
    _first.text = profile.firstName;
    _last.text = profile.lastName;
    _middle.text = profile.middleName;
    _gender.text = profile.gender;
    _age.text = profile.age;
    _birthday.text = profile.birthday;
    _address.text = profile.address;
    _email.text = profile.email;
    _phone.text = profile.phone;
    setState(() {});
  }

  @override
  void dispose() {
    for (final controller in [
      _first,
      _last,
      _middle,
      _gender,
      _age,
      _birthday,
      _address,
      _email,
      _phone,
    ]) {
      controller.dispose();
    }
    _pageScrollController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    if (!_editing) return;
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1200,
    );
    if (image != null && mounted) {
      setState(() => _selectedAvatar = File(image.path));
    }
  }

  Future<void> _pickBirthday() async {
    if (!_editing) return;
    final now = DateTime.now();
    final parsed = DateTime.tryParse(_birthday.text);
    final value = await showDatePicker(
      context: context,
      initialDate: parsed ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(now.year - 120),
      lastDate: now,
    );
    if (value != null) {
      _birthday.text = value.toIso8601String().split('T').first;
    }
  }

  Future<void> _applyChanges(ProfileProvider profile) async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final success = await profile.updateProfile(
      firstName: _first.text,
      middleName: _middle.text,
      lastName: _last.text,
      gender: _gender.text,
      age: _age.text,
      birthday: _birthday.text,
      address: _address.text,
      phone: _phone.text,
      avatar: _selectedAvatar,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Profile updated successfully.'
              : profile.errorMessage ?? 'Update failed.',
        ),
        backgroundColor: success ? const Color(0xFF18864B) : Colors.red,
      ),
    );
    if (success) {
      setState(() {
        _editing = false;
        _selectedAvatar = null;
      });
      _syncFields(profile);
    }
  }

  Future<void> _requestVerification(ProfileProvider profile) async {
    final success = await profile.requestVerification();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Verification request submitted.'
              : profile.errorMessage ?? 'Request failed.',
        ),
        backgroundColor: success ? const Color(0xFF18864B) : Colors.red,
      ),
    );
  }

  Future<void> _logout() async {
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _blue,
      resizeToAvoidBottomInset: false,
      body: Consumer<ProfileProvider>(
        builder: (context, profile, _) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
              final designHeight = constraints.maxHeight < 640
                  ? 640.0
                  : constraints.maxHeight;
              final canvas = SizedBox(
                height: designHeight,
                child: CustomPaint(
                  painter: const _ProfileBackgroundPainter(),
                  child: Column(
                    children: [
                      _ProfileHeader(
                        profile: profile,
                        editing: _editing,
                        selectedAvatar: _selectedAvatar,
                        onBack: () => Navigator.pop(context),
                        onLogout: _logout,
                        onEdit: () => setState(() => _editing = true),
                        onAvatarTap: _pickAvatar,
                      ),
                      Expanded(
                        child: _profileForm(
                          profile,
                          spreadFields: designHeight > 680,
                        ),
                      ),
                      const SizedBox(height: 114),
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

  Widget _profileForm(ProfileProvider profile, {required bool spreadFields}) {
    if (profile.isLoading && profile.profile.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: _purple));
    }
    return Form(
      key: _formKey,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(43, 10, 43, 24),
        child: Column(
          mainAxisAlignment: spreadFields
              ? MainAxisAlignment.spaceEvenly
              : MainAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _field('First Name', _first, required: true)),
                const SizedBox(width: 19),
                Expanded(child: _field('Last Name', _last, required: true)),
              ],
            ),
            Row(
              children: [
                Expanded(child: _field('Middle Name', _middle)),
                const SizedBox(width: 19),
                Expanded(child: _field('Gender', _gender)),
              ],
            ),
            Row(
              children: [
                Expanded(child: _field('Age', _age, number: true)),
                const SizedBox(width: 19),
                Expanded(
                  child: _field('Birthday', _birthday, onTap: _pickBirthday),
                ),
              ],
            ),
            _field('Barangay Address', _address, required: true),
            _field('Email Address', _email, readOnly: true),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: _field('Contact No.', _phone, phone: true)),
                const SizedBox(width: 19),
                if (_editing)
                  Expanded(
                    child: _ProfileActionButton(
                      label: 'Apply Changes',
                      loading: profile.isSaving,
                      onPressed: () => _applyChanges(profile),
                    ),
                  )
                else if (!profile.isVerified)
                  Expanded(
                    child: _ProfileActionButton(
                      label: profile.status == 'pending'
                          ? 'Submit Verification'
                          : 'Submit Verification',
                      loading: profile.isSaving,
                      onPressed: () => _requestVerification(profile),
                    ),
                  ),
              ],
            ),
            if (profile.errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                profile.errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    bool required = false,
    bool readOnly = false,
    bool number = false,
    bool phone = false,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        controller: controller,
        scrollPadding: const EdgeInsets.only(bottom: 140),
        readOnly: !_editing || readOnly || onTap != null,
        onTap: onTap,
        keyboardType: number
            ? TextInputType.number
            : phone
            ? TextInputType.phone
            : TextInputType.text,
        inputFormatters: number
            ? [FilteringTextInputFormatter.digitsOnly]
            : null,
        validator: required
            ? (value) => value?.trim().isEmpty ?? true ? 'Required' : null
            : null,
        style: const TextStyle(color: _ink, fontSize: 12),
        decoration: InputDecoration(
          labelText: label,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          labelStyle: const TextStyle(color: _ink, fontSize: 11),
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 9,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _ink),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _blue, width: 1.5),
          ),
          errorStyle: const TextStyle(fontSize: 9),
        ),
      ),
    );
  }
}

class _ProfileBackgroundPainter extends CustomPainter {
  const _ProfileBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final gradient = Paint()
      ..shader = const LinearGradient(
        colors: [_ProfileScreenState._cyan, _ProfileScreenState._blue],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, gradient);
    final footerTop = size.height - 114;
    final white = Path()
      ..moveTo(size.width * .38, 114)
      ..lineTo(size.width, 114)
      ..lineTo(size.width, footerTop - 179)
      ..lineTo(size.width * .61, footerTop)
      ..lineTo(0, footerTop)
      ..lineTo(0, 297)
      ..close();
    canvas.drawPath(white, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.profile,
    required this.editing,
    required this.selectedAvatar,
    required this.onBack,
    required this.onLogout,
    required this.onEdit,
    required this.onAvatarTap,
  });

  final ProfileProvider profile;
  final bool editing;
  final File? selectedAvatar;
  final VoidCallback onBack;
  final VoidCallback onLogout;
  final VoidCallback onEdit;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    ImageProvider? image;
    if (selectedAvatar != null) {
      image = FileImage(selectedAvatar!);
    } else if (profile.avatarUrl != null) {
      image = NetworkImage(profile.avatarUrl!);
    }
    return SizedBox(
      height: 175,
      child: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: TextButton.icon(
                    onPressed: onLogout,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    icon: const Icon(Icons.logout_rounded, size: 19),
                    label: const Text(
                      'Log out',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 15,
            top: 69,
            child: GestureDetector(
              onTap: onAvatarTap,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 45,
                    backgroundColor: const Color(0xFFE2F8FC),
                    backgroundImage: image,
                    child: image == null ? const _AvatarPlaceholder() : null,
                  ),
                  if (editing)
                    const Positioned(
                      right: 0,
                      bottom: 2,
                      child: CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.black,
                        child: Icon(
                          Icons.edit_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 108,
            top: 94,
            right: 10,
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    editing ? 'Editing Profile' : profile.fullName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (!editing && profile.isVerified) ...[
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.verified_rounded,
                    color: Color(0xFF19E54D),
                    size: 18,
                  ),
                ],
              ],
            ),
          ),
          if (!editing)
            Positioned(
              right: 14,
              top: 125,
              child: FilledButton(
                onPressed: onEdit,
                style: FilledButton.styleFrom(
                  backgroundColor: _ProfileScreenState._purple,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 29),
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  textStyle: const TextStyle(fontSize: 10),
                ),
                child: const Text('Manage or Edit Profile'),
              ),
            ),
          if (editing)
            const Positioned(
              left: 9,
              top: 162,
              child: Text(
                'Change Profile Picture',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
              ),
            ),
        ],
      ),
    );
  }
}

class _AvatarPlaceholder extends StatelessWidget {
  const _AvatarPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox(
        width: 90,
        height: 90,
        child: CustomPaint(painter: const _AvatarLandscapePainter()),
      ),
    );
  }
}

class _AvatarLandscapePainter extends CustomPainter {
  const _AvatarLandscapePainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFDDF7FF), Color(0xFFBDEEFF)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawCircle(
      Offset(size.width * .44, size.height * .25),
      10,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      Offset(size.width * .56, size.height * .25),
      13,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      Offset(size.width * .68, size.height * .28),
      8,
      Paint()..color = Colors.white,
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height * .73)
        ..quadraticBezierTo(
          size.width * .35,
          size.height * .55,
          size.width,
          size.height * .69,
        )
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close(),
      Paint()..color = const Color(0xFF9AC41A),
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height * .82)
        ..quadraticBezierTo(
          size.width * .55,
          size.height * .64,
          size.width,
          size.height * .82,
        )
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close(),
      Paint()..color = const Color(0xFF5D9800),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ProfileActionButton extends StatelessWidget {
  const _ProfileActionButton({
    required this.label,
    required this.loading,
    required this.onPressed,
  });
  final String label;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: _ProfileScreenState._purple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 10),
        ),
        child: loading
            ? const SizedBox.square(
                dimension: 15,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(label, textAlign: TextAlign.center),
      ),
    );
  }
}
