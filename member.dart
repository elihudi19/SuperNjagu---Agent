/// Inalingana na safu za data/members.csv kwenye app ya Streamlit.
class Member {
  String na;
  String jinaLaKawaida; // "Jina la Kawaida"
  String jinaLaUsajili; // "Jina la Usajili (M-Koba)"
  String namba; // "Namba ya Simu"
  String nambaSms; // "Namba ya SMS" (override, si lazima)
  String jinsia; // "ME" au "KE"

  Member({
    this.na = '',
    this.jinaLaKawaida = '',
    this.jinaLaUsajili = '',
    this.namba = '',
    this.nambaSms = '',
    this.jinsia = 'ME',
  });

  static const List<String> csvColumns = [
    'Na',
    'Jina la Kawaida',
    'Jina la Usajili (M-Koba)',
    'Namba ya Simu',
    'Namba ya SMS',
    'Jinsia',
  ];

  factory Member.fromCsvRow(Map<String, String> row) {
    return Member(
      na: row['Na'] ?? '',
      jinaLaKawaida: row['Jina la Kawaida'] ?? '',
      jinaLaUsajili: row['Jina la Usajili (M-Koba)'] ?? '',
      namba: row['Namba ya Simu'] ?? '',
      nambaSms: row['Namba ya SMS'] ?? '',
      jinsia: (row['Jinsia'] ?? '').isEmpty ? 'ME' : row['Jinsia']!,
    );
  }

  List<String> toCsvRow() =>
      [na, jinaLaKawaida, jinaLaUsajili, namba, nambaSms, jinsia];

  Member copyWith({
    String? na,
    String? jinaLaKawaida,
    String? jinaLaUsajili,
    String? namba,
    String? nambaSms,
    String? jinsia,
  }) {
    return Member(
      na: na ?? this.na,
      jinaLaKawaida: jinaLaKawaida ?? this.jinaLaKawaida,
      jinaLaUsajili: jinaLaUsajili ?? this.jinaLaUsajili,
      namba: namba ?? this.namba,
      nambaSms: nambaSms ?? this.nambaSms,
      jinsia: jinsia ?? this.jinsia,
    );
  }
}
