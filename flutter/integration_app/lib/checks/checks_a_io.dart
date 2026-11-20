import 'dart:io';

// ignore: depend_on_referenced_packages
import 'package:path_provider/path_provider.dart';

/// Path of the first `axiom_cache.sled` under `<app support dir>/axiom`.
Future<String?> findSledCache() async {
  final root = Directory('${(await getApplicationSupportDirectory()).path}/axiom');
  if (!root.existsSync()) return null;
  for (final e in root.listSync(recursive: true, followLinks: false)) {
    if (e.path.endsWith('axiom_cache.sled')) return e.path;
  }
  return null;
}
