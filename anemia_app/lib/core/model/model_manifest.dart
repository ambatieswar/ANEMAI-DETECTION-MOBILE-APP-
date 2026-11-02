import 'dart:convert';

class ModelManifest {
  final String modelId;
  final bool enabled;
  final String status;
  final String? sha256;
  final Map<String, dynamic> input;
  final Map<String, dynamic> output;

  const ModelManifest({
    required this.modelId,
    required this.enabled,
    required this.status,
    required this.sha256,
    required this.input,
    required this.output,
  });

  factory ModelManifest.fromJson(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Model manifest must be a JSON object.');
    }

    final input = decoded['input'];
    final output = decoded['output'];
    if (input is! Map<String, dynamic> || output is! Map<String, dynamic>) {
      throw const FormatException(
          'Model manifest tensor contracts are missing.');
    }

    return ModelManifest(
      modelId: decoded['model_id'] as String? ?? 'unknown',
      enabled: decoded['enabled'] == true,
      status: decoded['status'] as String? ?? 'unknown',
      sha256: decoded['model_sha256'] as String?,
      input: input,
      output: output,
    );
  }
}
