import 'dart:convert';

import 'package:experiment_sdk_flutter/local_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // apiKey 'test-api-key' → last 6 chars = 'pi-key' → namespace = 'ampli-pi-key'
  const apiKey = 'test-api-key';
  const namespace = 'ampli-pi-key';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('LocalStorage.load()', () {
    test('does not crash when a foreign key holds a plain UUID string', () async {
      // This is the exact scenario from the production crash:
      // a UUID stored by another library ends up in SharedPreferences
      // and jsonDecode throws FormatException on it.
      SharedPreferences.setMockInitialValues({
        '$namespace/my-flag': '{"value":"on","payload":{}}',
        'foreign-uuid-key': '42f26f45-6aa6-43c0-8041-37c0527853c3',
      });

      final storage = LocalStorage(apiKey: apiKey);

      await expectLater(storage.load(), completes);
    });

    test('does not crash when SharedPreferences contains non-String typed values', () async {
      // SharedPreferences can store int, double, bool, List<String>.
      // prefs.get(key) returns dynamic — if not guarded, jsonDecode
      // would be called on a non-String and throw a TypeError.
      SharedPreferences.setMockInitialValues({
        '$namespace/flag': '{"value":"control","payload":{}}',
        'some_int_key': 42,
        'some_bool_key': true,
      });

      final storage = LocalStorage(apiKey: apiKey);

      await expectLater(storage.load(), completes);
    });

    test('does not crash when a String value is valid JSON but not a Map', () async {
      // jsonDecode succeeds but the result is not a Map<String, dynamic>,
      // so ExperimentVariant.fromMap cannot be called on it.
      SharedPreferences.setMockInitialValues({
        '$namespace/flag': '{"value":"treatment","payload":{}}',
        'array_value': '["a","b","c"]',
        'number_value': '99',
      });

      final storage = LocalStorage(apiKey: apiKey);

      await expectLater(storage.load(), completes);
    });

    test('loads only entries whose key starts with the namespace prefix', () async {
      // Keys from other SDKs or libraries must be ignored even if their
      // values happen to be valid JSON that could be decoded as a Map.
      SharedPreferences.setMockInitialValues({
        '$namespace/my-flag': '{"value":"treatment","payload":{}}',
        'other-sdk-key': '{"value":"should-not-load","payload":{}}',
        'foreign-uuid-key': '42f26f45-6aa6-43c0-8041-37c0527853c3',
      });

      final storage = LocalStorage(apiKey: apiKey);
      await storage.load();

      final all = storage.getAll();

      expect(all.length, 1);
      expect(all['$namespace/my-flag']?.value, 'treatment');
      expect(all.containsKey('other-sdk-key'), isFalse);
      expect(all.containsKey('foreign-uuid-key'), isFalse);
    });

    test('correctly deserializes value and payload from stored JSON', () async {
      final storedJson = jsonEncode({
        'value': 'variant-b',
        'payload': {'value': {'color': 'blue', 'size': 42}},
      });

      SharedPreferences.setMockInitialValues({
        '$namespace/experiment-flag': storedJson,
      });

      final storage = LocalStorage(apiKey: apiKey);
      await storage.load();

      final variant = storage.get('$namespace/experiment-flag');

      expect(variant, isNotNull);
      expect(variant!.value, 'variant-b');
      expect(variant.payload, isNotNull);
      expect(variant.payload!['color'], 'blue');
      expect(variant.payload!['size'], 42);
    });

    test('returns an empty map when SharedPreferences has no matching keys', () async {
      SharedPreferences.setMockInitialValues({
        'completely-foreign-key': 'some-non-json-value',
        'another-foreign-key': '12345',
      });

      final storage = LocalStorage(apiKey: apiKey);
      await storage.load();

      expect(storage.getAll(), isEmpty);
    });
  });
}
