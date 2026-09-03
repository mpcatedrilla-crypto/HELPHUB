import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  
  int _populationScale = 3; // 1 to 5
  final List<String> _selectedVulnerableGroups = [];
  bool _isEmergency = false;

  final List<String> _vulnerableGroups = [
    'Elderly', 'PWD', 'Children', 'Pregnant'
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ReportProvider>(context, listen: false).fetchConcernTypes();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report a Concern'),
      ),
      body: Consumer<ReportProvider>(
        builder: (context, provider, child) {
          if (provider.concernTypes.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          
          return Stepper(
            type: StepperType.vertical, // Changed to fix overflow
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
              } else {
                // Submit Form
                final success = await provider.submitReport(
                  typeId: _selectedCategoryId!,
                  title: _titleController.text,
                  description: _descController.text,
                  populationScale: _populationScale,
                  vulnerableGroups: _selectedVulnerableGroups,
                  isEmergency: _isEmergency,
                );
                
                if (mounted) {
                  if (success) {
                    Navigator.pop(context); // return to dashboard
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
                content: const Center(child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Map View & Pin Drop will be enabled in a future update.'),
                )),
                isActive: _currentStep >= 2,
                state: _currentStep > 2 ? StepState.complete : StepState.indexed,
              ),
              Step(
                title: const Text('Evidence'),
                content: const Center(child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Camera & Photo Upload will be enabled in a future update.'),
                )),
                isActive: _currentStep >= 3,
              ),
            ],
          );
        }
      ),
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
}
