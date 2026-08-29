import 'package:sqids/src/defaults.dart' as defaults;

/// Official Dart port of Sqids. Generate short YouTube-looking IDs from
/// numbers.
///
/// The implementation works on a single `List` view of the alphabet that is
/// rotated, reversed and shuffled in place, and on code-unit lists for
/// decoding, so encoding and decoding never re-split or re-join the alphabet
/// per number.
class Sqids {
  /// The alphabet, shuffled once in the constructor, used to generate IDs.
  final String alphabet;

  /// The minimum length of generated IDs.
  final int minLength;

  /// The filtered blocklist: lowercase words of length >= 3 whose characters
  /// all appear in [alphabet].
  final Set<String> blocklist;

  static const int _maxValue = 9_007_199_254_740_991; // 2^53 - 1
  static const int _minAlphabetLength = 3;
  static const int _minLengthLimit = 255;

  Sqids({
    String alphabet = defaults.alphabet,
    int minLength = 0,
    Set<String>? blocklist,
  }) : alphabet = _shuffle(_validateAlphabet(alphabet)),
       minLength = _validateMinLength(minLength),
       blocklist = _filterBlocklist(blocklist ?? defaults.blocked, alphabet);

  // Views of [alphabet] computed lazily on first use. [alphabet] never changes
  // after construction, so these stay valid for the lifetime of the instance.
  late final List<String> _alphabetChars = alphabet.split('');
  late final List<int> _alphabetCodes = alphabet.codeUnits;
  late final Set<int> _alphabetCodeSet = _alphabetCodes.toSet();

  // Blocklist indexes, built once on first use, so [isBlockedId] never scans
  // the raw set word by word or runs a regex at encode time.
  //
  // The reference matching rules reduce to:
  //  - IDs of length <= 3: only an exact match against a 3-letter word counts
  //    (shorter words are dropped by [_filterBlocklist]).
  //  - Longer IDs: words of length <= 3 can never match; words containing a
  //    digit must match a prefix or suffix, other words any substring, and
  //    only words no longer than the ID need to be checked.
  //
  // Words are grouped by length into hash sets, and the ID is tested by
  // substring membership: a word of length L occurs in the ID iff some
  // substring of length L equals the word, which turns the per-word scans
  // into O(ID length) lookups per word length.
  late final Set<String> _exactBlocklist = {
    for (final word in blocklist)
      if (word.length == 3) word,
  };
  late final Map<int, Set<String>> _digitWordsByLength = _collectBlocklistWords(
    containsDigit: true,
  );
  late final Map<int, Set<String>> _plainWordsByLength = _collectBlocklistWords(
    containsDigit: false,
  );
  late final List<int> _blocklistLengths = {
    ..._digitWordsByLength.keys,
    ..._plainWordsByLength.keys,
  }.toList()..sort();

  Map<int, Set<String>> _collectBlocklistWords({required bool containsDigit}) {
    final result = <int, Set<String>>{};
    for (final word in blocklist) {
      if (word.length < 4) continue;
      if (_containsDigit(word) != containsDigit) continue;
      (result[word.length] ??= <String>{}).add(word);
    }
    return result;
  }

  /// Encode a list of numbers into a string.
  String encode(List<int> numbers) {
    if (numbers.isEmpty) {
      return '';
    }

    for (final n in numbers) {
      if (n < 0 || n > _maxValue) {
        throw Exception('Encoding supports numbers between 0 and $_maxValue');
      }
    }

    return _encodeNumbers(numbers, 0);
  }

