import 'dart:convert';
import 'dart:io';

/// The shared vectors in packages/test-vectors. `dart test` runs from the
/// package root.
final Map<String, dynamic> vectors = readVector('receipts.json');

Map<String, dynamic> readVector(String path) =>
    jsonDecode(File('../test-vectors/$path').readAsStringSync())
        as Map<String, dynamic>;

List<Map<String, dynamic>> section(String name) =>
    (vectors[name] as List).cast<Map<String, dynamic>>();
