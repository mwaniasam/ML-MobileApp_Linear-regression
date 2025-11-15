class PredictionRequest {
  final String state;
  final String season;
  final int year;
  final double areaHa;
  final String qualityGrade;

  PredictionRequest({
    required this.state,
    required this.season,
    required this.year,
    required this.areaHa,
    required this.qualityGrade,
  });

  Map<String, dynamic> toJson() {
    return {
      'state': state,
      'season': season,
      'year': year,
      'area_ha': areaHa,
      'quality_grade': qualityGrade,
    };
  }
}

class PredictionResponse {
  final double predictedYield;
  final String state;
  final String season;
  final int year;
  final double areaHa;
  final String qualityGrade;

  PredictionResponse({
    required this.predictedYield,
    required this.state,
    required this.season,
    required this.year,
    required this.areaHa,
    required this.qualityGrade,
  });

  factory PredictionResponse.fromJson(Map<String, dynamic> json) {
    return PredictionResponse(
      predictedYield: (json['predicted_yield'] as num).toDouble(),
      state: json['input_parameters']['state'] as String,
      season: json['input_parameters']['season'] as String,
      year: json['input_parameters']['year'] as int,
      areaHa: (json['input_parameters']['area_ha'] as num).toDouble(),
      qualityGrade: json['input_parameters']['quality_grade'] as String,
    );
  }
}
