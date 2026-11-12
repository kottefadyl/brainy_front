// Table layout of a saved view with an optional spreadsheet mode (T46), the same as on the
// web: cells edit in place with the entry editor's rules, rows are added at the bottom and
// columns are added to the data format with an explicit unit choice.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app_strings.dart';
import 'collections_api.dart';
import 'entry_clipboard.dart';
import 'number_units.dart';
import 'spreadsheet_range.dart';

/// What a cell edits directly; the other kinds open the full entry form.
enum SheetEditor { text, url, character, longText, number, duration, date, time, datetime, boolean, select, none }

SheetEditor sheetEditorFor(BrainyField field, BrainyFormat format) {
  if (format.workflow?['stateFieldId'] == field.id) return SheetEditor.none;
  return switch (field.kind) {
    BrainyFieldKind.title || BrainyFieldKind.text => SheetEditor.text,
    BrainyFieldKind.link => SheetEditor.url,
    BrainyFieldKind.character => SheetEditor.character,
    BrainyFieldKind.longText => SheetEditor.longText,
    BrainyFieldKind.number => SheetEditor.number,
    BrainyFieldKind.duration => SheetEditor.duration,
    BrainyFieldKind.date => SheetEditor.date,
    BrainyFieldKind.time => SheetEditor.time,
    BrainyFieldKind.datetime => SheetEditor.datetime,
    BrainyFieldKind.boolean => SheetEditor.boolean,
    BrainyFieldKind.select => SheetEditor.select,
    _ => SheetEditor.none,
  };
}

/// Stored value → editable text (French decimal comma).
String sheetEditable(BrainyField field, String stored, bool french) =>
    field.kind == BrainyFieldKind.number && french ? stored.replaceAll('.', ',') : stored;

/// Typed text → stored value with the entry editor's checks, the reason in the person's language.
({String value, String? error}) sheetStored(BrainyField field, String raw, {bool french = false}) {
  String m(String fr, String en) => french ? fr : en;
  final value = raw.trim();
  if (value.isEmpty) return (value: '', error: null);
  if (value.length > (field.kind == BrainyFieldKind.longText ? 50000 : 10000)) return (value: value, error: m('Cette valeur est trop longue.', 'This value is too long.'));
  switch (field.kind) {
    case BrainyFieldKind.number:
      final number = normalizeFieldNumber(value.replaceAll(RegExp(r'\s'), ''));
      final valid = RegExp(r'^[+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?$').hasMatch(number) && double.tryParse(number)?.isFinite == true;
      return valid ? (value: number, error: null) : (value: value, error: m('Saisissez un nombre valide, par exemple 12,5.', 'Enter a valid number, for example 12.5.'));
    case BrainyFieldKind.date:
      return RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) ? (value: value, error: null) : (value: value, error: m('Saisissez une date valide.', 'Enter a valid date.'));
    case BrainyFieldKind.time:
      return RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(value) ? (value: value, error: null) : (value: value, error: m('Saisissez une heure valide, par exemple 14:30.', 'Enter a valid time, for example 14:30.'));
    case BrainyFieldKind.datetime:
      final date = DateTime.tryParse(value);
      return date == null ? (value: value, error: m('Saisissez une date et une heure valides.', 'Enter a valid date and time.')) : (value: date.toUtc().toIso8601String(), error: null);
    case BrainyFieldKind.duration:
      return RegExp(r'^\d{1,6}:[0-5]\d$').hasMatch(value) ? (value: value, error: null) : (value: value, error: m('Saisissez une durée comme 1:30.', 'Enter a duration such as 1:30.'));
    case BrainyFieldKind.character:
      return value.characters.length == 1 ? (value: value, error: null) : (value: value, error: m('Saisissez un seul caractère.', 'Enter exactly one character.'));
    case BrainyFieldKind.link:
      final uri = Uri.tryParse(value);
      return uri != null && (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty ? (value: value, error: null) : (value: value, error: m('Saisissez un lien commençant par http:// ou https://.', 'Enter a web link starting with http:// or https://.'));
    case BrainyFieldKind.select:
      return field.options.contains(value) ? (value: value, error: null) : (value: value, error: m('Choisissez une des valeurs proposées.', 'Choose one of the choices.'));
    default:
      return (value: value, error: null);
  }
}

/// Kinds offered when a column is added from the table; the others stay in the data format editor.
const sheetColumnKinds = [
  BrainyFieldKind.text, BrainyFieldKind.number, BrainyFieldKind.date, BrainyFieldKind.time, BrainyFieldKind.datetime, BrainyFieldKind.duration,
  BrainyFieldKind.boolean, BrainyFieldKind.select, BrainyFieldKind.longText, BrainyFieldKind.link, BrainyFieldKind.character, BrainyFieldKind.title,
];

/// Existing fields keep every setting; the new column is appended last.
List<Map<String, dynamic>> sheetFieldsWithColumn(BrainyFormat format, {required String name, required BrainyFieldKind kind, String? unit, List<String> options = const []}) => [
  for (final field in format.fields)
    {
      'id': field.id, 'name': field.name, 'kind': field.kind.wireName,
      if (field.unit != null && field.unit!.isNotEmpty) 'unit': field.unit,
      if (field.options.isNotEmpty) 'options': field.options,
      if (field.codeListId != null) 'codeListId': field.codeListId,
      if (field.kind == BrainyFieldKind.objectRef) ...{
        'targetObjectFormatId': field.targetObjectFormatId, 'multiple': field.multiple,
        if (field.variableName != null) 'variableName': field.variableName, 'referenceMode': field.referenceMode,
      },
    },
  {
    'name': name.trim(), 'kind': kind.wireName,
    if (kind == BrainyFieldKind.number && unit != null && unit.isNotEmpty) 'unit': unit,
    if (kind == BrainyFieldKind.select) 'options': options,
  },
];

