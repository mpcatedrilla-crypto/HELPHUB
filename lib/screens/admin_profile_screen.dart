import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/profile_provider.dart';
import '../theme/app_theme.dart';
import 'admin_drawer.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _age = TextEditingController();
  final _gender = TextEditingController();
  final _imagePicker = ImagePicker();

  bool _editing = false;
  File? _selectedAvatar;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProfile());
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _age.dispose();
    _gender.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = context.read<ProfileProvider>();
    await profile.loadProfile();
    if (!mounted) return;
    _syncFields(profile);
  }

  void _syncFields(ProfileProvider profile) {
    _firstName.text = profile.firstName;
    _lastName.text = profile.lastName;
    _age.text = profile.age;
    _gender.text = profile.gender;
  }

  void _startEditing(ProfileProvider profile) {
    _syncFields(profile);
    setState(() {
      _editing = true;
      _selectedAvatar = null;
    });
  }

  void _cancelEditing(ProfileProvider profile) {
    FocusManager.instance.primaryFocus?.unfocus();
    _syncFields(profile);
    setState(() {
      _editing = false;
      _selectedAvatar = null;
    });
  }

  Future<void> _pickProfilePhoto() async {
    if (!_editing) return;
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1200,
    );
    if (image != null && mounted) {
      setState(() => _selectedAvatar = File(image.path));
    }
  }

  Future<void> _applyChanges(ProfileProvider profile) async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final success = await profile.updateProfile(
      firstName: _firstName.text.trim(),
      middleName: profile.middleName,
      lastName: _lastName.text.trim(),
      gender: _gender.text.trim(),
      age: _age.text.trim(),
      birthday: profile.birthday,
      address: profile.address,
      phone: profile.phone,
      avatar: _selectedAvatar,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Administrator profile updated successfully.'
              : profile.errorMessage ?? 'Unable to update profile.',
        ),
        backgroundColor: success ? const Color(0xFF18864B) : AppTheme.sosRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
    if (success) {
      _syncFields(profile);
      setState(() {
        _editing = false;
        _selectedAvatar = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          _editing ? 'Edit Administrator Profile' : 'Administrator Profile',
        ),
        actions: [
          Consumer<ProfileProvider>(
            builder: (context, profile, _) => IconButton(
              tooltip: _editing ? 'Cancel editing' : 'Edit profile',
              onPressed: profile.isSaving
                  ? null
                  : () => _editing
                        ? _cancelEditing(profile)
                        : _startEditing(profile),
              icon: Icon(_editing ? Icons.close_rounded : Icons.edit_rounded),
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      drawer: const AdminDrawer(),
      body: Consumer<ProfileProvider>(
        builder: (context, profile, _) {
          if (profile.isLoading && !profile.hasLoadedCurrentUser) {
            return const Center(child: CircularProgressIndicator());
          }
          if (profile.errorMessage != null && !profile.hasLoadedCurrentUser) {
            return _ProfileLoadError(onRetry: _loadProfile);
          }

          return RefreshIndicator(
            onRefresh: _loadProfile,
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _AdminIdentityHeader(
                                profile: profile,
                                editing: _editing,
                                selectedAvatar: _selectedAvatar,
                                onPhotoTap: _pickProfilePhoto,
                              )
                              .animate()
                              .fade(duration: 300.ms)
                              .slideY(begin: -.04),
                          const SizedBox(height: 16),
                          if (_editing)
                            _EditInformationCard(
                              firstName: _firstName,
                              lastName: _lastName,
                              age: _age,
                              gender: _gender,
                            ).animate().fade(delay: 80.ms).slideY(begin: .04)
                          else
                            _InformationCard(
                              title: 'Profile Information',
                              icon: Icons.admin_panel_settings_outlined,
                              children: [
                                _InformationRow(
                                  label: 'First name',
                                  value: _value(profile.firstName),
                                  icon: Icons.person_outline_rounded,
                                ),
                                _InformationRow(
                                  label: 'Last name',
                                  value: _value(profile.lastName),
                                  icon: Icons.person_outline_rounded,
                                ),
                                _InformationRow(
                                  label: 'Age',
                                  value: _value(profile.age),
                                  icon: Icons.cake_outlined,
                                ),
                                _InformationRow(
                                  label: 'Gender',
                                  value: _value(profile.gender),
                                  icon: Icons.wc_rounded,
                                  last: true,
                                ),
                              ],
                            ).animate().fade(delay: 80.ms).slideY(begin: .04),
                          const SizedBox(height: 16),
                          _AdminIdCard(adminId: profile.userId)
                              .animate()
                              .fade(delay: 150.ms)
                              .slideY(begin: .04),
                          if (_editing) ...[
                            const SizedBox(height: 18),
                            FilledButton.icon(
                              onPressed: profile.isSaving
                                  ? null
                                  : () => _applyChanges(profile),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.primaryBlue,
                                minimumSize: const Size.fromHeight(52),
                              ),
                              icon: profile.isSaving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.check_circle_outline_rounded,
                                    ),
                              label: Text(
                                profile.isSaving
                                    ? 'Saving changes...'
                                    : 'Apply Changes',
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: profile.isSaving
                                  ? null
                                  : () => _cancelEditing(profile),
                              child: const Text('Cancel'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  static String _value(String value) =>
      value.trim().isEmpty ? 'Not provided' : value.trim();
}

class _AdminIdentityHeader extends StatelessWidget {
  const _AdminIdentityHeader({
    required this.profile,
    required this.editing,
    required this.selectedAvatar,
    required this.onPhotoTap,
  });

  final ProfileProvider profile;
  final bool editing;
  final File? selectedAvatar;
  final VoidCallback onPhotoTap;

  @override
  Widget build(BuildContext context) {
    final ImageProvider? photo = selectedAvatar != null
        ? FileImage(selectedAvatar!)
        : profile.avatarUrl != null
        ? NetworkImage(profile.avatarUrl!)
        : null;
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.navy, AppTheme.primaryBlue],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.navy.withValues(alpha: .2),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: editing ? onPhotoTap : null,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .16),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white54, width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 48,
                    backgroundColor: const Color(0xFFDFEAFA),
                    backgroundImage: photo,
                    child: photo == null
                        ? const Icon(
                            Icons.person_rounded,
                            color: AppTheme.primaryBlue,
                            size: 54,
                          )
                        : null,
                  ),
                ),
                if (editing)
                  Positioned(
                    right: -2,
                    bottom: 1,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.primaryBlue),
                      ),
                      child: const Icon(
                        Icons.photo_camera_rounded,
                        color: AppTheme.primaryBlue,
                        size: 18,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (editing) ...[
            const SizedBox(height: 8),
            const Text(
              'Tap photo to change',
              style: TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            profile.fullName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF5DE2A5).withValues(alpha: .16),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFF5DE2A5)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.verified_rounded,
                  size: 15,
                  color: Color(0xFF5DE2A5),
                ),
                SizedBox(width: 5),
                Text(
                  'VERIFIED ADMINISTRATOR',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .5,
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

class _InformationCard extends StatelessWidget {
  const _InformationCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFE7F0FF),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: AppTheme.primaryBlue, size: 21),
              ),
              const SizedBox(width: 11),
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.onSurfaceColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          ...children,
        ],
      ),
    );
  }
}

