/// Inalingana na safu za data/ledger.csv - "chanzo cha ukweli" cha deni.
class LedgerEntry {
  String jinaLaKawaida;
  String jinaLaUsajili;
  String namba;
  String jinsia; // ME au KE
  String kianzioHali; // "INAHITAJIKA" au "HAHUSIKI"
  double mchangoJumla; // TZS, cumulative

  LedgerEntry({
    this.jinaLaKawaida = '',
    this.jinaLaUsajili = '',
    this.namba = '',
    this.jinsia = 'ME',
    this.kianzioHali = 'INAHITAJIKA',
    this.mchangoJumla = 0.0,
  });

  static const List<String> csvColumns = [
    'Jina la Kawaida',
    'Jina la Usajili (M-Koba)',
    'Namba ya Simu',
    'Jinsia',
    'Kianzio Hali',
    'Mchango Jumla (TZS)',
  ];

  static double parseMoney(String? val) {
    if (val == null) return 0.0;
    var text = val.replaceAll(',', '').replaceAll('TZS', '').replaceAll('/=', '').trim();
    if (text.isEmpty ||
        ['-', 'HAHUSIKI', 'HAJALIPA', 'NAN'].contains(text.toUpperCase())) {
      return 0.0;
    }
    final match = RegExp(r'[\d.]+').firstMatch(text);
    if (match == null) return 0.0;
    return double.tryParse(match.group(0)!) ?? 0.0;
  }

  factory LedgerEntry.fromCsvRow(Map<String, String> row) {
    return LedgerEntry(
      jinaLaKawaida: row['Jina la Kawaida'] ?? '',
      jinaLaUsajili: row['Jina la Usajili (M-Koba)'] ?? '',
      namba: row['Namba ya Simu'] ?? '',
      jinsia: (row['Jinsia'] ?? '').isEmpty ? 'ME' : row['Jinsia']!,
      kianzioHali: (row['Kianzio Hali'] ?? '').isEmpty
          ? 'INAHITAJIKA'
          : row['Kianzio Hali']!,
      mchangoJumla: parseMoney(row['Mchango Jumla (TZS)']),
    );
  }

  List<String> toCsvRow() => [
        jinaLaKawaida,
        jinaLaUsajili,
        namba,
        jinsia,
        kianzioHali,
        mchangoJumla.toStringAsFixed(0),
      ];
}
