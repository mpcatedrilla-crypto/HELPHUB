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
    if (profile.avatarUrl == null) {
      setState(() => _editing = true);
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          icon: const Icon(Icons.add_a_photo_rounded, color: _purple, size: 42),
          title: const Text(
            'Profile photo required',
            textAlign: TextAlign.center,
          ),
          content: const Text(
            'For identity verification, upload a clear profile photo and tap Apply Changes before submitting your request.',
            textAlign: TextAlign.center,
            style: TextStyle(height: 1.45, color: Colors.black54),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _pickAvatar();
                },
                style: FilledButton.styleFrom(backgroundColor: _purple),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Choose Profile Photo'),
              ),
            ),
          ],
        ),
      );
      return;
    }
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

  void _cancelEditing() {
    FocusManager.instance.primaryFocus?.unfocus();
    final profile = context.read<ProfileProvider>();
    _syncFields(profile);
    setState(() {
      _editing = false;
      _selectedAvatar = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _blue,
      resizeToAvoidBottomInset: true,
      body: Consumer<ProfileProvider>(
        builder: (context, profile, _) {
          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_cyan, _blue],
              ),
            ),
            child: SafeArea(
              bottom: false,
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
                    child: Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF5F8FC),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                      ),
                      child: profile.isLoading && profile.profile.isEmpty
                          ? const Center(
                              child: CircularProgressIndicator(color: _purple),
                            )
                          : SingleChildScrollView(
                              controller: _pageScrollController,
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              padding: EdgeInsets.fromLTRB(
                                18,
                                20,
                                18,
                                28 + MediaQuery.viewInsetsOf(context).bottom,
                              ),
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 620,
                                  ),
                                  child: _profileForm(profile),
                                ),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _profileForm(ProfileProvider profile) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ProfileStatusCard(profile: profile),
          const SizedBox(height: 14),
          _profileSection(
            title: 'Personal Information',
            icon: Icons.badge_outlined,
            children: [
              Row(
                children: [
                  Expanded(child: _field('First Name', _first, required: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _field('Last Name', _last, required: true)),
                ],
              ),
              Row(
                children: [
                  Expanded(child: _field('Middle Name', _middle)),
                  const SizedBox(width: 12),
                  Expanded(child: _field('Gender', _gender)),
                ],
              ),
              Row(
                children: [
                  Expanded(child: _field('Age', _age, number: true)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field('Birthday', _birthday, onTap: _pickBirthday),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          _profileSection(
            title: 'Contact Information',
            icon: Icons.contact_phone_outlined,
            children: [
              _field('Barangay Address', _address, required: true),
              _field('Email Address', _email, readOnly: true),
              _field('Contact No.', _phone, phone: true),
            ],
          ),
          if (!profile.isVerified && profile.avatarUrl == null) ...[
            const SizedBox(height: 14),
            const _PhotoRequirementNotice(),
          ],
          if (profile.errorMessage != null) ...[
            const SizedBox(height: 12),
            _InlineProfileError(message: profile.errorMessage!),
          ],
          const SizedBox(height: 18),
          if (_editing) ...[
            _ProfileActionButton(
              label: 'Apply Changes',
              loading: profile.isSaving,
              onPressed: () => _applyChanges(profile),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: profile.isSaving ? null : _cancelEditing,
              child: const Text('Cancel'),
            ),
          ] else if (!profile.isVerified)
            _ProfileActionButton(
              label: profile.isVerificationPending
                  ? 'Pending Verification'
                  : 'Submit Verification',
              loading: profile.isSaving,
              onPressed: profile.isVerificationPending
                  ? null
                  : () => _requestVerification(profile),
            ),
        ],
      ),
    );
  }

  Widget _profileSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDDE5EF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C0B1F3A),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: _blue, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
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
      padding: const EdgeInsets.only(bottom: 12),
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
        style: const TextStyle(
          color: _ink,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          labelText: label,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          labelStyle: const TextStyle(
            color: Color(0xFF5F6672),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 13,
            vertical: 13,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD7E0EB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _blue, width: 1.8),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD7E0EB)),
          ),
          errorStyle: const TextStyle(fontSize: 9),
        ),
      ),
    );
  }
}

class _ProfileStatusCard extends StatelessWidget {
  const _ProfileStatusCard({required this.profile});

  final ProfileProvider profile;

  @override
  Widget build(BuildContext context) {
    final verified = profile.isVerified;
    final pending = profile.isVerificationPending;
    final color = verified
        ? const Color(0xFF18864B)
        : pending
        ? const Color(0xFF075EB8)
        : const Color(0xFF9A6700);
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: verified
            ? const Color(0xFFE8F7EF)
            : pending
            ? const Color(0xFFEAF3FF)
            : const Color(0xFFFFF7DF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: .3)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              verified
                  ? Icons.verified_rounded
                  : pending
                  ? Icons.hourglass_top_rounded
                  : Icons.shield_outlined,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  verified
                      ? 'Verified Resident'
                      : pending
                      ? 'Pending Verification'
                      : 'Account Not Verified',
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  verified
                      ? 'Your identity has been confirmed by HelpHub.'
                      : pending
                      ? 'Your profile was submitted and is waiting for administrator review.'
                      : 'Complete your profile and submit it for administrator review.',
                  style: const TextStyle(
                    color: Color(0xFF5F6672),
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoRequirementNotice extends StatelessWidget {
  const _PhotoRequirementNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1EDFF),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFF2400B8).withValues(alpha: .25),
        ),
      ),
      child: const Row(
        children: [
          Icon(Icons.add_a_photo_outlined, color: Color(0xFF2400B8)),
          SizedBox(width: 11),
          Expanded(
            child: Text(
              'A clear profile photo is required before you can submit a verification request.',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineProfileError extends StatelessWidget {
  const _InlineProfileError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEDEC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 19),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.red, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
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
    } else {
      image = const AssetImage('assets/images/default_resident_avatar.png');
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

class _ProfileActionButton extends StatelessWidget {
  const _ProfileActionButton({
    required this.label,
    required this.loading,
    required this.onPressed,
  });
  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: _ProfileScreenState._purple,
          foregroundColor: Colors.white,
          disabledBackgroundColor: loading
              ? _ProfileScreenState._purple.withValues(alpha: .72)
              : const Color(0xFFEAF3FF),
          disabledForegroundColor: const Color(0xFF075EB8),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
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
