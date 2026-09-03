import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/report_provider.dart';

class EmergencySOSScreen extends StatefulWidget {
  const EmergencySOSScreen({super.key});

  @override
  State<EmergencySOSScreen> createState() => _EmergencySOSScreenState();
}

class _EmergencySOSScreenState extends State<EmergencySOSScreen> {
  bool _isHolding = false;
  double _holdProgress = 0.0;
  String? _selectedEmergencyType;
  
  Position? _currentPosition;
  bool _isSilentMode = false;

  final List<String> _emergencyTypes = [
    'Being Followed',
    'Violence / Fighting',
    'Fire Hazard',
    'Medical Emergency',
    'Accident'
  ];

  @override
  void initState() {
    super.initState();
    _fetchLiveLocation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ReportProvider>(context, listen: false).fetchConcernTypes();
    });
  }

  Future<void> _fetchLiveLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
    } catch (e) {
      debugPrint("Error fetching location: $e");
    }
  }

  void _onHoldStart(LongPressStartDetails details) async {
    setState(() => _isHolding = true);
    
    try {
      await Future.delayed(const Duration(seconds: 2));
      
      if (_isHolding && mounted) {
        // Trigger SOS Submission
        final reportProvider = Provider.of<ReportProvider>(context, listen: false);
        
        // Find a suitable concern type for emergencies
        String typeId = '00000000-0000-0000-0000-000000000000';
        if (reportProvider.concernTypes.isNotEmpty) {
          final peaceOrder = reportProvider.concernTypes.where((t) => t['category_name'] == 'Peace & Order').firstOrNull;
          typeId = peaceOrder?['id'] ?? reportProvider.concernTypes.first['id'];
        }
        
        final success = await reportProvider.submitReport(
          typeId: typeId, 
          title: _selectedEmergencyType ?? 'CRITICAL SOS ALERT',
          description: _isSilentMode ? 'SILENT SOS TRIGGERED' : 'SOS TRIGGERED',
          populationScale: 1,
          vulnerableGroups: [],
          isEmergency: true,
          latitude: _currentPosition?.latitude,
          longitude: _currentPosition?.longitude,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(success ? 'SOS Alert Sent to Barangay!' : 'Failed to send SOS.'),
              backgroundColor: success ? AppTheme.sosRed : Colors.black,
            ),
          );
          
          setState(() {
            _isHolding = false;
            _holdProgress = 1.0;
          });
          
          if (success) {
            Navigator.pop(context);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SOS Failed to send.')),
        );
      }
    }
  }

  void _onHoldEnd(LongPressEndDetails details) {
    setState(() {
      _isHolding = false;
      _holdProgress = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency SOS'),
        backgroundColor: AppTheme.primaryBlue,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.sosRed,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Icon(Icons.fiber_manual_record, color: Colors.white, size: 12),
                SizedBox(width: 4),
                Text('LIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            // The SOS Button
            GestureDetector(
              onLongPressStart: _onHoldStart,
              onLongPressEnd: _onHoldEnd,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: _isHolding ? 220 : 200,
                height: _isHolding ? 220 : 200,
                decoration: BoxDecoration(
                  color: AppTheme.sosRed.withOpacity(_isHolding ? 0.8 : 1.0),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.sosRed.withOpacity(0.4),
                      blurRadius: _isHolding ? 40 : 20,
                      spreadRadius: _isHolding ? 10 : 5,
                    )
                  ],
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.emergency, color: Colors.white, size: 64),
                    SizedBox(height: 8),
                    Text(
                      'HOLD 2s',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Hold to Send SOS',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Hold the button for 2 seconds to send an emergency alert to your Barangay',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 20),
            
            // Silent Mode Toggle
            SwitchListTile(
              title: const Text('Silent Mode', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Send SOS without flashing lights or sounds'),
              value: _isSilentMode,
              activeColor: AppTheme.sosRed,
              onChanged: (val) => setState(() => _isSilentMode = val),
              secondary: const Icon(Icons.volume_off),
            ),
            
            const SizedBox(height: 20),
            // Emergency Type Selection
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Select Emergency Type (optional)', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _emergencyTypes.map((type) {
                final isSelected = _selectedEmergencyType == type;
                return ChoiceChip(
                  label: Text(type),
                  selected: isSelected,
                  selectedColor: AppTheme.sosRed.withOpacity(0.2),
                  onSelected: (selected) {
                    setState(() {
                      _selectedEmergencyType = selected ? type : null;
                    });
                  },
                );
              }).toList(),
            ),
            
            const Spacer(),
            
            // Auto-captured info card
            Card(
              color: AppTheme.surfaceColor,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Auto-Captured Information', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                        Text('Read-only', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                    const Divider(),
                    _buildInfoRow(Icons.person, 'Registered Resident', auth.userName ?? 'Unknown'),
                    _buildInfoRow(
                      Icons.location_on, 
                      'GPS Location', 
                      _currentPosition != null 
                        ? '\${_currentPosition!.latitude.toStringAsFixed(4)}° N, \${_currentPosition!.longitude.toStringAsFixed(4)}° E'
                        : 'Locating...'
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          )
        ],
      ),
    );
  }
}
