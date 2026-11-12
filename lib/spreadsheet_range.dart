// T46/1: ranges, clipboard text, sorting and fill for the spreadsheet mode (same rules as the web,
// lib/spreadsheet-range.ts). Every pasted or filled value still goes through sheetStored.
import 'collections_api.dart';

typedef SheetCell = ({int row, int col});
typedef SheetRange = ({int top, int left, int bottom, int right});

SheetRange sheetRangeOf(SheetCell? anchor, SheetCell active) {
  final from = anchor ?? active;
  return (
    top: from.row < active.row ? from.row : active.row,
    bottom: from.row > active.row ? from.row : active.row,
    left: from.col < active.col ? from.col : active.col,
    right: from.col > active.col ? from.col : active.col,
  );
}

bool sheetInRange(SheetRange range, int row, int col) => row >= range.top && row <= range.bottom && col >= range.left && col <= range.right;

/// Tab-separated text, as spreadsheets exchange it; quoted when a cell holds a tab, a line break or a quote.
String sheetToClipboard(List<List<String>> rows) {
  String cell(String value) => RegExp('[\t\n\r"]').hasMatch(value) ? '"${value.replaceAll('"', '""')}"' : value;
  return rows.map((row) => row.map(cell).join('\t')).join('\n');
}

/// Reads tab-separated text from another spreadsheet (quoted cells may hold tabs and line breaks).
List<List<String>> sheetParseClipboard(String text) {
  final rows = <List<String>>[];
  var row = <String>[];
  final value = StringBuffer();
  var quoted = false;
  var source = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  if (source.endsWith('\n')) source = source.substring(0, source.length - 1);
  for (var index = 0; index < source.length; index++) {
    final char = source[index];
    if (quoted) {
      if (char == '"' && index + 1 < source.length && source[index + 1] == '"') {
        value.write('"');
        index++;
      } else if (char == '"') {
        quoted = false;
      } else {
        value.write(char);
      }
    } else if (char == '"' && value.isEmpty) {
      quoted = true;
    } else if (char == '\t') {
      row.add(value.toString());
      value.clear();
    } else if (char == '\n') {
      row.add(value.toString());
      rows.add(row);
      row = <String>[];
      value.clear();
    } else {
      value.write(char);
    }
  }
  row.add(value.toString());
  rows.add(row);
  return rows;
}

typedef SheetSort = ({String fieldId, bool ascending});

SheetSort? nextSheetSort(SheetSort? current, String fieldId) =>
    current?.fieldId != fieldId ? (fieldId: fieldId, ascending: true) : current!.ascending ? (fieldId: fieldId, ascending: false) : null;

final _digits = RegExp(r'(\d+)');

/// Text compared naturally ("Item 2" before "Item 10") and without case.
int _natural(String a, String b) {
  final left = a.toLowerCase().splitMapJoin(_digits, onMatch: (match) => match[0]!.padLeft(20, '0'));
  final right = b.toLowerCase().splitMapJoin(_digits, onMatch: (match) => match[0]!.padLeft(20, '0'));
  return left.compareTo(right);
}

/// Empty cells always come last; numbers compare as numbers.
List<BrainyEntry> sortSheetEntries(List<BrainyEntry> entries, List<BrainyField> fields, SheetSort? order) {
  final field = order == null ? null : fields.where((item) => item.id == order.fieldId).firstOrNull;
  if (order == null || field == null) return entries;
  int compare(String a, String b) {
    if (field.kind == BrainyFieldKind.number || field.kind == BrainyFieldKind.measure) return (double.tryParse(a) ?? 0).compareTo(double.tryParse(b) ?? 0);
    return _natural(a, b);
  }
  return [...entries]..sort((x, y) {
      final a = x.values[field.id] ?? '', b = y.values[field.id] ?? '';
      if (a.isEmpty || b.isEmpty) return a.isEmpty && b.isEmpty ? 0 : a.isEmpty ? 1 : -1;
      return order.ascending ? compare(a, b) : compare(b, a);
    });
}

/// A pasted check box accepts the usual spellings of yes.
String sheetPastedBoolean(String raw) {
  final value = raw.trim().toLowerCase();
  if (value.isEmpty) return '';
  return const {'true', '1', 'oui', 'yes', 'vrai', '✓', 'x'}.contains(value) ? 'true' : 'false';
}
