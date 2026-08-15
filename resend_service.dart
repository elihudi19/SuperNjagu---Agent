import 'dart:convert';
import 'package:http/http.dart' as http;

/// Sawa na send_email_code() ya Python, ikitumia Resend (https://resend.com).
class ResendService {
  static Future<(bool ok, String info)> sendEmailCode({
    required String apiKey,
    required String fromEmail,
    required String toEmail,
    required String code,
  }) async {
    if (apiKey.isEmpty) {
      return (false, 'Hakuna RESEND_API_KEY kwenye Mipangilio - muulize admin aweke.');
    }
    try {
      final resp = await http
          .post(
            Uri.parse('https://api.resend.com/emails'),
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'from': fromEmail,
              'to': [toEmail],
              'subject': 'ELIAMINI FAMILY - Nambari ya Kurejesha Password',
              'text': 'Ndugu,\n\nNambari yako ya kurejesha password ya Mfumo wa M-Koba '
                  '(ELIAMINI FAMILY) ni: $code\n\nNambari hii itatumika kwa dakika 10 tu. '
                  'Usimpe mtu yeyote nambari hii.',
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        return (true, '✅ Barua pepe ya nambari ya kurejesha imetumwa (kupitia Resend).');
      }
      final body = resp.body.length > 300 ? resp.body.substring(0, 300) : resp.body;
      return (false, 'Resend imekataa ombi (status ${resp.statusCode}): $body');
    } catch (e) {
      return (false, 'Imeshindikana kutuma barua pepe kupitia Resend: $e');
    }
  }
}