/// The data format editor's checks for one new column; null when it can be saved.
String? sheetColumnProblem(BrainyFormat format, {required String name, required BrainyFieldKind kind, required String? unitChoice, String customUnit = '', List<String> options = const [], required bool french}) {
  String text(String fr, String en) => french ? fr : en;
  final clean = name.trim();
  if (format.fields.length >= 30) return text('Un format de données compte 30 champs au maximum.', 'A data format has 30 fields at most.');
  if (clean.isEmpty || clean.length > 80) return text('Donnez un nom de 1 à 80 caractères.', 'Give a name of 1 to 80 characters.');
  if (format.fields.any((field) => field.name.toLowerCase() == clean.toLowerCase())) return text('Ce nom de champ existe déjà dans ce format de données.', 'This field name already exists in this data format.');
  if (kind == BrainyFieldKind.number) {
    if (unitChoice == null) return text('Choisissez une unité, ou « Sans unité ».', 'Choose a unit, or “No unit”.');
    if (unitChoice == 'custom' && customUnit.trim().isEmpty) return text('Saisissez l’unité personnalisée.', 'Enter the custom unit.');
    if (unitChoice == 'custom' && customUnit.trim().length > 24) return text('Une unité compte 24 caractères au maximum.', 'A unit can be at most 24 characters.');
  }
  if (kind == BrainyFieldKind.select && (options.length < 2 || options.length > 30 || options.map((item) => item.toLowerCase()).toSet().length != options.length)) {
    return text('Ajoutez de 2 à 30 choix différents.', 'Add 2 to 30 different choices.');
  }
  return null;
}

// The choice is kept per view: in memory for an instant display, and on the device so it
// survives a restart (same storage as the quick entry templates).
final _sheetModeByView = <String, bool>{};
String _sheetModeKey(String viewId) => 'brainy.spreadsheet.$viewId';

class SavedViewTable extends StatefulWidget {
  const SavedViewTable({
    super.key,
    required this.api,
    required this.collection,
    required this.view,
    required this.entries,
    required this.onOpenEntry,
    required this.onEntrySaved,
    required this.onCollectionChanged,
    required this.onEditFormat,
    this.storage = const FlutterSecureStorage(),
    this.canWrite = true,
    this.canChangeStructure = true,
  });

  /// T52/3: a reader sees the plain table only; a collaborator never adds columns.
  final bool canWrite, canChangeStructure;
  final FlutterSecureStorage storage;
  final CollectionsApi api;
  final BrainyCollection collection;
  final Map<String, dynamic> view;
  final List<BrainyEntry> entries;
  final void Function(BrainyEntry entry) onOpenEntry;
  final void Function(BrainyEntry entry) onEntrySaved;
  final void Function(BrainyCollection collection) onCollectionChanged;
  final void Function(BrainyFormat format) onEditFormat;

  @override
  State<SavedViewTable> createState() => _SavedViewTableState();
}

class _SavedViewTableState extends State<SavedViewTable> {
  String get _viewId => widget.view['id'] as String? ?? '';
  late bool _sheet = _sheetModeByView[_viewId] ?? false;

  @override
  void initState() {
    super.initState();
    if (!_sheetModeByView.containsKey(_viewId)) _restore();
  }

  Future<void> _restore() async {
    try {
      final saved = await widget.storage.read(key: _sheetModeKey(_viewId));
      if (saved == null || !mounted || _sheetModeByView.containsKey(_viewId)) return;
      _sheetModeByView[_viewId] = saved == 'on';
      setState(() => _sheet = saved == 'on');
    } catch (_) {
      // Unreadable storage: the sheet simply starts off.
    }
  }

  void _setSheet(bool value) {
    setState(() { _sheet = value; _sheetModeByView[_viewId] = value; });
    widget.storage.write(key: _sheetModeKey(_viewId), value: value ? 'on' : 'off').catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final fr = copy.isFrench;
    if (!widget.canWrite) return _readOnly(context, copy);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: SwitchListTile(
                key: const Key('spreadsheet-switch'),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                secondary: const Icon(Icons.table_chart_outlined),
                title: Text(fr ? 'Mode tableur' : 'Spreadsheet mode', style: const TextStyle(fontWeight: FontWeight.w600)),
                value: _sheet,
                onChanged: _setSheet,
              ),
            ),
            Text(
              _sheet
                  ? fr ? 'Touchez une cellule pour la modifier. Entrée valide, Échap annule.' : 'Tap a cell to change it. Enter saves, Escape cancels.'
                  : fr ? 'Activez-le pour saisir et modifier les données comme dans un tableur.' : 'Turn it on to enter and change data as in a spreadsheet.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_sheet) _SpreadsheetGrid(key: ValueKey('sheet-$_viewId'), table: widget) else _readOnly(context, copy),
      ],
    );
  }

  Widget _readOnly(BuildContext context, AppStrings copy) {
    final collection = widget.collection;
    final ids = (widget.view['columnFieldIds'] as List<dynamic>? ?? const []).cast<String>();
    final fields = collection.formats.expand((format) => format.fields).toList();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          DataColumn(label: Text(copy.text('Data format'))),
          DataColumn(label: Text(copy.text('Created'))),
          for (final id in ids) DataColumn(label: Text(fields.where((field) => field.id == id).firstOrNull?.name ?? id)),
          if (widget.canWrite) DataColumn(label: Text(copy.text('Action'))),
        ],
        rows: [
          for (final entry in widget.entries)
            DataRow(cells: [
              DataCell(Text(collection.formatFor(entry).name)),
              DataCell(Text(MaterialLocalizations.of(context).formatMediumDate(entry.createdAt.toLocal()))),
              for (final id in ids)
                DataCell(Text(switch ((fields.where((field) => field.id == id).firstOrNull, entry.values[id])) {
                  (final BrainyField field, final String value) => displayEntryValue(field, value, copy, snapshot: entry.unitSnapshots[id], collection: collection),
                  (_, final value) => value ?? '—',
                })),
              if (widget.canWrite) DataCell(TextButton(
                onPressed: () => widget.onOpenEntry(entry),
                child: Text(collection.formatFor(entry).appendOnly ? (copy.isFrench ? 'Ouvrir le registre' : 'Open register') : copy.text('Edit')),
              )),
            ]),
        ],
      ),
    );
  }
}

