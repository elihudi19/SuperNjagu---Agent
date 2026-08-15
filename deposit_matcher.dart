import '../models/ledger_entry.dart';
import 'pdf_parser_service.dart';
import 'text_utils.dart';

class MatchResult {
  /// index kwenye ledger -> jumla ya deposit mpya iliyooanishwa
  final Map<int, double> depositAmounts;
  final List<Deposit> unmatched;
  MatchResult(this.depositAmounts, this.unmatched);
}

/// Sawa na aggregate_deposits_by_member() ikitumika na use_name_fallback=False
/// (Tab 1 ya Python inatumia NAMBA YA SIMU PEKEE kuoanisha) - jina peke yake
/// halitoshi, ili kuepuka makosa ya kuchanganya wanachama wenye majina
/// yanayofanana.
class DepositMatcher {
  static MatchResult matchByPhoneOnly(List<Deposit> deposits, List<LedgerEntry> ledger) {
    final amounts = <int, double>{};
    final unmatched = <Deposit>[];

    final phoneIndex = <String, int>{};
    for (var i = 0; i < ledger.length; i++) {
      final p = TextUtils.cleanPhone(ledger[i].namba);
      if (p.isNotEmpty && !phoneIndex.containsKey(p)) {
        phoneIndex[p] = i;
      }
    }

    for (final dep in deposits) {
      if (dep.phone.isNotEmpty && phoneIndex.containsKey(dep.phone)) {
        final idx = phoneIndex[dep.phone]!;
        amounts[idx] = (amounts[idx] ?? 0.0) + dep.amount;
      } else {
        unmatched.add(dep);
      }
    }

    return MatchResult(amounts, unmatched);
  }
}
