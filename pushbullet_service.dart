import 'dart:convert';
import 'package:http/http.dart' as http;
import 'text_utils.dart';

class PushbulletDevice {
  final String iden;
  final String nickname;
  final bool hasSms;
  PushbulletDevice({required this.iden, required this.nickname, required this.hasSms});
}

class SmsFailure {
  final String jina;
  final String namba;
  final String tatizo;
  SmsFailure(this.jina, this.namba, this.tatizo);
}

class SmsSendItem {
  final String phone9;
  final String message;
  final String jina;
  SmsSendItem(this.phone9, this.message, this.jina);
}

/// Sawa na get_pushbullet_devices(), test_pushbullet_connection(), send_sms(),
/// send_sms_bulk() za Python.
class PushbulletService {
  static const _textsUrl = 'https://api.pushbullet.com/v2/texts';
  static const _devicesUrl = 'https://api.pushbullet.com/v2/devices';
  static const _meUrl = 'https://api.pushbullet.com/v2/users/me';
  static const _timeout = Duration(seconds: 8);

  static Future<List<PushbulletDevice>> getDevices(String token) async {
    if (token.isEmpty) return [];
    try {
      final resp = await http
          .get(Uri.parse(_devicesUrl), headers: {'Access-Token': token})
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return [];
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final devices = (json['devices'] as List<dynamic>? ?? []);
      return devices
          .where((d) => (d['active'] ?? true) == true)
          .map((d) => PushbulletDevice(
                iden: d['iden'] as String,
                nickname: (d['nickname'] as String?) ?? d['iden'] as String,
                hasSms: (d['has_sms'] ?? false) == true,
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<(bool ok, String info)> testConnection(String token) async {
    if (token.isEmpty) {
      return (false, 'Hujaweka Pushbullet Token yako bado.');
    }
    try {
      final resp = await http
          .get(Uri.parse(_meUrl), headers: {'Access-Token': token})
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 401) {
        return (false, '❌ Token si sahihi au imefutwa (status 401).');
      }
      if (resp.statusCode != 200) {
        return (false, '❌ Tatizo la kuunganisha na Pushbullet (status ${resp.statusCode}).');
      }
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final email = data['email'] ?? 'haijulikani';
      final devices = await getDevices(token);
      final smsDevices = devices.where((d) => d.hasSms).toList();
      if (smsDevices.isEmpty) {
        return (
          true,
          '✅ Token ni sahihi - umeungana kama $email. ⚠️ LAKINI hakuna simu yenye SMS iliyounganishwa.'
        );
      }
      final names = smsDevices.map((d) => d.nickname).join(', ');
      return (true, '✅ Muunganiko mzuri - umeungana kama $email. Simu zenye SMS: $names.');
    } catch (e) {
      return (false, 'Imeshindikana kuwasiliana na Pushbullet: $e');
    }
  }

  static Future<(bool ok, String info)> sendSms(
    String phone9,
    String message,
    String deviceIden,
    String token,
  ) async {
    if (token.isEmpty) return (false, 'Huna Pushbullet Token iliyowekwa.');
    if (deviceIden.isEmpty) return (false, 'Hakuna simu (device) iliyochaguliwa.');
    final address = TextUtils.formatPhoneForSms(phone9);
    if (address.isEmpty) return (false, 'Namba ya simu si sahihi/haipo.');

    try {
      final resp = await http
          .post(
            Uri.parse(_textsUrl),
            headers: {'Access-Token': token, 'Content-Type': 'application/json'},
            body: jsonEncode({
              'data': {
                'target_device_iden': deviceIden,
                'addresses': [address],
                'message': message,
              }
            }),
          )
          .timeout(_timeout);
      final ok = resp.statusCode == 200 || resp.statusCode == 201;
      return (ok, ok ? 'OK' : 'status ${resp.statusCode}');
    } catch (e) {
      return (false, e.toString());
    }
  }

  /// Sawa na send_sms_bulk() - kutuma SMS "sambamba" kwa vikundi (batches)
  /// vya ukubwa maxWorkers, kwa kutumia Future.wait (concurrency ya kweli
  /// kwa maombi ya mtandao, sawa na dhana ya ThreadPoolExecutor).
  static Future<(int successCount, List<SmsFailure> failures)> sendSmsBulk(
    List<SmsSendItem> items,
    String deviceIden,
    String token, {
    int maxWorkers = 25,
    void Function(double progress)? onProgress,
  }) async {
    if (items.isEmpty) return (0, <SmsFailure>[]);
    var successCount = 0;
    final failures = <SmsFailure>[];
    var completed = 0;

    for (var i = 0; i < items.length; i += maxWorkers) {
      final batch = items.sublist(i, (i + maxWorkers).clamp(0, items.length));
      final results = await Future.wait(batch.map((item) async {
        final (ok, info) = await sendSms(item.phone9, item.message, deviceIden, token);
        completed++;
        onProgress?.call(completed / items.length);
        return (ok, info, item);
      }));
      for (final (ok, info, item) in results) {
        if (ok) {
          successCount++;
        } else {
          failures.add(SmsFailure(
            item.jina.isNotEmpty ? item.jina : TextUtils.formatPhoneForSms(item.phone9),
            TextUtils.formatPhoneForSms(item.phone9),
            info,
          ));
        }
      }
    }
    return (successCount, failures);
  }
}
