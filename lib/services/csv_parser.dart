import '../models/student_row.dart';

class CsvParser {
  static List<StudentRow> parse(String csvText) {
    final lines = csvText
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();

    if (lines.isEmpty) return [];

    final sep = lines.first.contains(';') ? ';' : ',';
    final headers = _splitRow(lines.first, sep)
        .map((h) => h.toLowerCase().trim())
        .toList();

    final rows = <StudentRow>[];
    for (int i = 1; i < lines.length; i++) {
      final values = _splitRow(lines[i], sep);
      if (values.every((v) => v.trim().isEmpty)) continue;

      final rowMap = <String, String>{};
      for (int j = 0; j < headers.length && j < values.length; j++) {
        rowMap[headers[j]] = values[j].trim();
      }
      rows.add(StudentRow.fromCsvRow(rowMap));
    }
    return rows;
  }

  static List<String> _splitRow(String row, String sep) {
    final result = <String>[];
    var current = StringBuffer();
    var inQuotes = false;
    for (int i = 0; i < row.length; i++) {
      final ch = row[i];
      if (ch == '"') {
        inQuotes = !inQuotes;
      } else if (ch == sep && !inQuotes) {
        result.add(current.toString());
        current = StringBuffer();
      } else {
        current.write(ch);
      }
    }
    result.add(current.toString());
    return result;
  }
}
