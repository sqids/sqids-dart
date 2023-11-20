import 'package:flutter_test/flutter_test.dart';
import 'package:sqids/sqids.dart'; // Make sure to replace 'sqids' with the actual package name

void main() {
  group('alphabet', () {
    test('simple', () {
      final sqids = Sqids(options: SqidsOptions(alphabet: '0123456789abcdef'));

      final numbers = [1, 2, 3];
      const id = '489158';

      expect(sqids.encode(numbers), equals(id));
      expect(sqids.decode(id), equals(numbers));
    });

    test('short alphabet', () {
      final sqids = Sqids(options: SqidsOptions(alphabet: 'abc'));

      final numbers = [1, 2, 3];
      expect(sqids.decode(sqids.encode(numbers)), equals(numbers));
    });

    test('long alphabet', () {
      final sqids = Sqids(
        options: SqidsOptions(
            alphabet:
                'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*()-_+|{}[];:\'/?.>,<`~'),
      );

      final numbers = [1, 2, 3];
      expect(sqids.decode(sqids.encode(numbers)), equals(numbers));
    });

    test('repeating alphabet characters', () {
      expect(() => Sqids(options: SqidsOptions(alphabet: 'aabcdefg')),
          throwsA(isA<Exception>()));
    });

    test('too short of an alphabet', () {
      expect(
        () => Sqids(options: SqidsOptions(alphabet: 'ab')),
        throwsA(isA<Exception>()),
      );
    });

    test('too short of an alphabet', () {
      expect(
        () => Sqids(options: SqidsOptions(alphabet: 'ab')),
        throwsA(isA<Exception>()),
      );
    });
  });
}
