import 'package:flutter_test/flutter_test.dart';
import 'package:sqids/sqids.dart';



void main() {
  group('alphabet', () {
    test('simple', () {
      final sqids = Sqids(alphabet: '0123456789abcdef');

      final numbers = [1, 2, 3];
      const id = '489158';

      expect(sqids.encode(numbers), equals(id));
      expect(sqids.decode(id), equals(numbers));
    });

    test('short alphabet', () {
      final sqids = Sqids(alphabet: 'abc');

      final numbers = [1, 2, 3];
      expect(sqids.decode(sqids.encode(numbers)), equals(numbers));
    });

    test('long alphabet', () {
      final sqids = Sqids(
        alphabet:
            'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*()-_+|{}[];:\'/?.>,<`~',
      );

      final numbers = [1, 2, 3];
      expect(sqids.decode(sqids.encode(numbers)), equals(numbers));
    });

    test('repeating alphabet characters', () {
      expect(() => Sqids(alphabet: 'aabcdefg'), throwsA(isA<Exception>()));
    });

    test('too short of an alphabet', () {
      expect(
        () => Sqids(alphabet: 'ab'),
        throwsA(isA<Exception>()),
      );
    });

    test('too short of an alphabet', () {
      expect(
        () => Sqids(alphabet: 'ab'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
