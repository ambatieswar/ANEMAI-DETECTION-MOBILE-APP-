import 'dart:typed_data';

class ScreeningResult {
  final String label;
  final double riskProbability;
  final double qualityScore;
  final DateTime createdAt;
  final Uint8List? heatmap;
  final String disclaimer;

  const ScreeningResult({
    required this.label,
    required this.riskProbability,
    required this.qualityScore,
    required this.createdAt,
    required this.heatmap,
    required this.disclaimer,
  });

  bool get suggestsIncreasedRisk =>
      label == 'AI Screening Suggests Increased Risk';

  Map<String, dynamic> toJson() => {
        'label': label,
        'riskProbability': riskProbability,
        'qualityScore': qualityScore,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'heatmap': heatmap,
        'disclaimer': disclaimer,
      };

  factory ScreeningResult.fromJson(Map<String, dynamic> json) {
    return ScreeningResult(
      label: json['label'] as String,
      riskProbability: (json['riskProbability'] as num).toDouble(),
      qualityScore: (json['qualityScore'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      heatmap: json['heatmap'] is List
          ? Uint8List.fromList((json['heatmap'] as List).cast<int>())
          : null,
      disclaimer: json['disclaimer'] as String,
    );
  }
}