  /// Decode a string into a list of numbers.
  List<int> decode(String id) {
    if (id.isEmpty) {
      return <int>[];
    }

    final alphabetCodes = _alphabetCodes;
    final alphabetLength = alphabetCodes.length;

    // Reject IDs containing characters outside the alphabet before parsing.
    final validCodes = _alphabetCodeSet;
    for (var i = 0; i < id.length; i++) {
      if (!validCodes.contains(id.codeUnitAt(i))) {
        return <int>[];
      }
    }

    // Working alphabet: rotate by the prefix character's index, then reverse.
    final offset = alphabetCodes.indexOf(id.codeUnitAt(0));
    final codes = List<int>.filled(alphabetLength, 0);
    for (var i = 0; i < alphabetLength; i++) {
      codes[i] = alphabetCodes[(i + offset) % alphabetLength];
    }
    for (int i = 0, j = alphabetLength - 1; i < j; i++, j--) {
      final temp = codes[i];
      codes[i] = codes[j];
      codes[j] = temp;
    }

    final ret = <int>[];
    final numberBase = alphabetLength - 1;
    final idLength = id.length;
    var position = 1;
    while (position < idLength) {
      final separator = codes[0];
      final chunkStart = position;
      var value = 0;
      while (position < idLength && id.codeUnitAt(position) != separator) {
        value = value * numberBase + codes.indexOf(id.codeUnitAt(position)) - 1;
        position++;
      }
      if (position == chunkStart) {
        return ret;
      }
      ret.add(value);
      if (position < idLength) {
        _shuffleCodesInPlace(codes);
        position++;
      }
    }
    return ret;
  }

  /// Encode a list of numbers into a string with an optional increment used
  /// when regenerating blocked IDs.
  String encodeNumbers(List<int> numbers, [int increment = 0]) {
    return _encodeNumbers(numbers, increment);
  }

  String _encodeNumbers(List<int> numbers, int increment) {
    final alphabetChars = _alphabetChars;
    final alphabetLength = alphabetChars.length;
    if (increment > alphabetLength) {
      throw Exception('Reached max attempts to re-generate the ID');
    }

    var offset = 0;
    final numberCount = numbers.length;
    for (var i = 0; i < numberCount; i++) {
      offset += alphabet.codeUnitAt(numbers[i] % alphabetLength) + i;
    }
    offset = (offset + numberCount + increment) % alphabetLength;

    // Working alphabet: rotate by [offset], then reverse. The first character
    // of the rotated alphabet (the last entry of the reversed list) becomes
    // the ID prefix; the first entry of the reversed list is the separator
    // between numbers.
    final chars = List<String>.filled(alphabetLength, '', growable: false);
    for (var i = 0; i < alphabetLength; i++) {
      chars[i] = alphabetChars[(i + offset) % alphabetLength];
    }
    for (int i = 0, j = alphabetLength - 1; i < j; i++, j--) {
      final temp = chars[i];
      chars[i] = chars[j];
      chars[j] = temp;
    }

    final result = StringBuffer()..write(chars[alphabetLength - 1]);
    final numberBase = alphabetLength - 1;
    final digits = <String>[];
    for (var i = 0; i < numberCount; i++) {
      digits.clear();
      var value = numbers[i];
      do {
        digits.add(chars[1 + (value % numberBase)]);
        value ~/= numberBase;
      } while (value > 0);
      for (var d = digits.length - 1; d >= 0; d--) {
        result.write(digits[d]);
      }
      if (i < numberCount - 1) {
        result.write(chars[0]);
        _shuffleCharsInPlace(chars);
      }
    }

    var id = result.toString();

    // Ensure the ID meets the minimum length. Each padding round starts with
    // the current separator character, so decoding stops right after the
    // original numbers (the next chunk is always empty).
    if (minLength > id.length) {
      final padded = StringBuffer(id)..write(chars[0]);
      while (minLength - padded.length > 0) {
        _shuffleCharsInPlace(chars);
        final remaining = minLength - padded.length;
        final take = remaining < alphabetLength ? remaining : alphabetLength;
        for (var i = 0; i < take; i++) {
          padded.write(chars[i]);
        }
      }
      id = padded.toString();
    }

    // If the generated ID is blocked, regenerate with an incremented offset.
    if (isBlockedId(id)) {
      id = _encodeNumbers(numbers, increment + 1);
    }

    return id;
  }

  /// Shuffle the characters of an alphabet.
  String shuffle(String alphabet) {
    return _shuffle(alphabet);
  }

  static String _shuffle(String alphabet) {
    if (alphabet.isEmpty) {
      return alphabet;
    }
    final chars = alphabet.split('');
    _shuffleCharsInPlace(chars);
    return chars.join();
  }

