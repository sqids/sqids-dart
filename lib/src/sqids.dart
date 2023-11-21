// ignore_for_file: prefer_initializing_formals

import 'dart:math';

import 'package:sqids/src/blocked.dart';

class Sqids {
  // Properties
  late String alphabet;
  late int minLength;
  late Set<String> blocklist;

  // Constructor
  Sqids({
    String alphabet =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789',
    int minLength = 0,
    Set<String>? blocklist,
  }) {
    this.alphabet = alphabet;
    this.minLength = minLength;
    this.blocklist = blocklist ?? blocked.toSet();

    // Validate alphabet
    if (this.alphabet.isEmpty) {
      throw Exception('Alphabet cannot contain multibyte characters');
    }
    const minAlphabetLength = 3;
    if (this.alphabet.length < minAlphabetLength) {
      throw Exception('Alphabet length must be at least $minAlphabetLength');
    }
    if (Set.of(this.alphabet.split('')).length != this.alphabet.length) {
      throw Exception('Alphabet must contain unique characters');
    }

    // Validate minLength
    const minLengthLimit = 255;
    if (this.minLength < 0 || this.minLength > minLengthLimit) {
      throw Exception('Minimum length has to be between 0 and $minLengthLimit');
    }

    // Filter blocklist based on the provided criteria
    final filteredBlocklist = <String>{};
    final alphabetChars = this.alphabet.toLowerCase().split('');
    for (final word in this.blocklist) {
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

    // Shuffle the alphabet
    this.alphabet = shuffle(this.alphabet);
    this.minLength = minLength;
    this.blocklist = filteredBlocklist;
  }

  // Encode a list of numbers into a string
  String encode(List<int> numbers) {
    if (numbers.isEmpty) {
      return '';
    }

    // Validate that all numbers are in the valid range
    final inRangeNumbers =
        numbers.where((n) => n >= 0 && n <= maxValue()).toList();
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

    // Calculate the offset based on the numbers
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

    // Generate the encoded ID
    for (int i = 0; i < numbers.length; i++) {
      int num = numbers[i];

      ret.add(toId(num, alphabet.substring(1)));
      if (i < numbers.length - 1) {
        ret.add(alphabet.substring(0, 1));
        alphabet = shuffle(alphabet);
      }
    }

    String id = ret.join('');

    // Ensure the ID meets the minimum length
    if (minLength > id.length) {
      id += alphabet.substring(0, 1);

      for (int i = minLength - id.length; i > 0; i -= alphabet.length) {
        alphabet = shuffle(alphabet);
        id +=
            alphabet.substring(0, (i < alphabet.length) ? i : alphabet.length);
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
    final chars = alphabet.split('');

    for (int i = 0, j = chars.length - 1; j > 0; i++, j--) {
      final r = (i * j + chars[i].codeUnitAt(0) + chars[j].codeUnitAt(0)) %
          chars.length;
      final temp = chars[i];
      chars[i] = chars[r];
      chars[r] = temp;
    }

    return chars.join('');
  }

  // Convert a number to a string ID using a custom alphabet
  String toId(int num, String alphabet) {
    final id = <String>[];
    final chars = alphabet.split('');

    int result = num;

    do {
      id.insert(0, chars[result % chars.length]);
      result = (result / chars.length).floor();
    } while (result > 0);

    return id.join('');
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

  // Get the maximum value supported for encoding
  int maxValue() {
    return (pow(2, 53) - 1).toInt();
  }
}
