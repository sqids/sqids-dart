import 'dart:math';

import 'package:sqids/blocked.dart';

class SqidsOptions {
  String? alphabet;
  int? minLength;
  Set<String>? blocklist;

  SqidsOptions({this.alphabet, this.minLength, this.blocklist});
}

class Sqids {
  late String alphabet;
  late int minLength;
  late Set<String> blocklist;

  Sqids({SqidsOptions? options}) {
    final defaultOptions = {
      'alphabet':
          'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789',
      'minLength': 0,
      'blocklist': blocked.toSet(),
    };

    alphabet = options?.alphabet ?? defaultOptions['alphabet'] as String;
    minLength = options?.minLength ?? defaultOptions['minLength'] as int;
    blocklist =
        options?.blocklist ?? defaultOptions['blocklist'] as Set<String>;

    if (alphabet.isEmpty) {
      throw Exception('Alphabet cannot contain multibyte characters');
    }

    const minAlphabetLength = 3;
    if (alphabet.length < minAlphabetLength) {
      throw Exception('Alphabet length must be at least $minAlphabetLength');
    }

    if (Set.of(alphabet.split('')).length != alphabet.length) {
      throw Exception('Alphabet must contain unique characters');
    }

    const minLengthLimit = 255;
    if ((minLength < 0 || minLength > minLengthLimit)) {
      throw Exception('Minimum length has to be between 0 and $minLengthLimit');
    }

    final filteredBlocklist = <String>{};
    final alphabetChars = alphabet.toLowerCase().split('');
    for (final word in blocklist) {
      if (word.length >= 3) {
        final wordLowercased = word.toLowerCase();
        final wordChars = wordLowercased.split('');
        final intersection =
            wordChars.where((c) => alphabetChars.contains(c)).toList();
        if (intersection.length == wordChars.length) {
          filteredBlocklist.add(wordLowercased);
        }
      }
    }

    alphabet = shuffle(alphabet);
    minLength = minLength;
    blocklist = filteredBlocklist;
  }

  String encode(List<int> numbers) {
    if (numbers.isEmpty) {
      return '';
    }

    final inRangeNumbers =
        numbers.where((n) => n >= 0 && n <= maxValue()).toList();
    if (inRangeNumbers.length != numbers.length) {
      throw Exception('Encoding supports numbers between 0 and ${maxValue()}');
    }

    return encodeNumbers(numbers);
  }

  List<int> decode(String id) {
    List<int> ret = [];

    if (id.isEmpty) {
      return ret;
    }

    List<String> alphabetChars = this.alphabet.split('');
    for (String c in id.split('')) {
      if (!alphabetChars.contains(c)) {
        return ret;
      }
    }

    String prefix = id[0];
    int offset = this.alphabet.indexOf(prefix);
    String alphabet =
        this.alphabet.substring(offset) + this.alphabet.substring(0, offset);
    alphabet = alphabet.split('').reversed.join('');
    String slicedId = id.substring(1);

    while (slicedId.isNotEmpty) {
      String separator = alphabet.substring(0, 1);

      List<String> chunks = slicedId.split(separator);
      if (chunks.isNotEmpty) {
        if (chunks[0].isEmpty) {
          return ret;
        }

        ret.add(toNumber(chunks[0], alphabet.substring(1)));
        if (chunks.length > 1) {
          alphabet = shuffle(alphabet);
        }
      }

      slicedId = chunks.sublist(1).join(separator);
    }

    return ret;
  }

  String encodeNumbers(List<int> numbers, [int increment = 0]) {
    if (increment > this.alphabet.length) {
      throw Exception('Reached max attempts to re-generate the ID');
    }

    int offset = 0;

    for (int i = 0; i < numbers.length; i++) {
      int v = numbers[i];
      offset += this.alphabet[v % this.alphabet.length].codeUnitAt(0) + i;
    }

    offset = (offset + numbers.length) % this.alphabet.length;

    offset = (offset + increment) % this.alphabet.length;
    String alphabet =
        this.alphabet.substring(offset) + this.alphabet.substring(0, offset);
    String prefix = alphabet[0];
    alphabet = alphabet.split('').reversed.join('');
    List<String> ret = [prefix];

    for (int i = 0; i < numbers.length; i++) {
      int num = numbers[i];

      ret.add(toId(num, alphabet.substring(1)));
      if (i < numbers.length - 1) {
        ret.add(alphabet.substring(0, 1));
        alphabet = shuffle(alphabet);
      }
    }

    String id = ret.join('');

    if (minLength > id.length) {
      id += alphabet.substring(0, 1);

      for (int i = minLength - id.length; i > 0; i -= alphabet.length) {
        alphabet = shuffle(alphabet);
        id +=
            alphabet.substring(0, (i < alphabet.length) ? i : alphabet.length);
      }
    }

    if (isBlockedId(id)) {
      id = encodeNumbers(numbers, increment + 1);
    }

    return id;
  }

  String shuffle(String alphabet) {
    final chars = alphabet.split('');

    for (var i = 0, j = chars.length - 1; j > 0; i++, j--) {
      final r = (i * j + chars[i].codeUnitAt(0) + chars[j].codeUnitAt(0)) %
          chars.length;
      final temp = chars[i];
      chars[i] = chars[r];
      chars[r] = temp;
    }

    return chars.join('');
  }

  String toId(int num, String alphabet) {
    final id = <String>[];
    final chars = alphabet.split('');

    var result = num;

    do {
      id.insert(0, chars[result % chars.length]);
      result = (result / chars.length).floor();
    } while (result > 0);

    return id.join('');
  }

  int toNumber(String id, String alphabet) {
    final chars = alphabet.split('');
    return id.split('').fold(0, (a, v) => a * chars.length + chars.indexOf(v));
  }

  bool isBlockedId(String id) {
    final lowercaseId = id.toLowerCase();

    for (final word in blocklist) {
      if (word.length <= lowercaseId.length) {
        if (lowercaseId.length <= 3 || word.length <= 3) {
          if (lowercaseId == word) {
            return true;
          }
        } else if (RegExp(r'\d').hasMatch(word)) {
          if (lowercaseId.startsWith(word) || lowercaseId.endsWith(word)) {
            return true;
          }
        } else if (lowercaseId.contains(word)) {
          return true;
        }
      }
    }

    return false;
  }

  int maxValue() {
    return (pow(2, 53) - 1).toInt();
  }
}
