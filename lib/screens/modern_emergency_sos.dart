import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/report_provider.dart';

class ModernEmergencySos extends StatefulWidget {
  const ModernEmergencySos({super.key});

  @override
  State<ModernEmergencySos> createState() => _ModernEmergencySosState();
}

class _ModernEmergencySosState extends State<ModernEmergencySos> {
  static const _blue = Color(0xFF075EB8);
  static const _cyan = Color(0xFF55D8DD);
  static const _purple = Color(0xFF2400B8);
  static const _red = Color(0xFFE50008);
  static const _headingRed = Color(0xFFFF3038);
  static const _ink = Color(0xFF111111);
  static const _feedbackChannel = MethodChannel('helphub/device_feedback');

  static const _emergencyTypes = [
    'Being Followed',
    'Violence/Fighting',
    'Fire Hazard',
    'Medical Emergency',
    'Accident',
  ];

  Timer? _holdTimer;
  StreamSubscription<Position>? _trackingSubscription;
  final AudioPlayer _feedbackPlayer = AudioPlayer();
  Position? _currentPosition;
  String? _activeReportId;
  String? _selectedEmergencyType;
  bool _isHolding = false;
  bool _isSending = false;
  bool _isSilentMode = false;
  bool _flashEnabled = false;
  bool _sosActivated = false;
  String _locationStatus = 'Locating...';

