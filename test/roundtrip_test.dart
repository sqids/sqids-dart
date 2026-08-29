import 'dart:math';

import 'package:sqids/sqids.dart';
import 'package:test/test.dart';

const _maxValue = 9007199254740991;

const _alphabets = [
  'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789',
  '0123456789abcdef',
  'abc',
  'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
      r'!@#$%^&*()-_+|{}[];:'
      '"/?.>,<`~',
];

/// Uniformly random number in [0, 2^53 - 1] from 21 + 31 + 1 random bits.
int _randomBig(Random random) {
  return (random.nextInt(1 << 21) << 32) +
      (random.nextInt(1 << 31) << 1) +
      random.nextInt(2);
}

void main() {
  group('round trip', () {
    test('empty input', () {
      final sqids = Sqids();
      expect(sqids.encode([]), '');
      expect(sqids.decode(''), isEmpty);
    });

    test('boundary values', () {
      final sqids = Sqids();
      const cases = [
        [0],
        [_maxValue],
        [0, _maxValue],
        [_maxValue, 0, _maxValue],
        [1, _maxValue, 123456789, _maxValue - 1],
      ];
      for (final numbers in cases) {
        expect(sqids.decode(sqids.encode(numbers)), numbers);
      }
    });

    test('out of range numbers throw', () {
      final sqids = Sqids();
      expect(() => sqids.encode([-1]), throwsA(isA<Exception>()));
      expect(() => sqids.encode([_maxValue + 1]), throwsA(isA<Exception>()));
    });

    test('deterministic fuzz over alphabets and min lengths', () {
      final random = Random(42);
      for (final alphabet in _alphabets) {
        for (var round = 0; round < 50; round++) {
          final minLength = random.nextInt(32);
          final sqids = Sqids(alphabet: alphabet, minLength: minLength);
          final numbers = List.generate(
            1 + random.nextInt(8),
            (_) => _randomBig(random),
          );
          final id = sqids.encode(numbers);
          expect(id.length, greaterThanOrEqualTo(minLength));
          expect(
            sqids.decode(id),
            numbers,
            reason:
                'alphabet=$alphabet minLength=$minLength '
                'numbers=$numbers id=$id',
          );
        }
      }
    });
  });
}
