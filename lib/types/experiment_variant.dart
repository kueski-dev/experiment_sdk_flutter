import 'dart:convert';

class ExperimentVariant {
  String value;
  Map<String, dynamic>? payload;

  ExperimentVariant({required this.value, this.payload});

  factory ExperimentVariant.fromMap(Map<String, dynamic> map) {
    // Safe cast for payload - handles non-Map types
    final rawPayload = map['payload'];
    final payloadOnMap = rawPayload is Map<String, dynamic> ? rawPayload : null;

    return ExperimentVariant(
      value: (map['value'] as String?) ?? '',
      payload: payloadOnMap?['value'] is Map<String, dynamic>
          ? payloadOnMap!['value'] as Map<String, dynamic>
          : null,
    );
  }

  String toJsonAsString() {
    final toEncode = {};

    toEncode['value'] = value;
    toEncode['payload'] = payload ?? {};

    return jsonEncode(toEncode);
  }
}
