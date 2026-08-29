## 0.0.3
* Require Dart ^3.13.0.
* Performance: encode/decode now work on a single in-place alphabet list and
  code-unit views of the alphabet instead of re-splitting and re-joining
  strings per number (~5-19x faster encode, ~4.5x faster decode on the Dart VM).
* Performance: blocklist words are pre-indexed by length into hash sets at
  first use; `isBlockedId` now matches by substring membership instead of
  scanning every word with a regex per call (up to ~56x faster on a miss).
* Performance: `maxValue` is a constant and number range validation no longer
  allocates an intermediate list.
* Add deterministic round-trip regression tests and `benchmark/benchmark.dart`.

## 0.0.1
* Initial Open Source release