  @override
  void initState() {
    super.initState();
    _fetchLiveLocation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReportProvider>().fetchConcernTypes();
    });
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _trackingSubscription?.cancel();
    _feedbackPlayer.dispose();
    unawaited(_setTorch(false));
    super.dispose();
  }

  Future<void> _fetchLiveLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) setState(() => _locationStatus = 'Location is turned off');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() => _locationStatus = 'Location permission denied');
        }
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      setState(() {
        _currentPosition = position;
        _locationStatus =
            '${position.latitude.toStringAsFixed(4)}° N, '
            '${position.longitude.toStringAsFixed(4)}° E';
      });
    } catch (_) {
      if (mounted) setState(() => _locationStatus = 'Unable to get GPS');
    }
  }

  void _startHold(TapDownDetails details) {
    if (_isSending || _sosActivated) return;
    _holdTimer?.cancel();
    HapticFeedback.mediumImpact();
    setState(() => _isHolding = true);
    unawaited(_startDeviceFeedback());
    _holdTimer = Timer(const Duration(seconds: 2), _sendSos);
  }

  void _cancelHold([Object? _]) {
    if (_isSending) return;
    _holdTimer?.cancel();
    unawaited(_stopDeviceFeedback());
    if (_isHolding && mounted) setState(() => _isHolding = false);
  }

  Future<void> _startDeviceFeedback() async {
    if (_isSilentMode) return;
    if (_flashEnabled) await _setTorch(true);
    try {
      await _feedbackPlayer.play(AssetSource('sounds/siren.wav'), volume: .7);
    } catch (_) {
      // Haptics still provide feedback if audio is unavailable.
    }
  }

  Future<void> _stopDeviceFeedback() async {
    await _setTorch(false);
    try {
      await _feedbackPlayer.stop();
    } catch (_) {
      // The player may already be stopped.
    }
  }

  Future<void> _setTorch(bool enabled) async {
    try {
      await _feedbackChannel.invokeMethod<void>('setTorch', {
        'enabled': enabled,
      });
    } catch (_) {
      if (enabled && mounted) {
        setState(() => _flashEnabled = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Flashlight is unavailable on this device.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _changeFlashSetting(bool enabled) async {
    if (enabled) {
      var permission = await Permission.camera.status;
      if (!permission.isGranted) permission = await Permission.camera.request();
      if (!permission.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Camera permission is needed for the flashlight.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    }
    if (mounted) setState(() => _flashEnabled = enabled);
  }

  Future<void> _sendSos() async {
    if (!_isHolding || _isSending || !mounted) return;
    final reports = context.read<ReportProvider>();
    setState(() => _isSending = true);
    await _stopDeviceFeedback();
    HapticFeedback.heavyImpact();
    String typeId = '00000000-0000-0000-0000-000000000000';
    if (reports.concernTypes.isNotEmpty) {
      final matching = reports.concernTypes.where((type) {
        final name = type['category_name']?.toString().toLowerCase() ?? '';
        return name.contains('peace') || name.contains('emergency');
      });
      typeId =
          (matching.isEmpty
                  ? reports.concernTypes.first['id']
                  : matching.first['id'])
              .toString();
    }

    final success = await reports.submitReport(
      typeId: typeId,
      title: _selectedEmergencyType ?? 'CRITICAL SOS ALERT',
      description: _isSilentMode ? 'SILENT SOS TRIGGERED' : 'SOS TRIGGERED',
      populationScale: 1,
      vulnerableGroups: const [],
      isEmergency: true,
      latitude: _currentPosition?.latitude,
      longitude: _currentPosition?.longitude,
    );
    if (!mounted) return;
    setState(() {
      _isHolding = false;
      _isSending = false;
    });
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to send SOS. Please try again.'),
          backgroundColor: Colors.black87,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _activeReportId = reports.lastSubmittedReportId;
    setState(() => _sosActivated = true);
    await _startLocationTracking(reports);
    if (mounted) _showActivationConfirmation();
  }

  Future<void> _startLocationTracking(ReportProvider reports) async {
    final reportId = _activeReportId;
    if (reportId == null) return;
    await _trackingSubscription?.cancel();
    _trackingSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          ),
        ).listen((position) {
          if (!mounted) return;
          setState(() {
            _currentPosition = position;
            _locationStatus =
                '${position.latitude.toStringAsFixed(4)}° N, '
                '${position.longitude.toStringAsFixed(4)}° E';
          });
          unawaited(
            reports.updateEmergencyLocation(
              reportId: reportId,
              latitude: position.latitude,
              longitude: position.longitude,
              accuracy: position.accuracy,
            ),
          );
        });
  }

  void _showActivationConfirmation() {
    showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SosActivationSheet(
        location: _locationStatus,
        onContinue: () => Navigator.pop(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final residentName = context.watch<AuthProvider>().userName?.trim();
    return Scaffold(
      backgroundColor: _blue,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight < 640
              ? 640.0
              : constraints.maxHeight;
          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomLeft,
                end: Alignment.topRight,
                colors: [_cyan, _blue],
              ),
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: SizedBox(
                height: height,
                child: CustomPaint(
                  painter: const _SosBackgroundPainter(),
                  child: Column(
                    children: [
                      const _SosBrandHeader(),
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(42, 18, 42, 26),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: height - 223,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _sosButton(constraints.maxWidth),
                                const SizedBox(height: 15),
                                Text(
                                  _sosActivated
                                      ? 'SOS ACTIVE • LOCATION TRACKING ON'
                                      : 'HOLD TO SEND SOS EMERGENCY',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: _headingRed,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: .2,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  _sosActivated
                                      ? 'Your SOS was received. Keep this screen open\n'
                                            'to continue sharing location updates.'
                                      : 'Hold the button for 2 seconds to send an\n'
                                            'emergency alert to the barangay',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFF343434),
                                    fontSize: 11,
                                    height: 1.45,
                                  ),
                                ),
                                const SizedBox(height: 15),
                                _silentMode(),
                                const SizedBox(height: 8),
                                _flashMode(),
                                const SizedBox(height: 12),
                                _emergencyTypeSelector(),
                                const SizedBox(height: 13),
                                _autoCapturedInfo(
                                  residentName?.isNotEmpty == true
                                      ? residentName!
                                      : 'Registered Resident',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 60),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _sosButton(double screenWidth) {
    final diameter = (screenWidth * .32).clamp(112.0, 138.0);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _startHold,
      onTapUp: _cancelHold,
      onTapCancel: _cancelHold,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: _isHolding ? diameter + 8 : diameter,
        height: _isHolding ? diameter + 8 : diameter,
        decoration: BoxDecoration(
          color: _isHolding ? const Color(0xFFFF1C23) : _red,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF650004), width: 3),
          boxShadow: [
            BoxShadow(
              color: _red.withValues(alpha: _isHolding ? .42 : .22),
              blurRadius: _isHolding ? 22 : 8,
              spreadRadius: _isHolding ? 5 : 1,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _sosActivated
                  ? Icons.my_location_rounded
                  : _isSending
                  ? Icons.wifi_tethering_rounded
                  : Icons.notifications_active_outlined,
              color: Colors.black,
              size: diameter * .32,
            ),
            const SizedBox(height: 4),
            Text(
              _sosActivated
                  ? 'SOS ACTIVE'
                  : _isSending
                  ? 'SENDING'
                  : _isHolding
                  ? 'KEEP HOLDING'
                  : 'HOLD 2s',
              style: TextStyle(
                color: Colors.black,
                fontSize: _isHolding ? 13 : 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _silentMode() {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 4, 7, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: _purple, width: 1.2),
      ),
      child: Row(
        children: [
          Icon(
            _isSilentMode ? Icons.volume_off_rounded : Icons.volume_up_rounded,
            color: _ink,
            size: 25,
          ),
          const SizedBox(width: 9),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Silent SOS',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
                Text(
                  'Send without local alert sound or flashlight',
                  style: TextStyle(fontSize: 9, color: Color(0xFF555555)),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: .78,
            child: Switch(
              value: _isSilentMode,
              activeThumbColor: Colors.white,
              activeTrackColor: _purple,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: Colors.black,
              onChanged: (value) {
                setState(() => _isSilentMode = value);
                if (value) unawaited(_stopDeviceFeedback());
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _flashMode() {
    final enabled = !_isSilentMode;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: enabled ? 1 : .5,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 4, 7, 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: _purple, width: 1.2),
        ),
        child: Row(
          children: [
            Icon(
              _flashEnabled ? Icons.flashlight_on : Icons.flashlight_off,
              color: _ink,
              size: 25,
            ),
            const SizedBox(width: 9),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Flash Signal',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'Flash the phone light while holding SOS',
                    style: TextStyle(fontSize: 9, color: Color(0xFF555555)),
                  ),
                ],
              ),
            ),
            Transform.scale(
              scale: .78,
              child: Switch(
                value: _flashEnabled && enabled,
                activeThumbColor: Colors.white,
                activeTrackColor: _purple,
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: Colors.black,
                onChanged: enabled ? _changeFlashSetting : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emergencyTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Select Emergency Type (Optional)',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 7),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: _emergencyTypes.map((type) {
            final selected = _selectedEmergencyType == type;
            return SizedBox(
              height: 30,
              child: ChoiceChip(
                label: Text(type),
                selected: selected,
                showCheckmark: false,
                backgroundColor: Colors.white,
                selectedColor: const Color(0xFFFFE6E8),
                side: BorderSide(color: selected ? _red : _ink),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 2),
                labelStyle: TextStyle(
                  color: _ink,
                  fontSize: 9,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                ),
                onSelected: (value) => setState(() {
                  _selectedEmergencyType = value ? type : null;
                }),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _autoCapturedInfo(String residentName) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(9, 7, 9, 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _purple, width: 1.2),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  'Auto-Captured Information',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                'Read Only',
                style: TextStyle(fontSize: 9, color: Color(0xFF606060)),
              ),
            ],
          ),
          const Divider(height: 10),
          _infoRow(Icons.person, 'Registered Resident', residentName),
          const SizedBox(height: 8),
          _infoRow(
            Icons.location_on,
            'GPS Location',
            _locationStatus,
            onTap: _fetchLiveLocation,
          ),
        ],
      ),
    );
  }

  Widget _infoRow(
    IconData icon,
    String label,
    String value, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: Colors.black),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 9,
                      color: Color(0xFF666666),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.refresh_rounded, size: 16, color: _purple),
          ],
        ),
      ),
    );
  }
}

class _SosActivationSheet extends StatelessWidget {
  const _SosActivationSheet({required this.location, required this.onContinue});

  final String location;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .9,
        ),
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F8EE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF16A34A),
                  size: 54,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'SOS SENT & ACTIVATED',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _ModernEmergencySosState._red,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Your emergency alert has reached HelpHub. Your live location is now being shared for this SOS report.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF555A61),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              const _ActivationStatusRow(
                icon: Icons.send_rounded,
                label: 'SOS successfully sent',
              ),
              const SizedBox(height: 10),
              const _ActivationStatusRow(
                icon: Icons.cloud_done_rounded,
                label: 'Alert received by HelpHub',
              ),
              const SizedBox(height: 10),
              const _ActivationStatusRow(
                icon: Icons.my_location_rounded,
                label: 'Live location tracking active',
                active: true,
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F5F8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      color: _ModernEmergencySosState._purple,
                      size: 21,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        location,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Keep the SOS screen open so location updates can continue.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF777B82), fontSize: 11),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onContinue,
                  icon: const Icon(Icons.location_searching_rounded, size: 19),
                  label: const Text('Continue Location Tracking'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _ModernEmergencySosState._purple,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivationStatusRow extends StatelessWidget {
  const _ActivationStatusRow({
    required this.icon,
    required this.label,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFE8F8EE) : Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: active ? const Color(0xFF16A34A) : const Color(0xFFD8DCE2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: active
                ? const Color(0xFF16A34A)
                : _ModernEmergencySosState._purple,
            size: 21,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
          const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF16A34A),
            size: 20,
          ),
        ],
      ),
    );
  }
}

class _SosBackgroundPainter extends CustomPainter {
  const _SosBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final gradient = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: [
          _ModernEmergencySosState._cyan,
          _ModernEmergencySosState._blue,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, gradient);
    final footerTop = size.height - 60;
    final white = Path()
      ..moveTo(size.width * .24, 119)
      ..lineTo(size.width * .81, 119)
      ..lineTo(size.width, 218)
      ..lineTo(size.width, footerTop - 98)
      ..lineTo(size.width * .76, footerTop)
      ..lineTo(size.width * .19, footerTop)
      ..lineTo(0, footerTop - 104)
      ..lineTo(0, 218)
      ..close();
    canvas.drawPath(white, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SosBrandHeader extends StatelessWidget {
  const _SosBrandHeader();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 119,
      child: SafeArea(
        bottom: false,
        child: Center(
          child: Image.asset(
            'assets/images/helphub_crest.png',
            width: 67,
            height: 72,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}
