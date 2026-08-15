import 'dart:convert';
import 'package:http/http.dart' as http;

/// Sawa na github_fetch_csv()/github_push_csv() za Python - inatumia GitHub
/// Contents API (https://api.github.com/repos/{repo}/contents/{path}).
class GithubResult<T> {
  final bool ok;
  final String message;
  final T? data;
  GithubResult(this.ok, this.message, [this.data]);
}

class GithubService {
  final String token;
  final String repo; // mfano: "jina/jina-la-repo"
  final String branch;

  GithubService({required this.token, required this.repo, this.branch = 'main'});

  Map<String, String> get _headers => {
        'Authorization': 'token $token',
        'Accept': 'application/vnd.github+json',
      };

  Uri _contentsUri(String path) =>
      Uri.parse('https://api.github.com/repos/$repo/contents/$path');

  /// Soma faili la CSV. Inarudisha null endapo halijapatikana (404) au tatizo.
  Future<GithubResult<String>> fetchCsv(String path) async {
    if (token.isEmpty || repo.isEmpty) {
      return GithubResult(false, 'Hakuna GITHUB_TOKEN au GITHUB_REPO.');
    }
    try {
      final resp = await http
          .get(_contentsUri(path).replace(queryParameters: {'ref': branch}), headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode == 404) {
        return GithubResult(true, 'Faili halijapatikana bado (jipya).', '');
      }
      if (resp.statusCode != 200) {
        return GithubResult(false, 'Imeshindikana kusoma $path (status ${resp.statusCode}).');
      }
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final contentB64 = (json['content'] as String).replaceAll('\n', '');
      final bytes = base64.decode(contentB64);
      final text = utf8.decode(bytes, allowMalformed: true);
      return GithubResult(true, 'OK', text);
    } catch (e) {
      return GithubResult(false, 'Imeshindikana kuwasiliana na GitHub: $e');
    }
  }

  /// Andika/sasisha faili la CSV (huchukua sha ya sasa moja kwa moja).
  Future<GithubResult<void>> pushCsv({
    required String path,
    required String csvContent,
    required String commitMessage,
  }) async {
    if (token.isEmpty || repo.isEmpty) {
      return GithubResult(false, 'Hakuna GITHUB_TOKEN au GITHUB_REPO.');
    }
    String? sha;
    try {
      final getResp = await http
          .get(_contentsUri(path).replace(queryParameters: {'ref': branch}), headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (getResp.statusCode == 200) {
        sha = (jsonDecode(getResp.body) as Map<String, dynamic>)['sha'] as String?;
      } else if (getResp.statusCode != 404) {
        return GithubResult(false, 'Imeshindikana kusoma faili la sasa (status ${getResp.statusCode}).');
      }
    } catch (e) {
      return GithubResult(false, 'Imeshindikana kuwasiliana na GitHub: $e');
    }

    final contentB64 = base64.encode(utf8.encode(csvContent));
    final payload = {
      'message': commitMessage,
      'content': contentB64,
      'branch': branch,
      if (sha != null) 'sha': sha,
    };

    try {
      final putResp = await http
          .put(_contentsUri(path), headers: {..._headers, 'Content-Type': 'application/json'}, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 20));
      if (putResp.statusCode == 200 || putResp.statusCode == 201) {
        return GithubResult(true, '✅ $path imepandishwa GitHub kikamilifu.');
      }
      return GithubResult(false,
          'GitHub imekataa ombi (status ${putResp.statusCode}): ${putResp.body.substring(0, putResp.body.length > 300 ? 300 : putResp.body.length)}');
    } catch (e) {
      return GithubResult(false, 'Imeshindikana kutuma kwa GitHub: $e');
    }
  }

  /// Pima muunganiko (token sahihi, repo inapatikana, ruhusa ya push).
  Future<GithubResult<void>> testConnection() async {
    if (token.isEmpty) return GithubResult(false, 'Hakuna GITHUB_TOKEN.');
    if (repo.isEmpty) return GithubResult(false, 'Hakuna GITHUB_REPO.');
    try {
      final who = await http
          .get(Uri.parse('https://api.github.com/user'), headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (who.statusCode == 401) {
        return GithubResult(false, '❌ Token si sahihi au imekwisha muda (401).');
      }
      if (who.statusCode != 200) {
        return GithubResult(false, '❌ Tatizo la token (status ${who.statusCode}).');
      }
      final repoResp = await http
          .get(Uri.parse('https://api.github.com/repos/$repo'), headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (repoResp.statusCode == 404) {
        return GithubResult(false, "❌ Repo '$repo' haikupatikana.");
      }
      if (repoResp.statusCode != 200) {
        return GithubResult(false, '❌ Tatizo la kufikia repo (status ${repoResp.statusCode}).');
      }
      final info = jsonDecode(repoResp.body) as Map<String, dynamic>;
      final perms = info['permissions'] as Map<String, dynamic>? ?? {};
      if (perms['push'] != true) {
        return GithubResult(false, '❌ Token/akaunti hii HAINA ruhusa ya push kwenye repo hii.');
      }
      var note = '';
      if (info['private'] == false) {
        note = ' ⚠️ TAHADHARI: Repo hii SI ya siri (public).';
      }
      return GithubResult(true, "✅ Muunganiko mzuri - token na repo '$repo' vinafanya kazi.$note");
    } catch (e) {
      return GithubResult(false, 'Imeshindikana kuwasiliana na GitHub: $e');
    }
  }
}
