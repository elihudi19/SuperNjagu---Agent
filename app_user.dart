/// Inalingana na safu za data/users.csv - akaunti za viongozi watatu.
class AppUser {
  String jina; // ELIHUDI / YUSUPH / FIDE
  String email;
  String passwordHash;
  String salt;
  String pushbulletToken;
  String pushbulletDevice;

  AppUser({
    this.jina = '',
    this.email = '',
    this.passwordHash = '',
    this.salt = '',
    this.pushbulletToken = '',
    this.pushbulletDevice = '',
  });

  static const List<String> csvColumns = [
    'Jina',
    'Email',
    'PasswordHash',
    'Salt',
    'PushbulletToken',
    'PushbulletDevice',
  ];

  factory AppUser.fromCsvRow(Map<String, String> row) {
    return AppUser(
      jina: row['Jina'] ?? '',
      email: row['Email'] ?? '',
      passwordHash: row['PasswordHash'] ?? '',
      salt: row['Salt'] ?? '',
      pushbulletToken: row['PushbulletToken'] ?? '',
      pushbulletDevice: row['PushbulletDevice'] ?? '',
    );
  }

  List<String> toCsvRow() =>
      [jina, email, passwordHash, salt, pushbulletToken, pushbulletDevice];
}

/// Watu pekee wanaoruhusiwa kujisajili/kuingia - sawa na AUTHORIZED_NAMES.
const List<String> kAuthorizedNames = ['ELIHUDI', 'YUSUPH', 'FIDE'];
