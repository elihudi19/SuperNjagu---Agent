import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart' as pc;

/// Sawa na hash_password()/verify_password() na
/// generate_session_token()/verify_session_token() za Python (hmac+pbkdf2).
class AuthService {
  static const int _iterations = 100000;
  static const int _keyLength = 32; // bytes (sha256)

  /// Tengeneza salt mpya (herufi za hex, sawa na secrets.token_hex(16))
  static String _randomHexSalt([int bytes = 16]) {
    final rnd = Random.secure();
    final values = List<int>.generate(bytes, (_) => rnd.nextInt(256));
    return values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// PBKDF2-HMAC-SHA256, inarudisha hex string, sawa na hashlib.pbkdf2_hmac
  static String _pbkdf2Hex(String password, String saltHex) {
    final salt = Uint8List.fromList(
      List.generate(saltHex.length ~/ 2,
          (i) => int.parse(saltHex.substring(i * 2, i * 2 + 2), radix: 16)),
    );
    final derivator = pc.PBKDF2KeyDerivator(pc.HMac(pc.SHA256Digest(), 64))
      ..init(pc.Pbkdf2Parameters(salt, _iterations, _keyLength));
    final key = derivator.process(Uint8List.fromList(utf8.encode(password)));
    return key.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Inarudisha (hash, salt) - tumia salt uliyopewa (ukitaka kuthibitisha)
  /// au acha null ili itengeneze salt mpya (usajili mpya).
  static (String hash, String salt) hashPassword(String password, {String? salt}) {
    final s = salt ?? _randomHexSalt();
    final h = _pbkdf2Hex(password, s);
    return (h, s);
  }

  static bool verifyPassword(String password, String storedHash, String salt) {
    if (storedHash.isEmpty || salt.isEmpty) return false;
    final (check, _) = hashPassword(password, salt: salt);
    return _constantTimeEquals(check, storedHash);
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }

  // -------------------------------------------------------------------
  // Session token (remember-me) - HMAC-SHA256, sawa na generate/verify
  // _session_token() za Python. Hutumika kama SESSION_SECRET moja ya app.
  // -------------------------------------------------------------------
  static const int sessionTokenDaysValid = 30;

  static String generateSessionToken(String name, String sessionSecret) {
    final expiry =
        (DateTime.now().millisecondsSinceEpoch ~/ 1000) + sessionTokenDaysValid * 86400;
    final msg = '$name:$expiry';
    final sig = Hmac(sha256, utf8.encode(sessionSecret)).convert(utf8.encode(msg)).toString();
    final raw = '$expiry:$sig';
    return base64Url.encode(utf8.encode(raw));
  }

  static bool verifySessionToken(String name, String token, String sessionSecret) {
    if (name.isEmpty || token.isEmpty) return false;
    try {
      final raw = utf8.decode(base64Url.decode(token));
      final parts = raw.split(':');
      final expiry = int.parse(parts[0]);
      final sig = parts.sublist(1).join(':');
      if (DateTime.now().millisecondsSinceEpoch ~/ 1000 > expiry) return false;
      final msg = '$name:$expiry';
      final expectedSig =
          Hmac(sha256, utf8.encode(sessionSecret)).convert(utf8.encode(msg)).toString();
      return _constantTimeEquals(sig, expectedSig);
    } catch (_) {
      return false;
    }
  }

  /// Nambari ya kurejesha password (kama OTP), sawa na secrets.randbelow(900000)+100000
  static String randomSixDigitCode() {
    final rnd = Random.secure();
    return (100000 + rnd.nextInt(900000)).toString();
  }
}