class _EditInformationCard extends StatelessWidget {
  const _EditInformationCard({
    required this.firstName,
    required this.lastName,
    required this.age,
    required this.gender,
  });

  final TextEditingController firstName;
  final TextEditingController lastName;
  final TextEditingController age;
  final TextEditingController gender;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: .35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.edit_note_rounded,
                color: AppTheme.primaryBlue,
                size: 25,
              ),
              SizedBox(width: 9),
              Text(
                'Edit Profile Information',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _AdminEditField(
            label: 'First name',
            controller: firstName,
            icon: Icons.person_outline_rounded,
            validator: (value) => value == null || value.trim().isEmpty
                ? 'First name is required'
                : null,
          ),
          const SizedBox(height: 13),
          _AdminEditField(
            label: 'Last name',
            controller: lastName,
            icon: Icons.person_outline_rounded,
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Last name is required'
                : null,
          ),
          const SizedBox(height: 13),
          _AdminEditField(
            label: 'Age',
            controller: age,
            icon: Icons.cake_outlined,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (value) {
              final parsed = int.tryParse(value?.trim() ?? '');
              if (parsed == null) return 'Age is required';
              return parsed < 18 || parsed > 120
                  ? 'Enter a valid administrator age'
                  : null;
            },
          ),
          const SizedBox(height: 13),
          _AdminEditField(
            label: 'Gender',
            controller: gender,
            icon: Icons.wc_rounded,
            textInputAction: TextInputAction.done,
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Gender is required'
                : null,
          ),
        ],
      ),
    );
  }
}

class _AdminEditField extends StatelessWidget {
  const _AdminEditField({
    required this.label,
    required this.controller,
    required this.icon,
    required this.validator,
    this.keyboardType,
    this.inputFormatters,
    this.textInputAction = TextInputAction.next,
  });

  final String label;
  final TextEditingController controller;
  final IconData icon;
  final FormFieldValidator<String> validator;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction textInputAction;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textInputAction: textInputAction,
      validator: validator,
      scrollPadding: const EdgeInsets.only(bottom: 140),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
      ),
    );
  }
}

class _InformationRow extends StatelessWidget {
  const _InformationRow({
    required this.label,
    required this.value,
    required this.icon,
    this.last = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.textSecondary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: const TextStyle(
                        color: AppTheme.onSurfaceColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!last) const Divider(),
      ],
    );
  }
}

class _AdminIdCard extends StatelessWidget {
  const _AdminIdCard({required this.adminId});

  final String adminId;

  @override
  Widget build(BuildContext context) {
    final displayId = adminId.isEmpty ? 'Unavailable' : adminId;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: .25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.fingerprint_rounded, color: AppTheme.primaryBlue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Admin ID',
                  style: TextStyle(
                    color: AppTheme.primaryBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                SelectableText(
                  displayId,
                  style: const TextStyle(
                    color: AppTheme.onSurfaceColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (adminId.isNotEmpty)
            IconButton(
              tooltip: 'Copy Admin ID',
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: adminId));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Admin ID copied.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: const Icon(
                Icons.copy_rounded,
                color: AppTheme.primaryBlue,
                size: 20,
              ),
            ),
        ],
      ),
    );
  }
}

class _ProfileLoadError extends StatelessWidget {
  const _ProfileLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 54,
              color: AppTheme.sosRed,
            ),
            const SizedBox(height: 12),
            const Text(
              'Unable to load administrator profile',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