class _SpreadsheetGrid extends StatefulWidget {
  const _SpreadsheetGrid({super.key, required this.table});
  final SavedViewTable table;
  @override
  State<_SpreadsheetGrid> createState() => _SpreadsheetGridState();
}

class _SpreadsheetGridState extends State<_SpreadsheetGrid> {
  static const _cellWidth = 168.0, _rowHeight = 48.0, _numberWidth = 48.0;
  final _gridFocus = FocusNode(debugLabel: 'spreadsheet');
  final _editorFocus = FocusNode(debugLabel: 'spreadsheet-editor');
  final _editor = TextEditingController();
  String? _formatId;
  final _createdIds = <String>[];
  int _row = 0, _col = 0;
  bool _editing = false, _draftRow = false, _saving = false, _cancelled = false;
  String? _problem;
  // T46/1: range selection, sort by a column and column widths remembered per view.
  SheetCell? _anchor;
  SheetSort? _sort;
  final Map<String, double> _widths = {};
  static const _storage = FlutterSecureStorage();
  String get _widthKey => 'brainy.spreadsheet.widths.${t.view['id']}';
  double _widthOf(BrainyField field) => _widths[field.id] ?? _cellWidth;
  SheetRange get _range => sheetRangeOf(_anchor, (row: _row, col: _col));

  SavedViewTable get t => widget.table;
  bool get _fr => AppStrings.of(context).isFrench;
  List<BrainyFormat> get _viewFormats {
    final ids = (t.view['formatIds'] as List<dynamic>? ?? const []).cast<String>();
    return t.collection.formats.where((format) => ids.isEmpty || ids.contains(format.id)).toList();
  }
  BrainyFormat? get _format {
    final formats = _viewFormats;
    if (formats.isEmpty) return null;
    return formats.where((format) => format.id == _formatId).firstOrNull ??
        formats.where((format) => t.entries.any((entry) => entry.formatId == format.id)).firstOrNull ?? formats.first;
  }
  List<BrainyEntry> get _rows {
    final own = t.entries.where((entry) => entry.formatId == _format?.id).toList();
    return sortSheetEntries([...own.where((entry) => !_createdIds.contains(entry.id)), for (final id in _createdIds) ...own.where((entry) => entry.id == id)], _format?.fields ?? const [], _sort);
  }
  int get _rowCount => _rows.length + (_draftRow ? 1 : 0);

  @override
  void initState() {
    super.initState();
    _editorFocus.addListener(() { if (!_editorFocus.hasFocus && _editing && !_cancelled) _commitText(); });
    _storage.read(key: _widthKey).then((saved) {
      if (saved == null || !mounted) return;
      final pairs = saved.split(';').map((pair) => pair.split('=')).where((pair) => pair.length == 2);
      setState(() { for (final pair in pairs) { final width = double.tryParse(pair[1]); if (width != null) _widths[pair[0]] = width; } });
    }).catchError((Object _) {});
  }

  void _setWidth(String fieldId, double width) {
    setState(() => _widths[fieldId] = width.clamp(64, 640).roundToDouble());
  }

  void _saveWidths() => _storage.write(key: _widthKey, value: _widths.entries.map((item) => '${item.key}=${item.value}').join(';')).catchError((Object _) {});

  @override
  void dispose() { _gridFocus.dispose(); _editorFocus.dispose(); _editor.dispose(); super.dispose(); }

  BrainyEntry? _entryAt(int row) => row < _rows.length ? _rows[row] : null;
  bool _locked(BrainyEntry? entry) => entry != null && (entry.ledgerHash != null || entry.offlinePending || (_format?.appendOnly ?? false));
  SheetEditor _editorKind(BrainyField field, BrainyEntry? entry) => _locked(entry) ? SheetEditor.none : sheetEditorFor(field, _format!);

  void _select(int row, int col, {bool extend = false}) {
    final fields = _format?.fields ?? const <BrainyField>[];
    setState(() {
      if (extend) { _anchor ??= (row: _row, col: _col); } else { _anchor = null; }
      _row = row.clamp(0, (_rowCount - 1).clamp(0, 1 << 20));
      _col = col.clamp(0, (fields.length - 1).clamp(0, 1 << 20));
    });
    _gridFocus.requestFocus();
  }

  String _fillInForm(BrainyField field) => '${field.name} : ${_fr ? 'à remplir dans le formulaire complet' : 'fill it in the full form'}';

