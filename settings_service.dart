import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Huhifadhi secrets kwa usalama kwenye simu (Android Keystore / iOS Keychain)
/// badala ya kuziandika moja kwa moja kwenye msimbo (kama .streamlit/secrets.toml).
class SettingsService {
  static const _storage = FlutterSecureStorage();

  static const kGithubToken = 'GITHUB_TOKEN';
  static const kGithubRepo = 'GITHUB_REPO';
  static const kGithubBranch = 'GITHUB_BRANCH';
  static const kMembersPath = 'GITHUB_MEMBERS_PATH';
  static const kLedgerPath = 'GITHUB_LEDGER_PATH';
  static const kUsersPath = 'GITHUB_USERS_PATH';
  static const kSessionSecret = 'SESSION_SECRET';
  static const kSessionUser = 'SESSION_USER';
  static const kSessionToken = 'SESSION_TOKEN';
  static const kResendApiKey = 'RESEND_API_KEY';
  static const kResendFromEmail = 'RESEND_FROM_EMAIL';

  static Future<void> setValue(String key, String value) =>
      _storage.write(key: key, value: value);

  static Future<String> getValue(String key, {String fallback = ''}) async {
    return await _storage.read(key: key) ?? fallback;
  }

  static Future<void> clearSession() async {
    await _storage.delete(key: kSessionUser);
    await _storage.delete(key: kSessionToken);
  }

  /// Pakia mipangilio yote muhimu ya GitHub mara moja.
  static Future<Map<String, String>> loadGithubConfig() async {
    return {
      'token': await getValue(kGithubToken),
      'repo': await getValue(kGithubRepo),
      'branch': await getValue(kGithubBranch, fallback: 'main'),
      'membersPath': await getValue(kMembersPath, fallback: 'data/members.csv'),
      'ledgerPath': await getValue(kLedgerPath, fallback: 'data/ledger.csv'),
      'usersPath': await getValue(kUsersPath, fallback: 'data/users.csv'),
      'sessionSecret': await getValue(kSessionSecret,
          fallback: 'eliamini-family-mkoba-session-secret-2026'),
      'resendApiKey': await getValue(kResendApiKey),
      'resendFromEmail': await getValue(kResendFromEmail,
          fallback: 'ELIAMINI FAMILY <onboarding@resend.dev>'),
    };
  }
}
