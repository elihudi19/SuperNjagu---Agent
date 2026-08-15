import 'package:csv/csv.dart';

/// Husaidia kubadilisha kati ya maandishi ya CSV na List<Map<String,String>>,
/// sawa na jinsi pandas.read_csv/to_csv ilivyokuwa ikitumika Python.
class CsvService {
  static List<Map<String, String>> parse(String csvText) {
    if (csvText.trim().isEmpty) return [];
    final rows = const CsvToListConverter(eol: '\n').convert(csvText, shouldParseNumbers: false);
    if (rows.isEmpty) return [];
    final header = rows.first.map((e) => e.toString()).toList();
    final result = <Map<String, String>>[];
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      final map = <String, String>{};
      for (var j = 0; j < header.length; j++) {
        map[header[j]] = j < row.length ? row[j].toString() : '';
      }
      result.add(map);
    }
    return result;
  }

  static String build(List<String> columns, List<List<String>> rows) {
    final data = <List<String>>[columns, ...rows];
    return const ListToCsvConverter(eol: '\n').convert(data);
  }
}