  /// Saves several cells, one request per row; rows past the last one become new entries.
  Future<void> _saveRows(Map<int, Map<String, String>> changes, Set<String> skipped, [List<Map<String, String>> newRows = const []]) async {
    if (_saving) return;
    final copy = AppStrings.of(context);
    final format = _format!;
    final problems = [...skipped];
    var done = 0;
    setState(() => _saving = true);
    Future<void> save(BrainyEntry? entry, Map<String, String> cells, String label) async {
      final values = Map<String, String>.of(entry?.values ?? const {})..addAll(cells);
      values.removeWhere((_, value) => value.trim().isEmpty);
      if (values.isEmpty || (entry != null && cells.entries.every((cell) => (entry.values[cell.key] ?? '') == cell.value))) return;
      try {
        final saved = await t.api.saveEntry(t.collection.id, values, entryId: entry?.id, formatId: format.id, measures: entry?.measures ?? const {}, expectedUpdatedAt: entry?.updatedAt);
        if (entry == null) _createdIds.add(saved.id);
        t.onEntrySaved(saved);
        done++;
      } catch (error) {
        problems.add('$label : ${copy.error(error)}');
      }
    }
    try {
      final rows = _rows;
      for (final row in changes.keys.toList()..sort()) {
        if (row < rows.length) await save(rows[row], changes[row]!, '${_fr ? 'Ligne' : 'Row'} ${row + 1}');
      }
      for (var index = 0; index < newRows.length; index++) {
        if (newRows[index].isNotEmpty) await save(null, newRows[index], '${_fr ? 'Nouvelle ligne' : 'New row'} ${index + 1}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _draftRow = false;
          _problem = problems.isEmpty ? null : '${_fr ? '$done ligne(s) enregistrée(s).' : '$done row(s) saved.'} ${problems.take(3).join(' · ')}${problems.length > 3 ? ' …' : ''}';
        });
      }
    }
  }

  /// Copies the selected cells as tab-separated text.
  Future<void> _copy() async {
    final fields = _format?.fields ?? const <BrainyField>[];
    final range = _range;
    final lines = [
      for (var row = range.top; row <= range.bottom; row++)
        [for (var col = range.left; col <= range.right && col < fields.length; col++) sheetEditable(fields[col], _entryAt(row)?.values[fields[col].id] ?? '', _fr)],
    ];
    await Clipboard.setData(ClipboardData(text: sheetToClipboard(lines)));
    if (mounted) setState(() => _problem = null);
  }

  /// Pastes tab-separated text from the selected cell; one copied value fills the whole selection.
  Future<void> _paste() async {
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    if (text == null || text.isEmpty || !mounted) return;
    final fields = _format!.fields;
    final rows = _rows;
    final grid = sheetParseClipboard(text).take(200).toList();
    final range = _range;
    final single = grid.length == 1 && grid.first.length == 1 && (range.bottom > range.top || range.right > range.left);
    final top = single ? range.top : _row, left = single ? range.left : _col;
    final height = single ? range.bottom - range.top + 1 : grid.length;
    final width = single ? range.right - range.left + 1 : grid.map((line) => line.length).reduce((a, b) => a > b ? a : b);
    final changes = <int, Map<String, String>>{};
    final newRows = <Map<String, String>>[];
    final skipped = <String>{};
    for (var r = 0; r < height; r++) {
      final row = top + r;
      final entry = row < rows.length ? rows[row] : null;
      final cells = <String, String>{};
      for (var c = 0; c < width; c++) {
        if (left + c >= fields.length) continue;
        final line = single ? grid.first : grid[r];
        if (!single && c >= line.length) continue;
        final field = fields[left + c];
        final raw = single ? grid.first.first : line[c];
        if (_editorKind(field, entry) == SheetEditor.none) { skipped.add(_fillInForm(field)); continue; }
        final result = sheetStored(field, field.kind == BrainyFieldKind.boolean ? sheetPastedBoolean(raw) : raw, french: _fr);
        if (result.error != null) { skipped.add('${field.name} : ${result.error}'); continue; }
        cells[field.id] = result.value;
      }
      if (row < rows.length) { changes[row] = cells; } else { newRows.add(cells..removeWhere((_, value) => value.isEmpty)); }
    }
    await _saveRows(changes, skipped, newRows);
  }

  /// The first row of the selection is copied into the rows below it (the fill handle of a spreadsheet).
  Future<void> _fillDown() async {
    final range = _range;
    if (range.bottom == range.top) {
      setState(() => _problem = _fr ? 'Sélectionnez plusieurs lignes avant de recopier vers le bas.' : 'Select several rows before filling down.');
      return;
    }
    final fields = _format!.fields;
    final rows = _rows;
    final source = _entryAt(range.top);
    final changes = <int, Map<String, String>>{};
    final skipped = <String>{};
    for (var row = range.top + 1; row <= range.bottom && row < rows.length; row++) {
      for (var col = range.left; col <= range.right; col++) {
        final field = fields[col];
        if (_editorKind(field, rows[row]) == SheetEditor.none) { skipped.add(_fillInForm(field)); continue; }
        (changes[row] ??= {})[field.id] = source?.values[field.id] ?? '';
      }
    }
    await _saveRows(changes, skipped);
  }

  Future<void> _start(int row, int col, {String? initial}) async {
    final format = _format!;
    final entry = _entryAt(row), field = format.fields[col];
    final kind = _editorKind(field, entry);
    setState(() { _row = row; _col = col; _problem = null; });
    switch (kind) {
      case SheetEditor.none:
        if (entry != null) { t.onOpenEntry(entry); } else { setState(() => _problem = _fr ? 'Ce type de champ se remplit dans le formulaire complet : enregistrez d’abord une autre cellule de la ligne.' : 'This kind of field is filled in the full form: save another cell of the row first.'); }
      case SheetEditor.boolean:
        await _commit(row, field, entry?.values[field.id] == 'true' ? 'false' : 'true');
      case SheetEditor.select:
        final picked = await _pickChoice(field, entry?.values[field.id]);
        if (picked != null) await _commit(row, field, picked);
      case SheetEditor.date:
        final current = DateTime.tryParse(entry?.values[field.id] ?? '');
        final date = await showDatePicker(context: context, initialDate: current ?? DateTime.now(), firstDate: DateTime(1900), lastDate: DateTime(2200));
        if (date != null) await _commit(row, field, '${date.year.toString().padLeft(4, '0')}-${_two(date.month)}-${_two(date.day)}');
      case SheetEditor.time:
        final parts = (entry?.values[field.id] ?? '').split(':');
        final time = await showTimePicker(context: context, initialTime: parts.length == 2 ? TimeOfDay(hour: int.tryParse(parts[0]) ?? 9, minute: int.tryParse(parts[1]) ?? 0) : TimeOfDay.now());
        if (time != null) await _commit(row, field, '${_two(time.hour)}:${_two(time.minute)}');
      case SheetEditor.datetime:
        final current = DateTime.tryParse(entry?.values[field.id] ?? '')?.toLocal() ?? DateTime.now();
        final date = await showDatePicker(context: context, initialDate: current, firstDate: DateTime(1900), lastDate: DateTime(2200));
        if (date == null || !mounted) return;
        final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(current));
        if (time != null) await _commit(row, field, DateTime(date.year, date.month, date.day, time.hour, time.minute).toIso8601String());
      default:
        _cancelled = false;
        _editor.text = initial ?? sheetEditable(field, entry?.values[field.id] ?? '', _fr);
        _editor.selection = TextSelection.collapsed(offset: _editor.text.length);
        setState(() => _editing = true);
        WidgetsBinding.instance.addPostFrameCallback((_) => _editorFocus.requestFocus());
    }
  }

  static String _two(int value) => value.toString().padLeft(2, '0');

  Future<String?> _pickChoice(BrainyField field, String? current) => showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(child: ListView(shrinkWrap: true, children: [
      ListTile(title: Text(field.name, style: Theme.of(context).textTheme.titleMedium)),
      for (final option in field.options)
        ListTile(title: Text(option), trailing: option == current ? const Icon(Icons.check) : null, onTap: () => Navigator.pop(context, option)),
    ])),
  );

  Future<void> _commitText({int moveRow = 0, int moveCol = 0}) async {
    if (!_editing) return;
    final field = _format!.fields[_col];
    await _commit(_row, field, _editor.text, moveRow: moveRow, moveCol: moveCol, fromEditor: true);
  }

  /// Saves one cell; on failure the typed text stays with the reason.
  Future<void> _commit(int row, BrainyField field, String raw, {int moveRow = 0, int moveCol = 0, bool fromEditor = false}) async {
    if (_saving) return;
    final copy = AppStrings.of(context);
    final format = _format!;
    final entry = _entryAt(row);
    final result = sheetStored(field, raw, french: copy.isFrench);
    if (result.error != null) { setState(() => _problem = '${field.name} : ${result.error}'); return; }
    if (result.value == (entry?.values[field.id] ?? '')) { _stopEditing(moveRow, moveCol); return; }
    final values = Map<String, String>.of(entry?.values ?? const {});
    if (result.value.isEmpty) { values.remove(field.id); } else { values[field.id] = result.value; }
    if (values.values.every((value) => value.trim().isEmpty)) {
      if (entry == null) { _stopEditing(0, 0); return; }
      setState(() => _problem = copy.isFrench ? 'Une entrée garde au moins une valeur.' : 'An entry keeps at least one value.');
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await t.api.saveEntry(t.collection.id, values, entryId: entry?.id, formatId: format.id, measures: entry?.measures ?? const {}, expectedUpdatedAt: entry?.updatedAt);
      if (!mounted) return;
      if (entry == null) { _createdIds.add(saved.id); _draftRow = false; }
      t.onEntrySaved(saved);
      setState(() => _problem = null);
      _stopEditing(moveRow, moveCol);
    } catch (error) {
      if (mounted) setState(() => _problem = '${field.name} : ${copy.error(error)}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _stopEditing(int moveRow, int moveCol) {
    setState(() => _editing = false);
    _select(_row + moveRow, _col + moveCol);
  }

  KeyEventResult _onGridKey(FocusNode node, KeyEvent event) {
    if (_editing || event is KeyUpEvent) return KeyEventResult.ignored;
    final fields = _format?.fields ?? const <BrainyField>[];
    final key = event.logicalKey;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    final control = HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed;
    if (key == LogicalKeyboardKey.arrowDown) { _select(_row + 1, _col, extend: shift); return KeyEventResult.handled; }
    if (key == LogicalKeyboardKey.arrowUp) { _select(_row - 1, _col, extend: shift); return KeyEventResult.handled; }
    if (key == LogicalKeyboardKey.arrowRight) { _select(_row, _col + 1, extend: shift); return KeyEventResult.handled; }
    if (key == LogicalKeyboardKey.arrowLeft) { _select(_row, _col - 1, extend: shift); return KeyEventResult.handled; }
    if (control && key == LogicalKeyboardKey.keyC) { _copy(); return KeyEventResult.handled; }
    if (control && key == LogicalKeyboardKey.keyV) { _paste(); return KeyEventResult.handled; }
    if (control && key == LogicalKeyboardKey.keyD) { _fillDown(); return KeyEventResult.handled; }
    if (key == LogicalKeyboardKey.escape && _anchor != null) { setState(() => _anchor = null); return KeyEventResult.handled; }
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.f2 || (key == LogicalKeyboardKey.space && fields[_col].kind == BrainyFieldKind.boolean)) {
      if (_rowCount > 0) _start(_row, _col);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.delete || key == LogicalKeyboardKey.backspace) {
      final entry = _entryAt(_row);
      if (entry != null && _editorKind(fields[_col], entry) != SheetEditor.none && (entry.values[fields[_col].id] ?? '').isNotEmpty) _commit(_row, fields[_col], '');
      return KeyEventResult.handled;
    }
    final character = event.character;
    // Typing replaces the cell, as in a spreadsheet.
    if (character != null && character.length == 1 && character.trim().isNotEmpty && _rowCount > 0 && !HardwareKeyboard.instance.isControlPressed &&
        const {SheetEditor.text, SheetEditor.url, SheetEditor.character, SheetEditor.longText, SheetEditor.number, SheetEditor.duration}.contains(_editorKind(fields[_col], _entryAt(_row)))) {
      _start(_row, _col, initial: character);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _addRow() {
    final fields = _format!.fields;
    final col = fields.indexWhere((field) => sheetEditorFor(field, _format!) != SheetEditor.none);
    setState(() => _draftRow = true);
    _start(_rows.length, col < 0 ? 0 : col);
  }

  String _unitSymbol(String? unit) {
    if (unit == null || unit.isEmpty) return '';
    final local = t.collection.units.where((item) => 'local:${item.id}' == unit || item.id == unit).firstOrNull;
    return local?.symbol ?? numberUnit(unit)?.symbol ?? unit;
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final fr = copy.isFrench;
    final format = _format;
    final scheme = Theme.of(context).colorScheme;
    if (format == null) return Text(fr ? 'Cette vue ne contient aucun format de données.' : 'This view has no data format.');
    final fields = format.fields;
    final canAddColumn = format.linkedSource == null && fields.length < 30;
    final border = BorderSide(color: scheme.outlineVariant);
    // One height per row, shared by the fixed numbers and the scrolling cells so they stay aligned;
    // a long text being edited gets room for four lines.
    double heightOf(int row) => _editing && row == _row && _editorKind(fields[_col], _entryAt(row)) == SheetEditor.longText ? 128 : _rowHeight;

    Widget headerCell(BrainyField field) {
      final sorted = _sort?.fieldId == field.id ? _sort : null;
      return Container(
        width: _widthOf(field), height: 56,
        decoration: BoxDecoration(color: scheme.surfaceContainerHigh, border: Border(right: border, bottom: border)),
        child: Stack(children: [
          Positioned.fill(child: Semantics(
            button: true,
            label: '${field.name}, ${sorted == null ? (fr ? 'trier' : 'sort') : sorted.ascending ? (fr ? 'tri croissant' : 'sorted ascending') : (fr ? 'tri décroissant' : 'sorted descending')}',
            excludeSemantics: true,
            child: InkWell(
              key: Key('sheet-sort-${field.id}'),
              onTap: () => setState(() { _sort = nextSheetSort(_sort, field.id); _anchor = null; }),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 14, 0),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(child: Text(field.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
                    if (sorted != null) Icon(sorted.ascending ? Icons.arrow_upward : Icons.arrow_downward, size: 14, color: scheme.primary),
                  ]),
                  Text('${copy.text(field.kind.label)}${field.kind == BrainyFieldKind.number && (field.unit ?? '').isNotEmpty ? ' · ${_unitSymbol(field.unit)}' : ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                ]),
              ),
            ),
          )),
          // Drag the right edge to widen or narrow the column; arrow keys do the same once it has the focus.
          Positioned(top: 0, bottom: 0, right: 0, width: 12, child: Semantics(
            label: fr ? 'Largeur de ${field.name}' : 'Width of ${field.name}',
            child: Focus(
              onKeyEvent: (node, event) {
                if (event is KeyUpEvent) return KeyEventResult.ignored;
                final step = event.logicalKey == LogicalKeyboardKey.arrowRight ? 16 : event.logicalKey == LogicalKeyboardKey.arrowLeft ? -16 : 0;
                if (step == 0) return KeyEventResult.ignored;
                _setWidth(field.id, _widthOf(field) + step);
                _saveWidths();
                return KeyEventResult.handled;
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeColumn,
                child: GestureDetector(
                  key: Key('sheet-resize-${field.id}'),
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (details) => _setWidth(field.id, _widthOf(field) + details.delta.dx),
                  onHorizontalDragEnd: (_) => _saveWidths(),
                  onDoubleTap: () { setState(() => _widths.remove(field.id)); _saveWidths(); },
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          )),
        ]),
      );
    }

    Widget cell(int row, int col) {
      final entry = _entryAt(row), field = fields[col];
      final selected = row == _row && col == _col;
      final inRange = _anchor != null && sheetInRange(_range, row, col);
      final kind = _editorKind(field, entry);
      final editing = selected && _editing;
      final value = entry?.values[field.id] ?? '';
      Widget content;
      if (editing) {
        content = CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): () { _cancelled = true; setState(() { _editing = false; _problem = null; }); _gridFocus.requestFocus(); },
            const SingleActivator(LogicalKeyboardKey.tab): () => _commitText(moveCol: 1),
            const SingleActivator(LogicalKeyboardKey.tab, shift: true): () => _commitText(moveCol: -1),
            if (kind != SheetEditor.longText) const SingleActivator(LogicalKeyboardKey.enter): () => _commitText(moveRow: 1),
            if (kind == SheetEditor.longText) const SingleActivator(LogicalKeyboardKey.enter, control: true): () => _commitText(moveRow: 1),
          },
          child: TextField(
            key: const Key('spreadsheet-editor'),
            controller: _editor,
            focusNode: _editorFocus,
            maxLines: kind == SheetEditor.longText ? 4 : 1,
            minLines: 1,
            keyboardType: switch (kind) { SheetEditor.number => const TextInputType.numberWithOptions(decimal: true, signed: true), SheetEditor.url => TextInputType.url, SheetEditor.longText => TextInputType.multiline, _ => TextInputType.text },
            textInputAction: kind == SheetEditor.longText ? TextInputAction.newline : TextInputAction.done,
            // Keep the focus on submit: a refused value stays editable with its reason.
            onEditingComplete: () {},
            onSubmitted: (_) => _commitText(moveRow: 1),
            decoration: InputDecoration(
              isDense: true, border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              hintText: kind == SheetEditor.duration ? '1:30' : kind == SheetEditor.url ? 'https://' : null,
              suffixText: kind == SheetEditor.number ? _unitSymbol(field.unit) : null,
            ),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        );
      } else if (field.kind == BrainyFieldKind.boolean) {
        content = Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.only(left: 6), child: Icon(value == 'true' ? Icons.check_box : Icons.check_box_outline_blank, size: 22, color: value == 'true' ? scheme.primary : scheme.outline)));
      } else {
        content = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Align(
            alignment: field.kind == BrainyFieldKind.number ? Alignment.centerRight : Alignment.centerLeft,
            child: Text(value.isEmpty ? '' : displayEntryValue(field, value, copy, snapshot: entry?.unitSnapshots[field.id], collection: t.collection), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: kind == SheetEditor.none ? scheme.onSurfaceVariant : null)),
          ),
        );
      }
      return Semantics(
        key: Key('sheet-cell-$row-$col'),
        selected: selected,
        readOnly: kind == SheetEditor.none,
        label: '${field.name}, ${fr ? 'ligne' : 'row'} ${row + 1}',
        child: InkWell(
          // No double-tap handler: it would delay every single tap. A second tap on the
          // selected cell edits it, which a double click also does.
          onTap: editing ? null : () {
            if (HardwareKeyboard.instance.isShiftPressed) { _select(row, col, extend: true); return; }
            if (selected || field.kind == BrainyFieldKind.boolean) { _start(row, col); } else { _select(row, col); }
          },
          // On a touch screen, a long press extends the selection from the selected cell.
          onLongPress: editing ? null : () => _select(row, col, extend: true),
          child: Container(
            width: _widthOf(field), height: heightOf(row),
            decoration: BoxDecoration(
              color: _locked(entry) ? scheme.surfaceContainerLow : editing ? scheme.surfaceContainerHighest : inRange ? scheme.primaryContainer.withValues(alpha: .45) : scheme.surface,
              border: Border(right: border, bottom: border),
            ),
            foregroundDecoration: selected ? BoxDecoration(border: Border.all(color: scheme.primary, width: 2)) : null,
            child: content,
          ),
        ),
      );
    }

    final rows = _rows;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_viewFormats.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: DropdownMenu<String>(
              label: Text(fr ? 'Format de données de la feuille' : 'Data format of the sheet'),
              initialSelection: format.id,
              dropdownMenuEntries: [for (final item in _viewFormats) DropdownMenuEntry(value: item.id, label: item.name)],
              onSelected: (value) => setState(() { _formatId = value; _row = 0; _col = 0; _editing = false; _draftRow = false; }),
            ),
          ),
        if (_problem != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Semantics(liveRegion: true, child: Container(
              width: double.infinity, padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(border: Border.all(color: scheme.error), borderRadius: BorderRadius.circular(10)),
              child: Text(_problem!, style: TextStyle(color: scheme.error)),
            )),
          ),
        Focus(
          focusNode: _gridFocus,
          onKeyEvent: _onGridKey,
          child: Container(
            decoration: BoxDecoration(
              // Non-uniform border colours cannot be rounded in Flutter, so the sheet keeps square corners.
              border: Border(top: BorderSide(color: _formatColor(format.color, scheme), width: 3), left: border),
            ),
            // The row numbers stay in place while the cells scroll sideways, as in a spreadsheet.
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Column(key: const Key('spreadsheet-row-numbers'), children: [
                Container(width: _numberWidth, height: 56, alignment: Alignment.center, decoration: BoxDecoration(color: scheme.surfaceContainerHigh, border: Border(right: border, bottom: border)), child: const Text('#')),
                for (var row = 0; row < _rowCount; row++)
                  Container(width: _numberWidth, height: heightOf(row), alignment: Alignment.center, decoration: BoxDecoration(color: scheme.surfaceContainerHigh, border: Border(right: border, bottom: border)), child: Text(row < rows.length ? '${row + 1}' : '*', style: Theme.of(context).textTheme.bodySmall)),
              ]),
              Expanded(
                child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    for (final field in fields) headerCell(field),
                    Container(
                      height: 56, padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(color: scheme.surfaceContainerHigh, border: Border(right: border, bottom: border)),
                      child: !widget.table.canChangeStructure ? const SizedBox(width: 96) : Tooltip(
                        message: canAddColumn ? '' : format.linkedSource != null ? (fr ? 'Format lié : modifiez la source.' : 'Linked format: change the source.') : (fr ? '30 champs au maximum.' : '30 fields at most.'),
                        child: OutlinedButton.icon(
                          key: const Key('spreadsheet-add-column'),
                          onPressed: canAddColumn ? () => _addColumn(format) : null,
                          icon: const Icon(Icons.add, size: 18),
                          label: Text(fr ? 'Colonne' : 'Column'),
                        ),
                      ),
                    ),
                  ]),
                  for (var row = 0; row < _rowCount; row++)
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      for (var col = 0; col < fields.length; col++) cell(row, col),
                      SizedBox(
                        width: 56, height: heightOf(row),
                        child: row < rows.length ? IconButton(tooltip: fr ? 'Ouvrir la ligne ${row + 1}' : 'Open row ${row + 1}', icon: const Icon(Icons.open_in_new, size: 18), onPressed: () => t.onOpenEntry(rows[row])) : null,
                      ),
                    ]),
                ],
              ),
            ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
          OutlinedButton.icon(key: const Key('spreadsheet-add-row'), onPressed: _draftRow || _saving ? null : _addRow, icon: const Icon(Icons.add), label: Text(fr ? 'Ajouter une ligne' : 'Add a row')),
          const SizedBox(width: 4),
          IconButton(key: const Key('spreadsheet-copy'), tooltip: fr ? 'Copier la sélection (Ctrl+C)' : 'Copy the selection (Ctrl+C)', onPressed: _rowCount == 0 ? null : _copy, icon: const Icon(Icons.copy_outlined)),
          IconButton(key: const Key('spreadsheet-paste'), tooltip: fr ? 'Coller (Ctrl+V)' : 'Paste (Ctrl+V)', onPressed: _saving ? null : _paste, icon: const Icon(Icons.content_paste_outlined)),
          IconButton(key: const Key('spreadsheet-fill-down'), tooltip: fr ? 'Recopier vers le bas (Ctrl+D)' : 'Fill down (Ctrl+D)', onPressed: _saving || _anchor == null ? null : _fillDown, icon: const Icon(Icons.vertical_align_bottom)),
          if (_saving) ...[const SizedBox(width: 12), Text(fr ? 'Enregistrement…' : 'Saving…', style: Theme.of(context).textTheme.bodySmall)],
        ]),
      ],
    );
  }

  Color _formatColor(String hex, ColorScheme scheme) {
    final value = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
    return value == null ? scheme.outlineVariant : Color(0xFF000000 | value);
  }

  Future<void> _addColumn(BrainyFormat format) async {
    final updated = await showDialog<BrainyCollection>(
      context: context,
      builder: (context) => AddSheetColumnDialog(api: t.api, collection: t.collection, format: format, onMoreKinds: () { Navigator.pop(context); t.onEditFormat(format); }),
    );
    if (updated != null && mounted) { t.onCollectionChanged(updated); setState(() { _row = 0; _col = format.fields.length; }); }
  }
}

