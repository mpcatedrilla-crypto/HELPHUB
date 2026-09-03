import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class EmergencySOSScreen extends StatefulWidget {
  const EmergencySOSScreen({super.key});

  @override
  State<EmergencySOSScreen> createState() => _EmergencySOSScreenState();
}

class _EmergencySOSScreenState extends State<EmergencySOSScreen> {
  bool _isHolding = false;
  double _holdProgress = 0.0;
  String? _selectedEmergencyType;

  final List<String> _emergencyTypes = [
    'Being Followed',
    'Violence / Fighting',
    'Fire Hazard',
    'Medical Emergency',
    'Accident'
  ];

  void _onHoldStart(LongPressStartDetails details) async {
    setState(() => _isHolding = true);
    
    // Simulate Location Permission Request and One-Time GPS Capture
    // As defined in Flow 3 - Emergency SOS
    try {
      await Future.delayed(const Duration(seconds: 1)); // Request Permission delay
      await Future.delayed(const Duration(seconds: 1)); // Capture GPS delay
      
      if (_isHolding && mounted) {
        // Prepare SOS Details and Submit
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SOS Alert Sent to Barangay!')),
        );
        setState(() {
          _isHolding = false;
          _holdProgress = 1.0;
        });
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SOS Location Unavailable State. GPS Failed.')),
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
            const SizedBox(height: 40),
            
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
                    _buildInfoRow(Icons.person, 'Registered Resident', 'Juan dela Cruz'),
                    _buildInfoRow(Icons.location_on, 'GPS Location', '14.5995° N, 120.9842° E\nAccuracy: ±5 meters'),
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
