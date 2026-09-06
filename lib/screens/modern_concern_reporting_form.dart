import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../providers/report_provider.dart';
import 'camera_screen.dart';

class ModernConcernReportingForm extends StatefulWidget {
  const ModernConcernReportingForm({super.key});

  @override
  State<ModernConcernReportingForm> createState() =>
      _ModernConcernReportingFormState();
}

class _ModernConcernReportingFormState
    extends State<ModernConcernReportingForm> {
  static const _blue = Color(0xFF075EB8);
  static const _cyan = Color(0xFF55D8DD);
  static const _purple = Color(0xFF2400B8);
  static const _ink = Color(0xFF111111);
  static const _muted = Color(0xFF9B9B9B);
  static const _red = Color(0xFFFF3B3B);

  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _otherVulnerableGroupController = TextEditingController();
  final _otherVulnerableGroupFocusNode = FocusNode();
  final _pageScrollController = ScrollController();
  final _mapController = MapController();
  final _picker = ImagePicker();

  int _currentStep = 0;
  String? _selectedCategoryId;
  int _populationScale = 1;
  final List<String> _selectedGroups = [];
  LatLng? _selectedLocation;
  final List<File> _evidenceImages = [];
  bool _isLocating = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReportProvider>().fetchConcernTypes();
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _addressController.dispose();
    _otherVulnerableGroupController.dispose();
    _otherVulnerableGroupFocusNode.dispose();
    _pageScrollController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _cancel() {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.pop(context);
  }

  Future<void> _continue(ReportProvider provider) async {
    FocusManager.instance.primaryFocus?.unfocus();
    switch (_currentStep) {
      case 0:
        if (_selectedCategoryId == null) {
          _showMessage('Please select a concern type.');
          return;
        }
      case 1:
        if (_descriptionController.text.trim().length < 10) {
          _showMessage('Please add a clear description of the concern.');
          return;
        }
        if (_selectedGroups.contains('Other') &&
            _otherVulnerableGroupController.text.trim().isEmpty) {
          _showMessage('Please specify the other vulnerable group.');
          _otherVulnerableGroupFocusNode.requestFocus();
          return;
        }
      case 2:
        if (_selectedLocation == null) {
          _showMessage('Please pin the location or use your current GPS.');
          return;
        }
      case 3:
        if (_evidenceImages.isEmpty) {
          _showMessage('Please attach at least one evidence photo.');
          return;
        }
    }

    if (_currentStep < 3) {
      setState(() => _currentStep++);
      _scrollToTop();
      if (_currentStep == 2 && _selectedLocation == null) {
        await _getCurrentLocation();
      }
      return;
    }
    await _submit(provider);
  }

  void _scrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageScrollController.hasClients) {
        _pageScrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _toggleGroup(String group) {
    setState(() {
      if (group == 'None') {
        _selectedGroups
          ..clear()
          ..add('None');
        _otherVulnerableGroupController.clear();
        _otherVulnerableGroupFocusNode.unfocus();
        return;
      }
      _selectedGroups.remove('None');
      if (_selectedGroups.contains(group)) {
        _selectedGroups.remove(group);
        if (group == 'Other') {
          _otherVulnerableGroupController.clear();
          _otherVulnerableGroupFocusNode.unfocus();
        }
      } else {
        _selectedGroups.add(group);
        if (group == 'Other') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _otherVulnerableGroupFocusNode.requestFocus();
          });
        }
      }
    });
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Please turn on location services.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission is required.');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      final point = LatLng(position.latitude, position.longitude);
      setState(() => _selectedLocation = point);
      _mapController.move(point, 16);
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      String? path;
      if (source == ImageSource.camera) {
        var permission = await Permission.camera.status;
        if (!permission.isGranted) {
          permission = await Permission.camera.request();
        }
        if (!permission.isGranted) {
          _showMessage('Camera permission is required.');
          return;
        }
        final cameras = await availableCameras();
        if (cameras.isEmpty) throw Exception('No camera was found.');
        if (!mounted) return;
        path = await Navigator.push<String>(
          context,
          MaterialPageRoute(builder: (_) => CameraScreen(cameras: cameras)),
        );
      } else {
        final image = await _picker.pickImage(
          source: source,
          imageQuality: 76,
          maxWidth: 1800,
        );
        path = image?.path;
      }
      if (path != null && mounted) {
        setState(() => _evidenceImages.add(File(path!)));
      }
    } catch (error) {
      if (mounted) {
        _showMessage('Unable to add photo: $error');
      }
    }
  }

  Future<void> _submit(ReportProvider provider) async {
    setState(() => _isSubmitting = true);
    final selectedType = provider.concernTypes
        .cast<Map<String, dynamic>?>()
        .firstWhere(
          (type) => type?['id']?.toString() == _selectedCategoryId,
          orElse: () => null,
        );
    final category = selectedType?['category_name']?.toString() ?? 'Community';
    final vulnerableGroups = _selectedGroups.map((group) {
      if (group != 'Other') return group;
      return 'Other: ${_otherVulnerableGroupController.text.trim()}';
    }).toList();
    final success = await provider.submitReport(
      typeId: _selectedCategoryId!,
      title: '$category concern',
      description: _descriptionController.text.trim(),
      populationScale: _populationScale,
      vulnerableGroups: vulnerableGroups,
      latitude: _selectedLocation!.latitude,
      longitude: _selectedLocation!.longitude,
      addressNotes: _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim(),
      evidenceImages: _evidenceImages,
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted successfully.')),
      );
      Navigator.pop(context);
    } else {
      _showMessage(provider.errorMessage ?? 'Report submission failed.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: _blue,
        resizeToAvoidBottomInset: false,
        body: Consumer<ReportProvider>(
          builder: (context, provider, _) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final designHeight = constraints.maxHeight < 640
                    ? 640.0
                    : constraints.maxHeight;
                return CustomPaint(
                  painter: const _ReportConcernBackgroundPainter(),
                  child: SizedBox(
                    height: designHeight,
                    child: Column(
                      children: [
                        const _ReportConcernHeader(),
                        Expanded(
                          child: SingleChildScrollView(
                            controller: _pageScrollController,
                            primary: false,
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: EdgeInsets.fromLTRB(
                              24,
                              14,
                              24,
                              28 + keyboardInset,
                            ),
                            child: _steps(provider),
                          ),
                        ),
                        const SizedBox(height: 44),
                      ],
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

  Widget _steps(ReportProvider provider) {
    return Column(
      children: [
        _StepBlock(
          index: 0,
          label: 'Type',
          currentStep: _currentStep,
          child: _typeContent(provider),
        ),
        _StepBlock(
          index: 1,
          label: 'Details',
          currentStep: _currentStep,
          child: _detailsContent(),
        ),
        _StepBlock(
          index: 2,
          label: 'Location',
          currentStep: _currentStep,
          child: _locationContent(),
        ),
        _StepBlock(
          index: 3,
          label: 'Evidence',
          currentStep: _currentStep,
          child: _evidenceContent(),
        ),
      ],
    );
  }

  Widget _typeContent(ReportProvider provider) {
    if (provider.concernTypes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }
    final types = [...provider.concernTypes];
    final floodingIndex = types.indexWhere(
      (type) =>
          type['category_name'].toString().toLowerCase().contains('flood'),
    );
    final otherIndex = types.indexWhere(
      (type) => type['category_name'].toString().toLowerCase() == 'other',
    );
    if (floodingIndex >= 0 && otherIndex >= 0) {
      final flooding = types[floodingIndex];
      types[floodingIndex] = types[otherIndex];
      types[otherIndex] = flooding;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'What is your concern about?',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisExtent: 48,
            crossAxisSpacing: 12,
            mainAxisSpacing: 9,
          ),
          itemCount: types.length,
          itemBuilder: (context, index) {
            final type = types[index];
            final id = type['id'].toString();
            final selected = _selectedCategoryId == id;
            return _ChoiceButton(
              label: type['category_name']?.toString() ?? 'Concern',
              selected: selected,
              onPressed: () => setState(() => _selectedCategoryId = id),
            );
          },
        ),
        const SizedBox(height: 22),
        _StepActions(
          busy: false,
          onContinue: () => _continue(provider),
          onCancel: _cancel,
        ),
      ],
    );
  }

  Widget _detailsContent() {
    final provider = context.read<ReportProvider>();
    const groups = ['Children', 'Elderly', 'PWDs', 'Pregnant', 'Other', 'None'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _descriptionController,
          minLines: 4,
          maxLines: 5,
          scrollPadding: const EdgeInsets.only(bottom: 180),
          textCapitalization: TextCapitalization.sentences,
          decoration: _fieldDecoration(
            hint: 'Description',
            required: true,
            alignTop: true,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Affected Population Scale',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F0FF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            'Selected: ${_populationScale == 5 ? '5+' : _populationScale} — ${_populationScaleLabel(_populationScale)}',
            style: const TextStyle(
              color: _purple,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
            activeTrackColor: _purple,
            inactiveTrackColor: const Color(0xFFD5D5D5),
            thumbColor: _purple,
            valueIndicatorColor: _purple,
            valueIndicatorTextStyle: const TextStyle(color: Colors.white),
          ),
          child: Slider(
            value: _populationScale.toDouble(),
            min: 1,
            max: 5,
            divisions: 4,
            label: _populationScale == 5 ? '5+' : '$_populationScale',
            onChanged: (value) =>
                setState(() => _populationScale = value.round()),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(5, (index) {
            final value = index + 1;
            final selected = value == _populationScale;
            return Column(
              children: [
                Text(
                  value == 5 ? '5+' : '$value',
                  style: TextStyle(
                    color: selected ? _purple : _ink,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
                Text(
                  value == 1
                      ? '1 person'
                      : value == 5
                      ? 'or more'
                      : '',
                  style: const TextStyle(fontSize: 9, color: _muted),
                ),
              ],
            );
          }),
        ),
        const SizedBox(height: 20),
        const Text(
          'Vulnerable Groups Affected',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: groups.map((group) {
            return _ChoiceChipButton(
              label: group,
              selected: _selectedGroups.contains(group),
              onPressed: () => _toggleGroup(group),
            );
          }).toList(),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: !_selectedGroups.contains('Other')
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: TextField(
                    controller: _otherVulnerableGroupController,
                    focusNode: _otherVulnerableGroupFocusNode,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    scrollPadding: const EdgeInsets.only(bottom: 180),
                    decoration: _fieldDecoration(
                      hint: 'Specify other vulnerable group',
                      required: true,
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 20),
        _StepActions(
          busy: false,
          onContinue: () => _continue(provider),
          onCancel: _cancel,
        ),
      ],
    );
  }

  String _populationScaleLabel(int value) {
    const labels = {
      1: 'Few people',
      2: 'Small group',
      3: 'Many people',
      4: 'Large group',
      5: '5 or more people',
    };
    return labels[value]!;
  }

  Widget _locationContent() {
    final provider = context.read<ReportProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tap the map to set a pin, or use GPS',
          style: TextStyle(fontSize: 13, color: _muted),
        ),
        const SizedBox(height: 10),
        Container(
          height: 210,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: _ink),
          ),
          clipBehavior: Clip.antiAlias,
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(14.5995, 120.9842),
              initialZoom: 13,
              onTap: (_, point) => setState(() => _selectedLocation = point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.helphub',
              ),
              if (_selectedLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedLocation!,
                      width: 36,
                      height: 36,
                      child: const Icon(
                        Icons.location_pin,
                        color: _red,
                        size: 34,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _addressController,
          scrollPadding: const EdgeInsets.only(bottom: 180),
          textCapitalization: TextCapitalization.words,
          decoration: _fieldDecoration(
            hint: 'Exact address or landmark (optional)',
            prefix: Icons.pin_drop_outlined,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isLocating ? null : _getCurrentLocation,
            icon: _isLocating
                ? const SizedBox.square(
                    dimension: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location_rounded, size: 16),
            label: Text(
              _selectedLocation == null
                  ? 'Use current GPS location'
                  : 'Update GPS location',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: _purple,
              side: const BorderSide(color: _purple),
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _StepActions(
          busy: _isLocating,
          onContinue: () => _continue(provider),
          onCancel: _cancel,
        ),
      ],
    );
  }

  Widget _evidenceContent() {
    final provider = context.read<ReportProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _RequiredLabel('Attach photos of the situation'),
        const SizedBox(height: 18),
        Row(
          children: [
            _MediaButton(
              icon: Icons.camera_alt_outlined,
              label: 'Camera',
              onPressed: () => _pickImage(ImageSource.camera),
            ),
            const SizedBox(width: 14),
            _MediaButton(
              icon: Icons.photo_library_outlined,
              label: 'Gallery',
              onPressed: () => _pickImage(ImageSource.gallery),
            ),
          ],
        ),
        if (_evidenceImages.isNotEmpty) ...[
          const SizedBox(height: 13),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _evidenceImages.length,
              separatorBuilder: (_, _) => const SizedBox(width: 7),
              itemBuilder: (context, index) {
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: Image.file(
                        _evidenceImages[index],
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      right: -5,
                      top: -5,
                      child: InkWell(
                        onTap: () =>
                            setState(() => _evidenceImages.removeAt(index)),
                        child: const CircleAvatar(
                          radius: 9,
                          backgroundColor: _red,
                          child: Icon(
                            Icons.close,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 26),
        _StepActions(
          busy: _isSubmitting,
          onContinue: () => _continue(provider),
          onCancel: _cancel,
        ),
      ],
    );
  }

  InputDecoration _fieldDecoration({
    required String hint,
    bool required = false,
    bool alignTop = false,
    IconData? prefix,
  }) {
    return InputDecoration(
      hint: required
          ? Text.rich(
              TextSpan(
                text: hint,
                children: const [
                  TextSpan(
                    text: ' *',
                    style: TextStyle(color: _red),
                  ),
                ],
              ),
            )
          : null,
      hintText: required ? null : hint,
      hintStyle: const TextStyle(color: _muted, fontSize: 13),
      prefixIcon: prefix == null ? null : Icon(prefix, color: _ink, size: 18),
      alignLabelWithHint: alignTop,
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _ink),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _purple, width: 1.5),
      ),
    );
  }
}

class _ReportConcernBackgroundPainter extends CustomPainter {
  const _ReportConcernBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final gradient = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: [
          _ModernConcernReportingFormState._cyan,
          _ModernConcernReportingFormState._blue,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, gradient);
    final footerTop = size.height - 44;
    final white = Path()
      ..moveTo(size.width * .27, 94)
      ..lineTo(size.width * .81, 94)
      ..lineTo(size.width, 198)
      ..lineTo(size.width, footerTop)
      ..lineTo(0, footerTop)
      ..lineTo(0, 193)
      ..close();
    canvas.drawPath(white, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ReportConcernHeader extends StatelessWidget {
  const _ReportConcernHeader();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 101,
      child: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: 43,
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(10, 0, 13, 7),
            decoration: BoxDecoration(
              color: _ModernConcernReportingFormState._purple,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: const Text(
              'Report Concern',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepBlock extends StatelessWidget {
  const _StepBlock({
    required this.index,
    required this.label,
    required this.currentStep,
    required this.child,
  });

  final int index;
  final String label;
  final int currentStep;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final active = currentStep == index;
    final complete = currentStep > index;
    return Padding(
      padding: EdgeInsets.only(bottom: active ? 26 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: active || complete
                      ? _ModernConcernReportingFormState._purple
                      : const Color(0xFF7C7C7C),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: complete
                    ? const Icon(Icons.check, size: 21, color: Colors.white)
                    : Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
              const SizedBox(width: 14),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (active)
            Padding(
              padding: const EdgeInsets.only(left: 52, top: 7),
              child: child,
            ),
        ],
      ),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: _ModernConcernReportingFormState._ink,
        backgroundColor: selected ? const Color(0xFFE9E4FF) : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 7),
        side: BorderSide(
          color: selected
              ? _ModernConcernReportingFormState._purple
              : _ModernConcernReportingFormState._ink,
          width: selected ? 1.5 : 1,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
        textStyle: TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
      child: Text(label, textAlign: TextAlign.center),
    );
  }
}

class _ChoiceChipButton extends StatelessWidget {
  const _ChoiceChipButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: _ModernConcernReportingFormState._ink,
          backgroundColor: selected ? const Color(0xFFE9E4FF) : Colors.white,
          side: BorderSide(
            color: selected
                ? _ModernConcernReportingFormState._purple
                : const Color(0xFF777777),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontSize: 12),
        ),
        child: Text(label),
      ),
    );
  }
}

class _StepActions extends StatelessWidget {
  const _StepActions({
    required this.busy,
    required this.onContinue,
    required this.onCancel,
  });

  final bool busy;
  final VoidCallback onContinue;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          height: 40,
          child: FilledButton(
            onPressed: busy ? null : onContinue,
            style: FilledButton.styleFrom(
              backgroundColor: _ModernConcernReportingFormState._purple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: busy
                ? const SizedBox.square(
                    dimension: 13,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text('Continue'),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          height: 40,
          child: OutlinedButton(
            onPressed: busy ? null : onCancel,
            style: OutlinedButton.styleFrom(
              foregroundColor: _ModernConcernReportingFormState._ink,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              side: const BorderSide(
                color: _ModernConcernReportingFormState._purple,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: const Text('Cancel'),
          ),
        ),
      ],
    );
  }
}

class _MediaButton extends StatelessWidget {
  const _MediaButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: _ModernConcernReportingFormState._purple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          textStyle: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }
}

class _RequiredLabel extends StatelessWidget {
  const _RequiredLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: label,
        children: const [
          TextSpan(
            text: ' *',
            style: TextStyle(color: _ModernConcernReportingFormState._red),
          ),
        ],
      ),
      style: const TextStyle(fontSize: 13),
    );
  }
}