class AddSheetColumnDialog extends StatefulWidget {
  const AddSheetColumnDialog({super.key, required this.api, required this.collection, required this.format, required this.onMoreKinds});
  final CollectionsApi api;
  final BrainyCollection collection;
  final BrainyFormat format;
  final VoidCallback onMoreKinds;
  @override
  State<AddSheetColumnDialog> createState() => _AddSheetColumnDialogState();
}

class _AddSheetColumnDialogState extends State<AddSheetColumnDialog> {
  final _name = TextEditingController(), _custom = TextEditingController(), _options = TextEditingController();
  BrainyFieldKind _kind = BrainyFieldKind.text;
  // No unit is preselected: a number column needs an explicit choice, "no unit" included.
  String? _unitChoice;
  String? _error;
  bool _busy = false;

  @override
  void dispose() { _name.dispose(); _custom.dispose(); _options.dispose(); super.dispose(); }

  Future<void> _save() async {
    final fr = AppStrings.of(context).isFrench;
    final options = _options.text.split('\n').map((item) => item.trim()).where((item) => item.isNotEmpty).toList();
    final problem = sheetColumnProblem(widget.format, name: _name.text, kind: _kind, unitChoice: _unitChoice, customUnit: _custom.text, options: options, french: fr);
    if (problem != null) { setState(() => _error = problem); return; }
    final unit = _unitChoice == 'custom' ? _custom.text.trim() : _unitChoice == 'none' ? null : _unitChoice;
    setState(() { _busy = true; _error = null; });
    try {
      final updated = await widget.api.updateFormat(widget.collection.id, widget.format, widget.format.name, sheetFieldsWithColumn(widget.format, name: _name.text, kind: _kind, unit: unit, options: options));
      if (mounted) Navigator.pop(context, updated);
    } catch (error) {
      if (mounted) setState(() => _error = AppStrings.of(context).error(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final fr = copy.isFrench;
    return AlertDialog(
      title: Text(fr ? 'Nouvelle colonne · ${widget.format.name}' : 'New column · ${widget.format.name}'),
      scrollable: true,
      content: SizedBox(
        width: 420,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(fr ? 'La colonne devient un champ du format de données : elle apparaît aussi dans le formulaire des entrées.' : 'The column becomes a field of the data format: it also appears in the entry form.', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          TextField(key: const Key('column-name'), controller: _name, autofocus: true, maxLength: 80, decoration: InputDecoration(labelText: fr ? 'Nom de la colonne' : 'Column name')),
          const SizedBox(height: 8),
          DropdownButtonFormField<BrainyFieldKind>(
            key: const Key('column-kind'),
            initialValue: _kind,
            isExpanded: true,
            decoration: InputDecoration(labelText: fr ? 'Type de champ' : 'Field type'),
            items: [for (final kind in sheetColumnKinds) DropdownMenuItem(value: kind, child: Text(copy.text(kind.label)))],
            onChanged: (value) => setState(() { _kind = value ?? _kind; _error = null; }),
          ),
          if (_kind == BrainyFieldKind.number) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const Key('column-unit'),
              initialValue: _unitChoice,
              isExpanded: true,
              hint: Text(fr ? 'Choisir une unité…' : 'Choose a unit…'),
              decoration: InputDecoration(labelText: copy.text('Unit'), helperText: fr ? 'L’unité ne pourra plus changer une fois des valeurs saisies.' : 'The unit cannot change once values are entered.', helperMaxLines: 2),
              items: [
                DropdownMenuItem(value: 'none', child: Text(fr ? 'Sans unité' : 'No unit')),
                for (final unit in numberUnits) DropdownMenuItem(value: unit.code, child: Text(unitChoiceLabel(copy, unit), overflow: TextOverflow.ellipsis)),
                for (final unit in widget.collection.units) DropdownMenuItem(value: 'local:${unit.id}', child: Text('${fr ? 'Collection' : 'Collection'} · ${unit.name} (${unit.symbol})', overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(value: 'custom', child: Text(fr ? 'Unité personnalisée…' : 'Custom unit…')),
              ],
              onChanged: (value) => setState(() { _unitChoice = value; _error = null; }),
            ),
            if (_unitChoice == 'custom') TextField(key: const Key('column-custom-unit'), controller: _custom, maxLength: 24, decoration: InputDecoration(labelText: fr ? 'Unité personnalisée' : 'Custom unit')),
          ],
          if (_kind == BrainyFieldKind.select) ...[
            const SizedBox(height: 12),
            TextField(controller: _options, minLines: 3, maxLines: 6, decoration: InputDecoration(labelText: fr ? 'Choix (un par ligne)' : 'Choices (one per line)')),
          ],
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Semantics(liveRegion: true, child: Text(_error!, key: const Key('column-error'), style: TextStyle(color: Theme.of(context).colorScheme.error)))),
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: widget.onMoreKinds, child: Text(fr ? 'Autres types (pièce jointe, référence, mesure, code, lieu…)' : 'Other types (attachment, reference, measure, code, place…)'))),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(fr ? 'Annuler' : 'Cancel')),
        FilledButton(key: const Key('column-save'), onPressed: _busy ? null : _save, child: Text(_busy ? (fr ? 'Ajout…' : 'Adding…') : (fr ? 'Ajouter la colonne' : 'Add the column'))),
      ],
    );
  }
}