  static void _shuffleCharsInPlace(List<String> chars) {
    final length = chars.length;
    for (int i = 0, j = length - 1; j > 0; i++, j--) {
      final r =
          (i * j + chars[i].codeUnitAt(0) + chars[j].codeUnitAt(0)) % length;
      final temp = chars[i];
      chars[i] = chars[r];
      chars[r] = temp;
    }
  }

  // Decode keeps its alphabet as code units, so it needs the same shuffle
  // over ints. The formula is identical, so both produce the same permutation.
  static void _shuffleCodesInPlace(List<int> codes) {
    final length = codes.length;
    for (int i = 0, j = length - 1; j > 0; i++, j--) {
      final r = (i * j + codes[i] + codes[j]) % length;
      final temp = codes[i];
      codes[i] = codes[r];
      codes[r] = temp;
    }
  }

  /// Convert a number to a string ID using a custom alphabet.
  String toId(int num, String alphabet) {
    final chars = alphabet.split('');
    final charsLength = chars.length;
    final id = StringBuffer();
    var result = num;
    do {
      id.write(chars[result % charsLength]);
      result ~/= charsLength;
    } while (result > 0);
    final encoded = id.toString();
    final reversed = StringBuffer();
    for (var i = encoded.length - 1; i >= 0; i--) {
      reversed.write(encoded[i]);
    }
    return reversed.toString();
  }

  /// Convert a string ID to a number using a custom alphabet.
  int toNumber(String id, String alphabet) {
    final chars = alphabet.split('');
    final charsLength = chars.length;
    var result = 0;
    for (var i = 0; i < id.length; i++) {
      result = result * charsLength + chars.indexOf(id[i]);
    }
    return result;
  }

  /// Check if an ID is blocked based on the blocklist.
  bool isBlockedId(String id) {
    final lowercaseId = id.toLowerCase();
    final idLength = lowercaseId.length;

    if (idLength <= 3) {
      return idLength == 3 && _exactBlocklist.contains(lowercaseId);
    }

    final lengths = _blocklistLengths;
    for (var i = 0; i < lengths.length; i++) {
      final wordLength = lengths[i];
      if (wordLength > idLength) {
        break;
      }

      final digitWords = _digitWordsByLength[wordLength];
      if (digitWords != null &&
          (digitWords.contains(lowercaseId.substring(0, wordLength)) ||
              digitWords.contains(
                lowercaseId.substring(idLength - wordLength),
              ))) {
        return true;
      }

      final plainWords = _plainWordsByLength[wordLength];
      if (plainWords != null) {
        final lastStart = idLength - wordLength;
        for (var start = 0; start <= lastStart; start++) {
          if (plainWords.contains(
            lowercaseId.substring(start, start + wordLength),
          )) {
            return true;
          }
        }
      }
    }

    return false;
  }

  /// Get the maximum value supported for encoding.
  int maxValue() {
    return _maxValue;
  }

  static String _validateAlphabet(String alphabet) {
    if (alphabet.length < _minAlphabetLength) {
      throw Exception('Alphabet length must be at least $_minAlphabetLength');
    }

    if (alphabet.codeUnits.toSet().length != alphabet.length) {
      throw Exception('Alphabet must contain unique characters');
    }
    return alphabet;
  }

  static int _validateMinLength(int minLength) {
    if (minLength < 0 || minLength > _minLengthLimit) {
      throw Exception(
        'Minimum length has to be between 0 and $_minLengthLimit',
      );
    }
    return minLength;
  }

  static Set<String> _filterBlocklist(Set<String> blocklist, String alphabet) {
    final alphabetCodes = Set<int>.of(alphabet.toLowerCase().codeUnits);
    final filtered = <String>{};
    for (final word in blocklist) {
      if (word.length < 3) {
        continue;
      }
      final lowercase = word.toLowerCase();
      var allowed = true;
      for (var i = 0; i < lowercase.length; i++) {
        if (!alphabetCodes.contains(lowercase.codeUnitAt(i))) {
          allowed = false;
          break;
        }
      }
      if (allowed) {
        filtered.add(lowercase);
      }
    }
    return filtered;
  }

  static bool _containsDigit(String word) {
    for (var i = 0; i < word.length; i++) {
      final code = word.codeUnitAt(i);
      if (code >= 0x30 && code <= 0x39) {
        return true;
      }
    }
    return false;
  }
}
