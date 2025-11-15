import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/prediction_models.dart';
import '../services/api_service.dart';
import 'results_screen.dart';

class PredictionScreen extends StatefulWidget {
  const PredictionScreen({super.key});

  @override
  State<PredictionScreen> createState() => _PredictionScreenState();
}

class _PredictionScreenState extends State<PredictionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();
  
  String? _selectedState;
  String _selectedSeason = 'wet';
  final TextEditingController _yearController = TextEditingController();
  final TextEditingController _areaController = TextEditingController();
  String? _selectedGrade;
  
  List<String> _states = [];
  List<String> _grades = [];
  bool _isLoadingData = true;
  bool _isPredicting = false;

  @override
  void initState() {
    super.initState();
    _loadDropdownData();
  }

  Future<void> _loadDropdownData() async {
    try {
      final states = await _apiService.getStates();
      final grades = await _apiService.getGrades();
      setState(() {
        _states = states;
        _grades = grades;
        _isLoadingData = false;
      });
    } catch (e) {
      print('Error loading dropdown data: $e');
      setState(() {
        _states = [];
        _grades = [];
        _isLoadingData = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load states and grades. Check internet connection.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () {
                setState(() => _isLoadingData = true);
                _loadDropdownData();
              },
            ),
          ),
        );
      }
    }
  }

  Future<void> _predict() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedState == null || _selectedGrade == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select state and quality grade'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isPredicting = true);

    try {
      final request = PredictionRequest(
        state: _selectedState!,
        season: _selectedSeason,
        year: int.parse(_yearController.text),
        areaHa: double.parse(_areaController.text),
        qualityGrade: _selectedGrade!,
      );

      final response = await _apiService.predictYield(request);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ResultsScreen(prediction: response),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Prediction failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      setState(() => _isPredicting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yield Prediction'),
        elevation: 0,
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF2E7D32).withOpacity(0.1),
                    Colors.white,
                  ],
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Text(
                        'Enter Farm Details',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF2E7D32),
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Provide accurate information for better predictions',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                      const SizedBox(height: 32),

                      // State Dropdown
                      _buildLabel('State'),
                      DropdownButtonFormField<String>(
                        value: _selectedState,
                        decoration: const InputDecoration(
                          hintText: 'Select your state',
                          prefixIcon: Icon(Icons.location_on, color: Color(0xFF2E7D32)),
                        ),
                        items: _states.map((state) {
                          return DropdownMenuItem(value: state, child: Text(state));
                        }).toList(),
                        onChanged: (value) => setState(() => _selectedState = value),
                        validator: (value) =>
                            value == null ? 'Please select a state' : null,
                      ),
                      const SizedBox(height: 24),

                      // Season Selection
                      _buildLabel('Season'),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildSeasonButton('Wet Season', 'wet', Icons.water_drop),
                            ),
                            Container(width: 1, height: 40, color: Colors.grey.shade300),
                            Expanded(
                              child: _buildSeasonButton('Dry Season', 'dry', Icons.wb_sunny),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Year Input
                      _buildLabel('Year'),
                      TextFormField(
                        controller: _yearController,
                        decoration: const InputDecoration(
                          hintText: 'Enter year (2000-2030)',
                          prefixIcon: Icon(Icons.calendar_today, color: Color(0xFF2E7D32)),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a year';
                          }
                          final year = int.tryParse(value);
                          if (year == null || year < 2000 || year > 2030) {
                            return 'Year must be between 2000 and 2030';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Area Input
                      _buildLabel('Farm Area (hectares)'),
                      TextFormField(
                        controller: _areaController,
                        decoration: const InputDecoration(
                          hintText: 'Enter area in hectares',
                          prefixIcon: Icon(Icons.landscape, color: Color(0xFF2E7D32)),
                          suffixText: 'ha',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter farm area';
                          }
                          final area = double.tryParse(value);
                          if (area == null || area <= 0 || area > 1000) {
                            return 'Area must be between 0 and 1000 hectares';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Quality Grade Dropdown
                      _buildLabel('Quality Grade'),
                      DropdownButtonFormField<String>(
                        value: _selectedGrade,
                        decoration: const InputDecoration(
                          hintText: 'Select maize quality grade',
                          prefixIcon: Icon(Icons.grade, color: Color(0xFF2E7D32)),
                        ),
                        items: _grades.map((grade) {
                          return DropdownMenuItem(value: grade, child: Text(grade));
                        }).toList(),
                        onChanged: (value) => setState(() => _selectedGrade = value),
                        validator: (value) =>
                            value == null ? 'Please select a quality grade' : null,
                      ),
                      const SizedBox(height: 40),

                      // Predict Button
                      ElevatedButton(
                        onPressed: _isPredicting ? null : _predict,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                        ),
                        child: _isPredicting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.analytics, size: 24),
                                  SizedBox(width: 12),
                                  Text(
                                    'Predict Yield',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Color(0xFF2E7D32),
        ),
      ),
    );
  }

  Widget _buildSeasonButton(String label, String value, IconData icon) {
    final isSelected = _selectedSeason == value;
    return InkWell(
      onTap: () => setState(() => _selectedSeason = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2E7D32) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[600],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _yearController.dispose();
    _areaController.dispose();
    super.dispose();
  }
}
