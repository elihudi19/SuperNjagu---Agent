import 'dart:typed_data';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class Deposit {
  final String name;
  final String phone;
  final double amount;
  Deposit({required this.name, required this.phone, required this.amount});
}

class _Word {
  final String text;
  final double x0;
  final double top;
  _Word(this.text, this.x0, this.top);
}

/// Sawa na parse_vodacom_pdf() ya Python: inatumia nafasi (x0/top) za kila
/// neno kwenye ukurasa kutambua vichwa vya jedwali (Date, Member, Description,
/// Amount, n.k) na kupanga maneno ya kila mstari kwenye safu husika.
class PdfParserService {
  static const _headerLabels = {
    'date',
    'refference',
    'reference',
    'member',
    'description',
    'amount',
    'balance',
  };

  static List<Deposit> parseVodacomPdf(Uint8List pdfBytes) {
    final deposits = <Deposit>[];
    final document = PdfDocument(inputBytes: pdfBytes);
    try {
      final extractor = PdfTextExtractor(document);
      for (var pageIndex = 0; pageIndex < document.pages.count; pageIndex++) {
        final textLines = extractor.extractTextLines(
          startPageIndex: pageIndex,
          endPageIndex: pageIndex,
        );
        final words = <_Word>[];
        for (final line in textLines) {
          for (final w in line.wordCollection) {
            final t = w.text.trim();
            if (t.isEmpty) continue;
            words.add(_Word(t, w.bounds.left, w.bounds.top));
          }
        }
        if (words.isEmpty) continue;

        // 1) Tambua vichwa vya jedwali (header) na nafasi zake x0
        final header = <String, double>{};
        for (final w in words) {
          final key = w.text.toLowerCase();
          if (_headerLabels.contains(key) && !header.containsKey(key)) {
            header[key] = w.x0;
          }
        }
        if (!header.containsKey('date') || !header.containsKey('member')) continue;

        final headerTop = words
            .where((w) => header.containsKey(w.text.toLowerCase()))
            .map((w) => w.top)
            .reduce((a, b) => a < b ? a : b);

        final boundaries = header.entries.toList()
          ..sort((a, b) => a.value.compareTo(b.value));

        String colFor(double x0) {
          String? bestName;
          double? bestDist;
          for (final e in boundaries) {
            final d = (x0 - e.value).abs();
            if (bestDist == null || d < bestDist) {
              bestDist = d;
              bestName = e.key;
            }
          }
          return bestName ?? '';
        }

        final dataWords = words.where((w) => w.top > headerTop + 5).toList();
        if (dataWords.isEmpty) continue;

        // 2) Kusanya (cluster) maneno kwa mistari kulingana na 'top'
        final clusters = _clusterRows(dataWords, gapThreshold: 12);

        for (final cluster in clusters) {
          final cols = <String, List<String>>{};
          final sorted = List<_Word>.from(cluster)
            ..sort((a, b) {
              final t = a.top.compareTo(b.top);
              return t != 0 ? t : a.x0.compareTo(b.x0);
            });
          for (final w in sorted) {
            final col = colFor(w.x0);
            cols.putIfAbsent(col, () => []).add(w.text);
          }

          final dateText = (cols['date'] ?? []).join(' ');
          if (!RegExp(r'\d{4}-\d{2}-\d{2}').hasMatch(dateText)) continue;

          final memberText = (cols['member'] ?? []).join(' ');
          final descText = (cols['description'] ?? []).join(' ').toLowerCase();
          final amountText = (cols['amount'] ?? []).join(' ');

          if (['withdraw', 'kutoa', 'sent to'].any((k) => descText.contains(k))) {
            continue;
          }

          final phoneMatches = RegExp(r'\d{9,12}').allMatches(memberText).toList();
          final phone = phoneMatches.isNotEmpty
              ? _last9(phoneMatches.first.group(0)!)
              : '';

          var namePart = memberText.replaceAll(RegExp(r'\d{9,12}'), '');
          namePart = namePart.replaceAll(RegExp(r'[-|()]'), ' ');
          namePart = namePart.replaceAll(RegExp(r'\s+'), ' ').trim();

          final amount = _parseMoney(amountText);
          if (amount <= 0) continue;

          deposits.add(Deposit(name: namePart, phone: phone, amount: amount));
        }
      }
    } finally {
      document.dispose();
    }
    return deposits;
  }

  static String _last9(String digits) =>
      digits.length >= 9 ? digits.substring(digits.length - 9) : digits;

  static double _parseMoney(String val) {
    var text = val.replaceAll(',', '').replaceAll('TZS', '').replaceAll('/=', '').trim();
    if (text.isEmpty) return 0.0;
    final match = RegExp(r'[\d.]+').firstMatch(text);
    if (match == null) return 0.0;
    return double.tryParse(match.group(0)!) ?? 0.0;
  }

  static List<List<_Word>> _clusterRows(List<_Word> dataWords, {double gapThreshold = 12}) {
    final sorted = List<_Word>.from(dataWords)..sort((a, b) => a.top.compareTo(b.top));
    final clusters = <List<_Word>>[];
    var current = <_Word>[];
    double? lastTop;
    for (final w in sorted) {
      if (lastTop != null && (w.top - lastTop) > gapThreshold) {
        clusters.add(current);
        current = [];
      }
      current.add(w);
      lastTop = w.top;
    }
    if (current.isNotEmpty) clusters.add(current);
    return clusters;
  }
}
