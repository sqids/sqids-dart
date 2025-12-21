// ignore_for_file: prefer_initializing_formals

import 'dart:math';

import 'package:sqids/src/defaults.dart' as defaults;

class Sqids {
  // Properties
  late String alphabet;
  late int minLength;
  late Set<String> blocklist;
  static final _numberRegex = RegExp(r'\d');

  // Constructor
  Sqids({
    String alphabet = defaults.alphabet,
    int minLength = 0,
    Set<String>? blocklist,
  }) {
    this.alphabet = _validateAlphabet(alphabet);
    this.minLength = _validateMinLength(minLength);
    this.blocklist = _filterBlocklist(blocklist ?? defaults.blocked, alphabet);
    this.alphabet = shuffle(this.alphabet);
  }

  // Encode a list of numbers into a string
  String encode(List<int> numbers) {
    if (numbers.isEmpty) {
      return '';
    }

    // Validate that all numbers are in the valid range
    final inRangeNumbers = numbers
        .where((n) => n >= 0 && n <= maxValue())
        .toList();
    if (inRangeNumbers.length != numbers.length) {
      throw Exception('Encoding supports numbers between 0 and ${maxValue()}');
    }

    return encodeNumbers(numbers);
  }

  // Decode a string into a list of numbers
  List<int> decode(String id) {
    List<int> ret = [];

    if (id.isEmpty) {
      return ret;
    }

    // Validate that all characters in the ID are part of the alphabet
    List<String> alphabetChars = this.alphabet.split('');
    for (String c in id.split('')) {
      if (!alphabetChars.contains(c)) {
        return ret;
      }
    }

    // Initialize variables for decoding
    String prefix = id[0];
    int offset = this.alphabet.indexOf(prefix);
    String alphabet =
        this.alphabet.substring(offset) + this.alphabet.substring(0, offset);
    alphabet = alphabet.split('').reversed.join('');
    String slicedId = id.substring(1);

    // Decode the ID
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

  // Encode a list of numbers into a string with optional increment
  String encodeNumbers(List<int> numbers, [int increment = 0]) {
    if (increment > this.alphabet.length) {
      throw Exception('Reached max attempts to re-generate the ID');
    }

    int offset = 0;
    int len = numbers.length;

    // Calculate the offset based on the numbers
    for (int i = 0; i < len; i++) {
      int v = numbers[i];
      offset += this.alphabet.codeUnitAt(v % this.alphabet.length) + i;
    }

    offset = (offset + len) % this.alphabet.length;

    offset = (offset + increment) % this.alphabet.length;

    // Create internal alphabet as a list to avoid repeated string splits
    // Using string manipulation for the initial rotation as it's just one time
    String alphabetStr =
        this.alphabet.substring(offset) + this.alphabet.substring(0, offset);
    String prefix = alphabetStr[0];
    List<String> alphabet = alphabetStr.split('').reversed.toList();

    StringBuffer result = StringBuffer();
    result.write(prefix);

    // Generate the encoded ID
    for (int i = 0; i < len; i++) {
      int num = numbers[i];

      // Using a helper that works with List<String> would be faster but toId expects String
      // For now, let's keep toId adaptable or pass the current state
      // Actually passing the list sublist as string is expensive: alphabet.substring(1)
      // Let's optimize shuffle to work on the list in place if possible,
      // but shuffle returns a new 'alphabet' state.

      // We need to match the spec exactly on how alphabet evolves.
      // alphabet = shuffle(alphabet) returns a string in original code.
      // Let's rewrite optimal shuffle and toId.

      result.write(toId(num, alphabet.sublist(1).join('')));

      if (i < len - 1) {
        result.write(alphabet.sublist(0, 1).join(''));
        _shuffleInPlace(alphabet);
      }
    }

    String id = result.toString();

    // Ensure the ID meets the minimum length
    if (minLength > id.length) {
      id += alphabet[0];

      while (minLength - id.length > 0) {
        _shuffleInPlace(alphabet);
        int diff = minLength - id.length;
        if (diff > 0) {
          id += alphabet.sublist(0, min(diff, alphabet.length)).join('');
        }
      }
    }

    // If the generated ID is blocked, recursively regenerate with an increment
    if (isBlockedId(id)) {
      id = encodeNumbers(numbers, increment + 1);
    }

    return id;
  }

  // Shuffle the characters of the alphabet
  String shuffle(String alphabet) {
    if (alphabet.isEmpty) return alphabet;
    final chars = alphabet.split('');
    _shuffleInPlace(chars);
    return chars.join('');
  }

  void _shuffleInPlace(List<String> chars) {
    for (int i = 0, j = chars.length - 1; j > 0; i++, j--) {
      final r =
          (i * j + chars[i].codeUnitAt(0) + chars[j].codeUnitAt(0)) %
          chars.length;
      final temp = chars[i];
      chars[i] = chars[r];
      chars[r] = temp;
    }
  }

  // Convert a number to a string ID using a custom alphabet
  String toId(int num, String alphabet) {
    final id = StringBuffer();
    final chars = alphabet.split('');
    final int charsLength = chars.length;

    int result = num;

    do {
      id.write(chars[result % charsLength]);
      result = (result / charsLength).floor();
    } while (result > 0);

    return id.toString().split('').reversed.join('');
  }

  // Convert a string ID to a number using a custom alphabet
  int toNumber(String id, String alphabet) {
    final chars = alphabet.split('');
    return id.split('').fold(0, (a, v) => a * chars.length + chars.indexOf(v));
  }

  // Check if an ID is blocked based on the blocklist
  bool isBlockedId(String id) {
    final lowercaseId = id.toLowerCase();

    for (final word in blocklist) {
      if (word.length <= lowercaseId.length) {
        if (lowercaseId.length <= 3 || word.length <= 3) {
          if (lowercaseId == word) {
            return true;
          }
        } else if (_numberRegex.hasMatch(word)) {
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

  // Get the maximum value supported for encoding
  int maxValue() {
    return (pow(2, 53) - 1).toInt();
  }

  static String _validateAlphabet(String alphabet) {
    const minAlphabetLength = 3;

    if (alphabet.length < minAlphabetLength) {
      throw Exception('Alphabet length must be at least $minAlphabetLength');
    }

    if (Set.of(alphabet.split('')).length != alphabet.length) {
      throw Exception('Alphabet must contain unique characters');
    }
    return alphabet;
  }

  static int _validateMinLength(int minLength) {
    const minLengthLimit = 255;
    if (minLength < 0 || minLength > minLengthLimit) {
      throw Exception('Minimum length has to be between 0 and $minLengthLimit');
    }
    return minLength;
  }

  static Set<String> _filterBlocklist(Set<String> blocklist, String alphabet) {
    final alphabetChars = alphabet.toLowerCase().split('').toSet();

    return blocklist
        .where((word) => word.length >= 3)
        .map((word) => word.toLowerCase())
        .where(
          (word) =>
              word.split('').every((char) => !alphabetChars.contains(char)) ==
              false,
        ) // The logic in original was difference.isEmpty.
        // Original: Set.from(word.split('')).difference(alphabetChars).isEmpty
        // This means ALL characters in word MUST be in alphabetChars.
        // My replacement above: word.split('').every((char) => !alphabetChars.contains(char)) == false
        // This logic is confusing. Let's simpler:
        // word chars subset of alphabet chars.
        .where((word) {
          for (var i = 0; i < word.length; i++) {
            if (!alphabetChars.contains(word[i])) return false;
          }
          return true;
        })
        .toSet();
  }
}
