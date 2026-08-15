import '../models/member.dart';
import '../models/ledger_entry.dart';
import '../models/app_user.dart';
import 'csv_service.dart';
import 'github_service.dart';

/// Safu moja inayounganisha GithubService (usafirishaji) na CsvService
/// (uumbizaji), na kubadilisha kuwa/kutoka List<Member/LedgerEntry/AppUser>.
class DataRepository {
  final GithubService github;
  final String membersPath;
  final String ledgerPath;
  final String usersPath;

  DataRepository({
    required this.github,
    required this.membersPath,
    required this.ledgerPath,
    required this.usersPath,
  });

  // ---------------- MEMBERS ----------------
  Future<GithubResult<List<Member>>> fetchMembers() async {
    final res = await github.fetchCsv(membersPath);
    if (!res.ok) return GithubResult(false, res.message);
    final rows = CsvService.parse(res.data ?? '');
    return GithubResult(true, 'OK', rows.map(Member.fromCsvRow).toList());
  }

  Future<GithubResult<void>> saveMembers(List<Member> members, String commitMessage) async {
    final csvText =
        CsvService.build(Member.csvColumns, members.map((m) => m.toCsvRow()).toList());
    return github.pushCsv(path: membersPath, csvContent: csvText, commitMessage: commitMessage);
  }

  // ---------------- LEDGER ----------------
  Future<GithubResult<List<LedgerEntry>>> fetchLedger() async {
    final res = await github.fetchCsv(ledgerPath);
    if (!res.ok) return GithubResult(false, res.message);
    final rows = CsvService.parse(res.data ?? '');
    return GithubResult(true, 'OK', rows.map(LedgerEntry.fromCsvRow).toList());
  }

  Future<GithubResult<void>> saveLedger(List<LedgerEntry> ledger, String commitMessage) async {
    final csvText = CsvService.build(
        LedgerEntry.csvColumns, ledger.map((l) => l.toCsvRow()).toList());
    return github.pushCsv(path: ledgerPath, csvContent: csvText, commitMessage: commitMessage);
  }

  /// Sawa na ensure_ledger_has_all_members() - ongeza kwenye Ledger
  /// wanachama wa Backend ambao bado hawapo Ledger.
  static List<LedgerEntry> ensureLedgerHasAllMembers(
      List<LedgerEntry> ledger, List<Member> members) {
    final result = List<LedgerEntry>.from(ledger);
    final existingKeys = <String>{};
    for (final l in result) {
      if (l.jinaLaKawaida.trim().isNotEmpty) {
        existingKeys.add(l.jinaLaKawaida.trim().toUpperCase());
      }
      if (l.jinaLaUsajili.trim().isNotEmpty) {
        existingKeys.add(l.jinaLaUsajili.trim().toUpperCase());
      }
    }
    for (final m in members) {
      final jk = m.jinaLaKawaida.trim().toUpperCase();
      final ju = m.jinaLaUsajili.trim().toUpperCase();
      if ((jk.isNotEmpty && existingKeys.contains(jk)) ||
          (ju.isNotEmpty && existingKeys.contains(ju))) {
        continue;
      }
      if (jk.isEmpty && ju.isEmpty) continue;
      result.add(LedgerEntry(
        jinaLaKawaida: m.jinaLaKawaida,
        jinaLaUsajili: m.jinaLaUsajili,
        namba: m.namba,
        jinsia: m.jinsia.isEmpty ? 'ME' : m.jinsia,
        kianzioHali: 'INAHITAJIKA',
        mchangoJumla: 0.0,
      ));
      if (jk.isNotEmpty) existingKeys.add(jk);
      if (ju.isNotEmpty) existingKeys.add(ju);
    }
    return result;
  }

  // ---------------- USERS ----------------
  Future<GithubResult<List<AppUser>>> fetchUsers() async {
    final res = await github.fetchCsv(usersPath);
    if (!res.ok) return GithubResult(false, res.message);
    final rows = CsvService.parse(res.data ?? '');
    return GithubResult(true, 'OK', rows.map(AppUser.fromCsvRow).toList());
  }

  Future<GithubResult<void>> saveUsers(List<AppUser> users, String commitMessage) async {
    final csvText =
        CsvService.build(AppUser.csvColumns, users.map((u) => u.toCsvRow()).toList());
    return github.pushCsv(path: usersPath, csvContent: csvText, commitMessage: commitMessage);
  }
}
