// Parsing of the runtime's validation marker (Complete event data, runtime
// 0.150.1) into AxiomState.validation, with fake runtime event payloads.
import 'dart:convert';
import 'dart:typed_data';

import 'package:axiom_flutter/axiom_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _event(String json) => Uint8List.fromList(utf8.encode(json));

void main() {
  group('AxiomValidationMode.fromCompleteData', () {
    test('empty Complete data means full', () {
      expect(AxiomValidationMode.fromCompleteData(Uint8List(0)),
          AxiomValidationMode.full);
    });
    test('marker sample / off', () {
      expect(
          AxiomValidationMode.fromCompleteData(
              _event('{"v":1,"validation":"sample"}')),
          AxiomValidationMode.sampled);
      expect(
          AxiomValidationMode.fromCompleteData(
              _event('{"v":1,"validation":"off"}')),
          AxiomValidationMode.off);
    });
    test('stage-timer JSON carries the same field', () {
      expect(
          AxiomValidationMode.fromCompleteData(_event(
              '{"v":1,"id":42,"queueNs":21000,"validateNs":1070000,'
              '"validation":"sample","cache":"none","status":200}')),
          AxiomValidationMode.sampled);
      for (final v in ['full', 'syntax', 'none']) {
        expect(
            AxiomValidationMode.fromCompleteData(
                _event('{"v":1,"id":1,"validation":"$v"}')),
            AxiomValidationMode.full,
            reason: v);
      }
    });
    test('garbage or unknown values are unknown', () {
      expect(AxiomValidationMode.fromCompleteData(_event('not json')),
          AxiomValidationMode.unknown);
      expect(
          AxiomValidationMode.fromCompleteData(
              _event('{"validation":"later"}')),
          AxiomValidationMode.unknown);
    });
  });

  test('AxiomState carries validation through map and withValidation', () {
    final s = AxiomState<int>.success(1, AxiomSource.network);
    expect(s.validation, AxiomValidationMode.unknown);
    final v = s.withValidation(AxiomValidationMode.sampled);
    expect(v.validation, AxiomValidationMode.sampled);
    expect(v.data, 1);
    expect(v.map((d) => '$d').validation, AxiomValidationMode.sampled);
  });

  test('AxiomCallOptions and AxiomConfig carry the validation policy', () {
    const o = AxiomCallOptions(validation: AxiomValidationPolicy.full);
    expect(o.validation!.name, 'full');
    expect(o.copyWith(timeout: const Duration(seconds: 1)).validation,
        AxiomValidationPolicy.full);
    const c = AxiomConfig(contracts: {}, validation: AxiomValidationPolicy.off);
    expect(c.copyWith(debug: true).validation, AxiomValidationPolicy.off);
    expect(AxiomValidationPolicy.values.map((e) => e.name),
        ['auto', 'full', 'sample', 'off']);
  });
}
