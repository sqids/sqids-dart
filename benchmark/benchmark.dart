// Micro-benchmark for the Sqids implementation.
//
// Run with: dart run benchmark/benchmark.dart
//
// The same script is run against the pre-optimization implementation (with
// the class renamed) to compare results; timings are from the Dart VM.

import 'package:sqids/sqids.dart';

const _maxValue = 9007199254740991;

const _tenNumbers = [1, 2, 3, 500, 99_999, 1_234_567, 89_101_112, 7, 42, 0];

void _time(String name, int iterations, void Function() body) {
  for (var i = 0, warmup = iterations ~/ 10; i < warmup; i++) {
    body();
  }
  final sw = Stopwatch()..start();
  for (var i = 0; i < iterations; i++) {
    body();
  }
  sw.stop();
  final usPerOp = sw.elapsedMicroseconds / iterations;
  print(
    '| $name | ${usPerOp.toStringAsFixed(2)} µs | '
    '${(1e6 / usPerOp).round()} |',
  );
}

void _benchAll(
  dynamic sqids,
  dynamic sqidsPadded,
  List<int> hundredNumbers,
  String longId,
) {
  // A fixed sample of blocked words, measuring the average hit cost (a single
  // word's cost depends on scan order, which is not meaningful on its own).
  final sample = sqids.blocklist.take(50).toList();
  print('| scenario | time | ops/s |');
  print('| --- | --- | --- |');
  _time('encode([1, 2, 3])', 20000, () => sqids.encode(const [1, 2, 3]));
  _time('encode(10 numbers)', 10000, () => sqids.encode(_tenNumbers));
  _time('encode(100 numbers)', 1000, () => sqids.encode(hundredNumbers));
  _time(
    'encode([1, 2, 3]), minLength: 20',
    10000,
    () => sqidsPadded.encode(const [1, 2, 3]),
  );
  _time("decode('86Rf07')", 50000, () => sqids.decode('86Rf07'));
  _time('decode(100-number ID)', 1000, () => sqids.decode(longId));
  _time(
    "isBlockedId('abcdefghij') — miss, full scan",
    5000,
    () => sqids.isBlockedId('abcdefghij'),
  );
  _time('isBlockedId over 50 blocked words — avg hit', 1000, () {
    for (var i = 0; i < sample.length; i++) {
      sqids.isBlockedId(sample[i]);
    }
  });
  _time(
    'isBlockedId(100-number ID) — miss',
    1000,
    () => sqids.isBlockedId(longId),
  );
}

void main() {
  final sqids = Sqids();
  final sqidsPadded = Sqids(minLength: 20);
  final hundredNumbers = List.generate(
    100,
    (i) => (i * 7_517_977_331 + 101) % _maxValue,
  );
  final longId = sqids.encode(hundredNumbers);

  _benchAll(sqids, sqidsPadded, hundredNumbers, longId);
  _time('Sqids() constructor', 500, () => Sqids());
}
