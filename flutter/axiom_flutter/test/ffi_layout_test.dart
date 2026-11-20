// F1 regression guard: the Dart FFI structs must mirror the C layout in
// axiom-runtime/include/axiom.h on every ABI, including 32-bit armeabi-v7a.
// `size_t`/`uintptr_t` fields must be declared `@Size()`/`@UintPtr()`: a
// `@Uint64()` there is 16 bytes on 32-bit ARM where C has 8.
import 'dart:ffi';
import 'dart:io';

import 'package:axiom_flutter/src/runtime_io.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';

/// C field types from include/axiom.h (origin/flutter/parity of axiom-runtime).
const _cStructs = <String, List<(String, String)>>{
  'AxiomString': [('ptr', 'ptr'), ('len', 'size_t')],
  'AxiomBuffer': [('ptr', 'ptr'), ('len', 'size_t')],
  'AxiomResponseBuffer': [
    ('requestId', 'uint64_t'),
    ('eventType', 'int32_t'),
    ('errorCode', 'int32_t'),
    ('data', 'AxiomBuffer'),
    ('errorMessage', 'AxiomBuffer'),
  ],
};

const _annotationFor = <String, Set<String>>{
  'size_t': {'@Size()', '@UintPtr()'},
  'uint64_t': {'@Uint64()'},
  'int32_t': {'@Int32()'},
};

void main() {
  final src = File('lib/src/runtime_io.dart').readAsStringSync();

  for (final entry in _cStructs.entries) {
    test('${entry.key} fields use ABI-correct annotations', () {
      final m = RegExp(
        'class ${entry.key} extends Struct \\{([^}]*)\\}',
      ).firstMatch(src);
      expect(m, isNotNull, reason: 'struct ${entry.key} not found');
      final body = m!.group(1)!;
      for (final (name, cType) in entry.value) {
        final f = RegExp(
          r'((?:@\w+\(\)\s*)?)external\s+[\w<>]+\s+' + name + ';',
        ).firstMatch(body);
        expect(f, isNotNull, reason: '${entry.key}.$name missing');
        final ann = f!.group(1)!.trim();
        final allowed = _annotationFor[cType];
        if (allowed == null) {
          expect(ann, isEmpty, reason: '${entry.key}.$name is $cType');
        } else {
          expect(allowed, contains(ann),
              reason: '${entry.key}.$name is $cType in axiom.h, Dart has "$ann"');
        }
      }
    });
  }

  test('struct sizes match the C layout for this ABI', () {
    final p = sizeOf<IntPtr>();
    expect(sizeOf<AxiomString>(), 2 * p);
    expect(sizeOf<AxiomBuffer>(), 2 * p);
    // u64 + i32 + i32 + 2 * {ptr, size_t}
    expect(sizeOf<AxiomResponseBuffer>(), 16 + 4 * p);
  });

  test('AxiomResponseBuffer field offsets match C', () {
    final p = sizeOf<IntPtr>();
    final buf = calloc<AxiomResponseBuffer>();
    try {
      buf.ref.data.len = 0x11;
      buf.ref.errorMessage.len = 0x22;
      final bytes = buf.cast<Uint8>().asTypedList(16 + 4 * p);
      // C offsets: data.len at 16 + p, errorMessage.len at 16 + 3p (little endian).
      expect(bytes[16 + p], 0x11);
      expect(bytes[16 + 3 * p], 0x22);
    } finally {
      calloc.free(buf);
    }
  });
}
