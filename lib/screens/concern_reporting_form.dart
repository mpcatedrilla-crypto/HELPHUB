import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/report_provider.dart';
import '../theme/app_theme.dart';

class ConcernReportingForm extends StatefulWidget {
  const ConcernReportingForm({super.key});

  @override
  State<ConcernReportingForm> createState() => _ConcernReportingFormState();
}

class _ConcernReportingFormState extends State<ConcernReportingForm> {
  int _currentStep = 0;
  
  String? _selectedCategoryId;
  bool _isEmergency = false;
  
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _addressController = TextEditingController();
  
  int _populationScale = 1; // 1 to 5
  
  final List<String> _vulnerableGroups = ['Children', 'Elderly', 'PWDs', 'Pregnant', 'None'];
  final List<String> _selectedVulnerableGroups = [];

  LatLng? _selectedLocation;
  final MapController _mapController = MapController();
  bool _isLocating = false;

  final List<File> _evidenceImages = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ReportProvider>(context, listen: false).fetchConcernTypes();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Location disabled');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw Exception('Permission denied');
      }
      
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Permission permanently denied');
      }

      Position position = await Geolocator.getCurrentPosition();
      final latLng = LatLng(position.latitude, position.longitude);
      
      setState(() {
        _selectedLocation = latLng;
      });
      
      _mapController.move(latLng, 16.0);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not get location: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      if (source == ImageSource.camera) {
        var status = await Permission.camera.status;
        if (!status.isGranted) {
          status = await Permission.camera.request();
          if (!status.isGranted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Camera permission is required.')));
            return;
          }
        }
      }

      final XFile? image = await _picker.pickImage(source: source, imageQuality: 70);
      if (image != null) {
        setState(() {
          _evidenceImages.add(File(image.path));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report Concern')),
      body: Consumer<ReportProvider>(
        builder: (context, provider, child) {
          if (provider.concernTypes.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No categories found. Please run seed_data.sql in Supabase.'),
              ),
            );
          }
          
          return Stepper(
            type: StepperType.vertical,
            currentStep: _currentStep,
            onStepContinue: () async {
              if (_currentStep == 0) {
                if (_selectedCategoryId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a category')));
                  return;
                }
              } else if (_currentStep == 1) {
                if (_titleController.text.isEmpty || _descController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter title and description')));
                  return;
                }
              }
              
              if (_currentStep < 3) {
                setState(() => _currentStep += 1);
                
                // Automatically fetch GPS when reaching the Location step
                if (_currentStep == 2 && _selectedLocation == null) {
                  _getCurrentLocation();
                }
              } else {
                // Submit Form
                final success = await provider.submitReport(
                  typeId: _selectedCategoryId!,
                  title: _titleController.text,
                  description: _descController.text,
                  populationScale: _populationScale,
                  vulnerableGroups: _selectedVulnerableGroups,
                  isEmergency: _isEmergency,
                  latitude: _selectedLocation?.latitude,
                  longitude: _selectedLocation?.longitude,
                  addressNotes: _addressController.text.isEmpty ? null : _addressController.text,
                  evidenceImages: _evidenceImages,
                );
                
                if (mounted) {
                  if (success) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Submission Confirmation: Report sent!')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(provider.errorMessage ?? 'Submission failed')),
                    );
                  }
                }
              }
            },
            onStepCancel: () {
              if (_currentStep > 0) {
                setState(() => _currentStep -= 1);
              } else {
                Navigator.pop(context);
              }
            },
            steps: [
              Step(
                title: const Text('Type'),
                content: _buildCategorySelection(provider.concernTypes),
                isActive: _currentStep >= 0,
                state: _currentStep > 0 ? StepState.complete : StepState.indexed,
              ),
              Step(
                title: const Text('Details'),
                content: _buildDetailsSection(),
                isActive: _currentStep >= 1,
                state: _currentStep > 1 ? StepState.complete : StepState.indexed,
              ),
              Step(
                title: const Text('Location'),
                content: _buildLocationSection(),
                isActive: _currentStep >= 2,
                state: _currentStep > 2 ? StepState.complete : StepState.indexed,
              ),
              Step(
                title: const Text('Evidence'),
                content: _buildEvidenceSection(),
                isActive: _currentStep >= 3,
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildEvidenceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Attach photos of the situation (Optional)', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              onPressed: () => _pickImage(ImageSource.camera),
              icon: const Icon(Icons.camera_alt),
              label: const Text('Camera'),
            ),
            ElevatedButton.icon(
              onPressed: () => _pickImage(ImageSource.gallery),
              icon: const Icon(Icons.photo_library),
              label: const Text('Gallery'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_evidenceImages.isNotEmpty)
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _evidenceImages.length,
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(right: 8, top: 8),
                      width: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: FileImage(_evidenceImages[index]),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _evidenceImages.removeAt(index);
                          });
                        },
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildCategorySelection(List<Map<String, dynamic>> categories) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('What is your concern about?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 2.0,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final cat = categories[index];
            final isSelected = _selectedCategoryId == cat['id'];
            return InkWell(
              onTap: () => setState(() => _selectedCategoryId = cat['id']),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryBlue.withOpacity(0.1) : Colors.white,
                  border: Border.all(color: isSelected ? AppTheme.primaryBlue : Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                padding: const EdgeInsets.all(8),
                child: Text(
                  cat['category_name'],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? AppTheme.primaryBlue : Colors.black87,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          title: const Text('Critical Override (Emergency SOS)', style: TextStyle(color: AppTheme.sosRed, fontWeight: FontWeight.bold)),
          value: _isEmergency,
          activeColor: AppTheme.sosRed,
          onChanged: (val) => setState(() => _isEmergency = val),
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _titleController,
          decoration: InputDecoration(
            labelText: 'Concern Title',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _descController,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Description',
            alignLabelWithHint: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 24),
        const Text('Affected Population Scale', style: TextStyle(fontWeight: FontWeight.bold)),
        Slider(
          value: _populationScale.toDouble(),
          min: 1,
          max: 5,
          divisions: 4,
          label: _populationScale.toString(),
          onChanged: (val) => setState(() => _populationScale = val.toInt()),
        ),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text('Few', style: TextStyle(color: Colors.grey, fontSize: 12)), Text('Community-wide', style: TextStyle(color: Colors.grey, fontSize: 12))],
        ),
        const SizedBox(height: 16),
        const Text('Vulnerable Groups Affected', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _vulnerableGroups.map((group) {
            final isSelected = _selectedVulnerableGroups.contains(group);
            return FilterChip(
              label: Text(group, style: const TextStyle(fontSize: 12)),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedVulnerableGroups.add(group);
                  } else {
                    _selectedVulnerableGroups.remove(group);
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildLocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tap the map to set a pin, or use GPS.', style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 8),
        Container(
          height: 200,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: const LatLng(14.5995, 120.9842), // Manila Default
                    initialZoom: 13.0,
                    onTap: (tapPosition, point) {
                      setState(() {
                        _selectedLocation = point;
                      });
                    },
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
                            width: 40,
                            height: 40,
                            child: const Icon(Icons.location_pin, color: AppTheme.sosRed, size: 40),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: FloatingActionButton.small(
                  backgroundColor: Colors.white,
                  onPressed: _getCurrentLocation,
                  child: _isLocating 
                      ? const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.my_location, color: AppTheme.primaryBlue),
                ),
              )
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _addressController,
          decoration: InputDecoration(
            labelText: 'Exact Address or Landmark (Optional)',
            hintText: 'e.g. In front of the bakery near Plaza',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            prefixIcon: const Icon(Icons.edit_location_alt),
          ),
          maxLines: 2,
        ),
      ],
    );
  }
}
