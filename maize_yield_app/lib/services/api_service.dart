import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/prediction_models.dart';

class ApiService {
  static const String baseUrl = 'https://ml-mobileapp-linear-regression.onrender.com';

  Future<PredictionResponse> predictYield(PredictionRequest request) async {
    try {
      print('Making prediction request to: $baseUrl/predict');
      print('Request body: ${json.encode(request.toJson())}');
      
      final response = await http.post(
        Uri.parse('$baseUrl/predict'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(request.toJson()),
      ).timeout(const Duration(seconds: 30));

      print('Prediction response status: ${response.statusCode}');
      print('Prediction response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return PredictionResponse.fromJson(data);
      } else if (response.statusCode == 422) {
        final errorData = json.decode(response.body);
        final details = errorData['detail'] as List;
        final firstError = details.isNotEmpty ? details[0] : {};
        final msg = firstError['msg'] ?? 'Validation error';
        throw Exception('Validation Error: $msg');
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('Prediction error: $e');
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Network error: Unable to connect to server. Check your internet connection.');
    }
  }

  Future<List<String>> getStates() async {
    try {
      print('Fetching states from: $baseUrl/states');
      final response = await http.get(
        Uri.parse('$baseUrl/states'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      print('States response status: ${response.statusCode}');
      print('States response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<String>.from(data['states']);
      } else {
        throw Exception('Server returned status ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching states: $e');
      throw Exception('Unable to fetch states: $e');
    }
  }

  Future<List<String>> getGrades() async {
    try {
      print('Fetching grades from: $baseUrl/grades');
      final response = await http.get(
        Uri.parse('$baseUrl/grades'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      print('Grades response status: ${response.statusCode}');
      print('Grades response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // API returns "grades" not "quality_grades"
        return List<String>.from(data['grades']);
      } else {
        throw Exception('Server returned status ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching grades: $e');
      throw Exception('Unable to fetch grades: $e');
    }
  }
}
