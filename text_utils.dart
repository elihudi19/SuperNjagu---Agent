/// Sawa na clean_phone(), norm_name(), format_phone_for_sms(),
/// name_similarity() za Python.
class TextUtils {
  static String cleanPhone(String? val) {
    if (val == null) return '';
    final digits = val.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 9 ? digits.substring(digits.length - 9) : '';
  }

  static String normName(String? val) {
    if (val == null) return '';
    return val.trim().replaceAll(RegExp(r'\s+'), ' ').toUpperCase();
  }

  static String formatPhoneForSms(String phone9) {
    if (phone9.isEmpty) return '';
    final digits = phone9.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('255')) return '+$digits';
    if (digits.length >= 9) return '+255${digits.substring(digits.length - 9)}';
    return '';
  }

  /// Ulinganifu wa maneno (0.0 - 1.0), sawa na SequenceMatcher.ratio()
  /// (Python difflib) - tunatumia Levenshtein-based ratio inayokaribiana.
  static double nameSimilarity(String a, String b) {
    final sa = normName(a);
    final sb = normName(b);
    if (sa.isEmpty && sb.isEmpty) return 1.0;
    if (sa.isEmpty || sb.isEmpty) return 0.0;
    final matches = _matchingBlocksLength(sa, sb);
    return (2.0 * matches) / (sa.length + sb.length);
  }

  /// Idadi ya herufi zinazolingana kwa mtindo wa longest-common-subsequence
  /// (inatosha kwa ulinganifu wa majina, si sahihi 100% kama difflib lakini
  /// inakaribiana vya kutosha kwa matumizi haya).
  static int _matchingBlocksLength(String a, String b) {
    final dp = List.generate(a.length + 1, (_) => List<int>.filled(b.length + 1, 0));
    for (var i = 1; i <= a.length; i++) {
      for (var j = 1; j <= b.length; j++) {
        if (a[i - 1] == b[j - 1]) {
          dp[i][j] = dp[i - 1][j - 1] + 1;
        } else {
          dp[i][j] = dp[i - 1][j] > dp[i][j - 1] ? dp[i - 1][j] : dp[i][j - 1];
        }
      }
    }
    return dp[a.length][b.length];
  }
}
