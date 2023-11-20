import 'package:flutter_test/flutter_test.dart';
import 'package:sqids/sqids.dart'; // Make sure to replace 'sqids' with the actual package name

void main() {
  group('blocklist', () {
    test('if no custom blocklist param, use the default blocklist', () {
      final sqids = Sqids();

      expect(sqids.decode('aho1e'), equals([4572721]));
      expect(sqids.encode([4572721]), equals('JExTR'));
    });

    test("if an empty blocklist param passed, don't use any blocklist", () {
      final sqids = Sqids(options: SqidsOptions(blocklist: <String>{}));

      expect(sqids.decode('aho1e'), equals([4572721]));
      expect(sqids.encode([4572721]), equals('aho1e'));
    });

    test('if a non-empty blocklist param passed, use only that', () {
      final sqids = Sqids(
        options:
            SqidsOptions(blocklist: {'ArUO'}), // originally encoded [100000]
      );

      // make sure we don't use the default blocklist
      expect(sqids.decode('aho1e'), equals([4572721]));
      expect(sqids.encode([4572721]), equals('aho1e'));

      // make sure we are using the passed blocklist
      expect(sqids.decode('ArUO'), equals([100000]));
      expect(sqids.encode([100000]), equals('QyG4'));
      expect(sqids.decode('QyG4'), equals([100000]));
    });

    test('blocklist', () {
      final sqids = Sqids(
        options: SqidsOptions(blocklist: {
          'JSwXFaosAN', // normal result of 1st encoding, let's block that word on purpose
          'OCjV9JK64o', // result of 2nd encoding
          'rBHf', // result of 3rd encoding is `4rBHfOiqd3`, let's block a substring
          '79SM', // result of 4th encoding is `dyhgw479SM`, let's block the postfix
          '7tE6', // result of 4th encoding is `7tE6jdAHLe`, let's block the prefix
        }),
      );

      expect(sqids.encode([1000000, 2000000]), equals('1aYeB7bRUt'));
      expect(sqids.decode('1aYeB7bRUt'), equals([1000000, 2000000]));
    });

    test('decoding blocklist words should still work', () {
      final sqids = Sqids(
        options: SqidsOptions(
            blocklist: {'86Rf07', 'se8ojk', 'ARsz1p', 'Q8AI49', '5sQRZO'}),
      );

      expect(sqids.decode('86Rf07'), equals([1, 2, 3]));
      expect(sqids.decode('se8ojk'), equals([1, 2, 3]));
      expect(sqids.decode('ARsz1p'), equals([1, 2, 3]));
      expect(sqids.decode('Q8AI49'), equals([1, 2, 3]));
      expect(sqids.decode('5sQRZO'), equals([1, 2, 3]));
    });

    test('match against a short blocklist word', () {
      final sqids = Sqids(options: SqidsOptions(blocklist: {'pnd'}));

      expect(sqids.decode(sqids.encode([1000])), equals([1000]));
    });

    test('blocklist filtering in constructor', () {
      final sqids = Sqids(
        options: SqidsOptions(
            alphabet: 'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
            blocklist: {
              'sxnzkl'
            }), // lowercase blocklist in only-uppercase alphabet
      );

      final id = sqids.encode([1, 2, 3]);
      final numbers = sqids.decode(id);

      expect(id, equals('IBSHOZ')); // without blocklist, would've been "SXNZKL"
      expect(numbers, equals([1, 2, 3]));
    });

    test('max encoding attempts', () {
      const alphabet = 'abc';
      const minLength = 3;
      final blocklist = {'cab', 'abc', 'bca'};

      final sqids = Sqids(
          options: SqidsOptions(
        alphabet: alphabet,
        minLength: minLength,
        blocklist: blocklist,
      ));

      expect(alphabet.length, equals(minLength));
      expect(blocklist.length, equals(minLength));

      expect(() => sqids.encode([0]), throwsA(isA<Exception>()));
    });
  });
}
