import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'brand_assets.dart';
import 'design_tokens.dart';
import 'workspace_navigation.dart';
import 'workspace_format_cards.dart';
import 'workspace_entry_row.dart';

import 'auth_api.dart';
import 'app_strings.dart';
import 'collections_api.dart';
import 'collection_copy_dialog.dart';
import 'linked_format_dialog.dart';
import 'saved_view_dialog.dart';
import 'calendar_view.dart';
import 'entry_reminder_dialog.dart';
import 'push_registration.dart';
import 'collection_transfer.dart';
import 'entry_clipboard.dart';
import 'entry_details_dialog.dart';
import 'number_units.dart';
import 'object_dialog.dart';
import 'unit_dialog.dart';
import 'starter_dialog.dart';
import 'insights_dialog.dart';
import 'stock_screen.dart';
import 'workflow_screen.dart';
import 'contribution_screen.dart';
import 'ledger_screen.dart';
import 'sensitivity_screen.dart';
import 'entry_links_dialog.dart';
import 'entry_link_duplicate_check.dart';
import 'entry_editor_pickers.dart';
import 'entry_object_ref_field.dart';
import 'offline_entry_queue.dart';
import 'offline_sync_panel.dart';
import 'collection_tools_hub.dart';
import 'workspace_tools_dialog.dart';
import 'quick_capture_sheet.dart';
import 'quick_entry_sheet.dart';
import 'classification_screen.dart';
import 'geo_map_view.dart';
import 'geo_field_input.dart';

part 'workspace_entry_pagination.dart';

const _ink = Color(0xFF20242C);
const _muted = Color(0xFF545E6D);
const _blue = Color(0xFF2463CE);

Color _dialogInk(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFFF1F3F7)
    : _ink;
Color _dialogMuted(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFFB5BECC)
    : _muted;

Color _pastelColor(String color) {
  final hex = color.replaceFirst('#', '');
  return Color(
    int.tryParse(hex, radix: 16) == null
        ? 0xFFEEF5FF
        : 0xFF000000 | int.parse(hex, radix: 16),
  );
}

Color _formatTint(BrainyFormat format) => _pastelColor(format.color);

String _displayFormatName(BuildContext context, BrainyFormat format) =>
    format.id.startsWith('legacy-') && format.name == 'General'
    ? AppStrings.of(context).text('General')
    : format.name;

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({
    super.key,
    required this.user,
    required this.api,
    required this.onSignOut,
    this.onEditProfile,
    this.onLanguageChanged,
    this.themeButton,
  });

  final AppUser user;
  final AuthApi api;
  final Future<void> Function() onSignOut;
  final VoidCallback? onEditProfile;
  final ValueChanged<String>? onLanguageChanged;
  final Widget? themeButton;

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  void _mutate(VoidCallback change) => setState(change);
  bool get _dark => Theme.of(context).brightness == Brightness.dark;
  Color get _panel => _dark ? BrainyColors.darkSurface : BrainyColors.lightSurface;
  Color get _panelBorder =>
      _dark ? BrainyColors.darkLine : BrainyColors.lightLine;
  Color get _panelInk => _dark ? BrainyColors.darkInk : BrainyColors.lightInk;
  Color get _panelMuted => _dark ? BrainyColors.darkMuted : BrainyColors.lightMuted;
  Color get _actionAccent => _dark ? BrainyColors.darkAccent : _blue;


  String _t(String value) => AppStrings.of(context).text(value);
  AppStrings get _copy => AppStrings.of(context);
  late final CollectionsApi _api = CollectionsApi(widget.api);
  late final PushRegistration _push = PushRegistration(_api);
  List<BrainyCollection> _collections = [];
  List<BrainyEntry> _entries = [];
  String? _pageCursor;
  String? _pageAfter;
  final List<String?> _previousPages = [];
  bool _loadingMore = false;
  final _searchController = TextEditingController();
  final _filterController = TextEditingController();
  Timer? _filterDebounce;
  int _entryRequest = 0;
  String _search = '';
  String? _filterFormatId;
  String? _filterFieldId;
  String _filterOperator = 'EQ';
  String _filterValue = '';
  String? _selectedViewId;
  String? _selectedId;
  bool _loading = true;
  bool _loadingEntries = false;
  String? _error;
  Map<String, String>? _queuedShare;

  BrainyCollection? get _selected {
    for (final collection in _collections) {
      if (collection.id == _selectedId) return collection;
    }
    return null;
  }

  Map<String, dynamic>? get _selectedView {
    for (final view
        in _selected?.savedViews ?? const <Map<String, dynamic>>[]) {
      if (view['id'] == _selectedViewId) return view;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    QuickCaptureBridge.install((data) { _queuedShare = data; if (_collections.isNotEmpty) { _queuedShare = null; _showQuickCapture(data); } });
    _load();
    _push.refreshIfAuthorized().catchError((Object _) {});
  }

  @override
  void dispose() {
    QuickCaptureBridge.clear();
    _filterDebounce?.cancel();
    _push.dispose();
    _searchController.dispose();
    _filterController.dispose();
    super.dispose();
  }

  void _scheduleEntries() {
    _filterDebounce?.cancel();
    _filterDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _search = _searchController.text.trim();
        _filterValue = _filterController.text.trim();
      });
      _loadEntries();
    });
  }

  Future<void> _load() async {
    try {
      final collections = await _api.collections();
      if (!mounted) return;
      setState(() {
        _collections = collections;
        _selectedId = collections.any((item) => item.id == _selectedId)
            ? _selectedId
            : collections.firstOrNull?.id;
        _loading = false;
        _error = null;
      });
      await _loadEntries();
      _queuedShare ??= await QuickCaptureBridge.takePending();
      if (_queuedShare != null && mounted) {
        final shared = _queuedShare!;
        _queuedShare = null;
        await _showQuickCapture(shared);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.toString();
        });
      }
    }
  }

  Future<void> _editSavedView(
    BrainyCollection collection, [
    Map<String, dynamic>? view,
  ]) async {
    final updated = await showSavedViewEditor(
      context,
      api: _api,
      collection: collection,
      existing: view,
      search: _search,
      formatId: _filterFormatId,
      filterFieldId: _filterFieldId,
      filterOperator: _filterOperator,
      filterValue: _filterValue,
    );
    if (!mounted || updated == null) return;
    setState(() {
      _collections = _collections
          .map((item) => item.id == updated.id ? updated : item)
          .toList();
      _selectedViewId =
          view?['id'] as String? ?? updated.savedViews.last['id'] as String?;
    });
    await _loadEntries();
  }

  Future<void> _deleteSavedView(
    BrainyCollection collection,
    Map<String, dynamic> view,
  ) async {
    try {
      final updated = await _api.deleteView(
        collection.id,
        view['id'] as String,
      );
      if (!mounted) return;
      setState(() {
        _collections = _collections
            .map((item) => item.id == updated.id ? updated : item)
            .toList();
        _selectedViewId = null;
      });
      await _loadEntries();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  void _select(BrainyCollection collection) {
    if (_selectedId == collection.id) return;
    setState(() {
      _selectedId = collection.id;
      _entries = [];
      _pageCursor = null;
      _filterFormatId = null;
      _filterFieldId = null;
      _filterValue = '';
      _search = '';
      _selectedViewId = null;
    });
    _searchController.clear();
    _filterController.clear();
    _loadEntries();
  }

  Future<void> _createCollection() async {
    final collection = await showStarterDialog(context, _api);
    if (!mounted || collection == null) return;
    setState(() {
      _collections = [collection, ..._collections];
      _selectedId = collection.id;
      _entries = [];
    });
  }

  Future<void> _createCollectionManually() async {
    final collection = await showDialog<BrainyCollection>(
      context: context,
      builder: (context) => _CollectionEditor(api: _api),
    );
    if (!mounted || collection == null) return;
    setState(() {
      _collections = [collection, ..._collections];
      _selectedId = collection.id;
      _entries = [];
    });
  }

  Future<void> _showInsights(BrainyCollection collection) async {
    final updated = await showInsightsDialog(
      context,
      _api,
      collection,
      onOpenEntry: (entryId) async {
        final entry = await _api.entry(collection.id, entryId);
        if (mounted) await _editEntry(entry);
      },
    );
    if (!mounted || updated == null) return;
    setState(
      () => _collections = [
        for (final item in _collections) item.id == updated.id ? updated : item,
      ],
    );
  }

  Future<void> _addFormat() async {
    final collection = _selected;
    if (collection == null) return;
    final updated = await showDialog<BrainyCollection>(
      context: context,
      builder: (context) =>
          _CollectionEditor(api: _api, collection: collection),
    );
    if (!mounted || updated == null) return;
    setState(() {
      _collections = [
        for (final item in _collections) item.id == updated.id ? updated : item,
      ];
    });
  }

  Future<void> _editFormat(BrainyFormat format) async {
    final collection = _selected;
    if (collection == null) return;
    final updated = await showDialog<BrainyCollection>(
      context: context,
      builder: (context) => _CollectionEditor(
        api: _api,
        collection: collection,
        editingFormat: format,
      ),
    );
    if (!mounted || updated == null) return;
    setState(
      () => _collections = [
        for (final item in _collections) item.id == updated.id ? updated : item,
      ],
    );
  }

  Future<void> _changeFormatColor(BrainyFormat format) async {
    final collection = _selected;
    if (collection == null) return;
    var chosen = format.color;
    final color = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(_t('Change color')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_displayFormatName(context, format)),
              const SizedBox(height: 10),
              Text(
                _t(
                  'Every entry in this data format uses this soft background.',
                ),
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (
                    var index = 0;
                    index < brainyFormatColors.length;
                    index++
                  )
                    Builder(
                      builder: (context) {
                        final option = brainyFormatColors[index];
                        final used = collection.formats.any(
                          (item) =>
                              item.id != format.id && item.color == option,
                        );
                        return Tooltip(
                          message: '${_t('Color')} ${index + 1}',
                          child: InkWell(
                            onTap: used
                                ? null
                                : () => update(() => chosen = option),
                            borderRadius: BorderRadius.circular(10),
                            child: Opacity(
                              opacity: used ? 0.35 : 1,
                              child: Container(
                                width: 39,
                                height: 39,
                                decoration: BoxDecoration(
                                  color: _pastelColor(option),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: chosen == option
                                        ? _blue
                                        : const Color(0xFFCCD9E7),
                                    width: chosen == option ? 2.5 : 1,
                                  ),
                                ),
                                child: chosen == option
                                    ? const Icon(
                                        Icons.check_rounded,
                                        size: 20,
                                        color: _blue,
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_t('Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, chosen),
              child: Text(_t('Save')),
            ),
          ],
        ),
      ),
    );
    if (!mounted || color == null || color == format.color) return;
    try {
      final updated = await _api.setFormatColor(
        collection.id,
        format.id,
        color,
      );
      if (mounted) {
        setState(
          () => _collections = [
            for (final item in _collections)
              item.id == updated.id ? updated : item,
          ],
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _editEntry([BrainyEntry? entry, String? initialFormatId]) async {
    final collection = _selected;
    if (collection == null) return;
    if (entry != null && collection.formatFor(entry).appendOnly) {
      await showLedgerScreen(context, _api, collection, french: _copy.isFrench, userId: widget.user.id);
      if (mounted) await _load();
      return;
    }
    final saved = await showDialog<BrainyEntry>(
      context: context,
      builder: (context) => _EntryEditor(
        api: _api,
        collection: collection,
        userId: widget.user.id,
        entry: entry,
        initialFormatId: initialFormatId,
      ),
    );
    if (!mounted || saved == null || _selectedId != collection.id) return;
    if (saved.offlinePending) {
      setState(() { _entries = [saved, ..._entries.where((item) => item.id != saved.id)]; _error = _copy.isFrench ? 'Entrée conservée sur cet appareil, en attente de synchronisation' : 'Entry kept on this device, waiting to sync'; });
    } else { await _loadEntries(); }
  }

  Future<void> _manageObjects() async {
    final collection = _selected;
    if (collection == null) return;
    final request = await showDialog<ObjectEditorRequest>(
      context: context,
      builder: (context) => ObjectDialog(
        collection: collection,
        api: _api,
        onCollection: (updated) {
          if (mounted) {
            setState(
              () => _collections = [
                for (final item in _collections)
                  item.id == updated.id ? updated : item,
              ],
            );
          }
        },
        onEntriesChanged: () {
          if (mounted) _loadEntries();
        },
      ),
    );
    if (!mounted || request == null) return;
    await _editEntry(request.entry, request.formatId);
  }

  Future<bool> _confirm(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(_t('Cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(_t('Delete')),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _deleteEntry(BrainyEntry entry) async {
    if (_selected?.formatFor(entry).appendOnly == true) {
      await _editEntry(entry);
      return;
    }
    if (!await _confirm(
      _t('Delete entry?'),
      _t('This entry will be removed permanently.'),
    )) {
      return;
    }
    try {
      await _api.deleteEntry(entry.id);
      if (mounted) {
        setState(() => _entries.removeWhere((item) => item.id == entry.id));
      }
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _renameCollection() async {
    final collection = _selected;
    if (collection == null) return;
    final controller = TextEditingController(text: collection.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('Rename collection')),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 80,
          decoration: InputDecoration(labelText: _t('Collection name')),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_t('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(_t('Save')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;
    try {
      final updated = await _api.renameCollection(collection.id, name);
      if (mounted) {
        setState(() {
          _collections = [
            for (final item in _collections)
              item.id == updated.id ? updated : item,
          ];
        });
      }
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _deleteCollection() async {
    final collection = _selected;
    if (collection == null) return;
    if (!await _confirm(
      '${_t('Delete')} ${collection.name}?',
      _t('The collection and every entry in it will be removed permanently.'),
    )) {
      return;
    }
    try {
      await _api.deleteCollection(collection.id);
      if (!mounted) return;
      setState(() {
        _collections.removeWhere((item) => item.id == collection.id);
        _selectedId = _collections.firstOrNull?.id;
        _entries = [];
      });
      _loadEntries();
    } catch (error) {
      _showError(error);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(_copy.error(error))));
  }

  Future<void> _copyEntry(
    BrainyCollection collection,
    BrainyEntry entry,
  ) async {
    try {
      await Clipboard.setData(
        ClipboardData(text: entryClipboardText(collection, entry, _copy)),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(_t('Copied to clipboard'))));
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _downloadAttachment(BrainyEntry entry, BrainyField field) async {
    try {
      final attachment = await _api.entryAttachment(entry.id, field.id);
      final saved = await FilePicker.saveFile(
        fileName: attachment.fileName,
        bytes: attachment.bytes,
      );
      if (saved != null && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_t('File saved'))));
      }
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _openTransfer() async {
    BrainyTransfer? transfer;
    var includeSensitive = false;
    var targetNew = true;
    var busy = false;
    String? error;
    String? resultText;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, update) => AlertDialog(
          backgroundColor: _dark
              ? const Color(0xFF1C1F23)
              : const Color(0xFFF7FAFF),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Text(_t('Import and export')),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_selected != null) ...[
                    CheckboxListTile(value: includeSensitive, contentPadding: EdgeInsets.zero,
                      title: Text(_copy.isFrench ? 'Inclure explicitement les données personnelles et sensibles' : 'Explicitly include personal and sensitive data'),
                      onChanged: busy ? null : (value) => update(() => includeSensitive = value ?? false)),
                    Text(
                      _t('Export collection'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: busy
                              ? null
                              : () async {
                                  update(() => busy = true);
                                  try {
                                    final backup = await BrainyTransfer.export(
                                      _selected!,
                                      _api, includeSensitive: includeSensitive, french: _copy.isFrench,
                                    );
                                    final saved = await FilePicker.saveFile(
                                      fileName:
                                          'brainy-${_selected!.name}.json',
                                      bytes: Uint8List.fromList(
                                        utf8.encode(backup.json),
                                      ),
                                    );
                                    if (dialogContext.mounted &&
                                        saved != null) {
                                      update(
                                        () => resultText = _t('File saved'),
                                      );
                                    }
                                  } catch (cause) {
                                    if (dialogContext.mounted) {
                                      update(() => error = _copy.error(cause));
                                    }
                                  } finally {
                                    if (dialogContext.mounted) {
                                      update(() => busy = false);
                                    }
                                  }
                                },
                          child: Text(_t('Brainy backup (JSON)')),
                        ),
                        OutlinedButton(
                          onPressed: busy
                              ? null
                              : () async {
                                  update(() => busy = true);
                                  try {
                                    final backup = await BrainyTransfer.export(
                                      _selected!,
                                      _api, includeSensitive: includeSensitive, french: _copy.isFrench,
                                    );
                                    final saved = await FilePicker.saveFile(
                                      fileName: 'brainy-${_selected!.name}.csv',
                                      bytes: Uint8List.fromList(
                                        utf8.encode(backup.csv()),
                                      ),
                                    );
                                    if (dialogContext.mounted &&
                                        saved != null) {
                                      update(
                                        () => resultText = _t('File saved'),
                                      );
                                    }
                                  } catch (cause) {
                                    if (dialogContext.mounted) {
                                      update(() => error = _copy.error(cause));
                                    }
                                  } finally {
                                    if (dialogContext.mounted) {
                                      update(() => busy = false);
                                    }
                                  }
                                },
                          child: Text(_t('Readable table (CSV)')),
                        ),
                        if (_selected!.formats.any(
                          (format) =>
                              format.fields.any(
                                (field) =>
                                    field.kind == BrainyFieldKind.longText,
                              ) &&
                              format.fields.any(
                                (field) =>
                                    field.kind == BrainyFieldKind.number &&
                                    [
                                      'ordre',
                                      'order',
                                    ].contains(field.name.toLowerCase()),
                              ),
                        ))
                          OutlinedButton(
                            onPressed: busy
                                ? null
                                : () async {
                                    update(() => busy = true);
                                    try {
                                      final backup =
                                          await BrainyTransfer.export(
                                            _selected!,
                                            _api, includeSensitive: includeSensitive, french: _copy.isFrench,
                                          );
                                      final saved = await FilePicker.saveFile(
                                        fileName:
                                            'brainy-${_selected!.name}.txt',
                                        bytes: Uint8List.fromList(
                                          utf8.encode(
                                            backup.bookText(
                                              french: _copy.isFrench,
                                            ),
                                          ),
                                        ),
                                      );
                                      if (dialogContext.mounted &&
                                          saved != null) {
                                        update(
                                          () => resultText = _t('File saved'),
                                        );
                                      }
                                    } catch (cause) {
                                      if (dialogContext.mounted) {
                                        update(
                                          () => error = _copy.error(cause),
                                        );
                                      }
                                    } finally {
                                      if (dialogContext.mounted) {
                                        update(() => busy = false);
                                      }
                                    }
                                  },
                            child: Text(
                              _copy.isFrench ? 'Texte du livre' : 'Book text',
                            ),
                          ),
                      ],
                    ),
                    const Divider(height: 30),
                  ],
                  Text(
                    _t('Import collection'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () async {
                            try {
                              final selected = await FilePicker.pickFile(
                                type: FileType.custom,
                                allowedExtensions: ['json'],
                              );
                              if (selected == null) return;
                              final bytes = await selected.readAsBytes();
                              if (bytes.length > 100000000) {
                                throw const FormatException(
                                  'File is too large (100 MB maximum)',
                                );
                              }
                              final parsed = BrainyTransfer.parse(
                                utf8.decode(bytes),
                              );
                              if (dialogContext.mounted) {
                                update(() {
                                  transfer = parsed;
                                  error = null;
                                  resultText = null;
                                });
                              }
                            } catch (cause) {
                              if (dialogContext.mounted) {
                                update(() => error = _copy.error(cause));
                              }
                            }
                          },
                    icon: const Icon(Icons.upload_file_outlined),
                    label: Text(_t('Choose a Brainy backup')),
                  ),
                  if (transfer != null) ...[
                    const SizedBox(height: 13),
                    Text(
                      '${transfer!.source['name']} · ${transfer!.entries.length} ${_t('entries')}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (_selected != null)
                      SwitchListTile.adaptive(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(_t('Create a new collection')),
                        subtitle: Text(
                          targetNew
                              ? _t('Create a new collection')
                              : '${_t('Add to this collection')}: ${_selected!.name}',
                        ),
                        value: targetNew,
                        onChanged: busy
                            ? null
                            : (value) => update(() => targetNew = value),
                      ),
                    Text(
                      _t('Field mapping'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    for (final format in transfer!.formats)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '${format['name']}: ${(format['fields'] as List).map((field) => (field as Map)['name']).join(' → ')}',
                          style: const TextStyle(color: _muted),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      _t('Importing again skips entries already copied.'),
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  if (resultText != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        resultText!,
                        style: const TextStyle(color: _blue),
                      ),
                    ),
                  if (busy)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: LinearProgressIndicator(),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(dialogContext),
              child: Text(_t('Close')),
            ),
            if (transfer != null)
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        update(() {
                          busy = true;
                          error = null;
                        });
                        BrainyCollection? target = targetNew ? null : _selected;
                        try {
                          target ??= await _api.createCollectionWithFormats(
                            transfer!.source['name'] as String,
                            [
                              for (final format in transfer!.formats)
                                {
                                  'name': format['name'],
                                  'color': format['color'],
                                  if (format['sensitivity'] != null) 'sensitivity': format['sensitivity'],
                                  'objectModel': format['objectModel'] == true,
                                  'fields': [
                                    for (final field
                                        in (format['fields'] as List)
                                            .cast<Map<String, dynamic>>())
                                      {
                                        'name': field['name'],
                                        'kind': field['kind'],
                                        if (field['sensitivity'] != null) 'sensitivity': field['sensitivity'],
                                        if (field['unit'] != null)
                                          'unit': field['unit'],
                                        if (field['options'] != null)
                                          'options': field['options'],
                                        if (field['codeListId'] != null)
                                          'codeListId': field['codeListId'],
                                      },
                                  ],
                                },
                            ],
                            units: transfer!.units,
                            codeLists: (transfer!.source['codeLists'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>(),
                            exchangeRates:
                                (transfer!.source['exchangeRates']
                                        as List<dynamic>)
                                    .cast<Map<String, dynamic>>(),
                          );
                          final preview = await transfer!.importInto(
                            target,
                            _api,
                            dryRun: true,
                          );
                          if (preview.errors.isNotEmpty) {
                            if (targetNew) {
                              await _api.deleteCollection(target.id);
                            }
                            throw FormatException(
                              preview.errors.take(10).join('\n'),
                            );
                          }
                          final outcome = await transfer!.importInto(
                            target,
                            _api,
                            dryRun: false,
                          );
                          if (!mounted || !dialogContext.mounted) return;
                          setState(() {
                            _collections = [
                              target!,
                              ..._collections.where(
                                (item) => item.id != target!.id,
                              ),
                            ];
                            _selectedId = target.id;
                          });
                          await _loadEntries();
                          if (dialogContext.mounted) {
                            update(() {
                              resultText =
                                  '${_t('Import complete')}: ${outcome.created} ${_t('created')}, ${outcome.skipped} ${_t('skipped')}';
                              error = outcome.errors.isEmpty
                                  ? null
                                  : outcome.errors.take(10).join('\n');
                            });
                          }
                        } catch (cause) {
                          if (dialogContext.mounted) {
                            update(() => error = _copy.error(cause));
                          }
                        } finally {
                          if (dialogContext.mounted) update(() => busy = false);
                        }
                      },
                child: Text(_t('Import entries')),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _manageUnits() async {
    final selected = _selected;
    if (selected == null) return;
    final updated = await showDialog<BrainyCollection>(
      context: context,
      builder: (context) => UnitDialog(collection: selected, api: _api),
    );
    if (!mounted || updated == null) return;
    setState(
      () => _collections = [
        for (final item in _collections) item.id == updated.id ? updated : item,
      ],
    );
    await _loadEntries();
  }

  Future<void> _manageClassifications() async {
    final selected = _selected;
    if (selected == null) return;
    final changed = await showClassificationScreen(context, _api, selected, _collections, french: _copy.isFrench);
    if (changed && mounted) await _load();
  }

  Future<void> _showGeoMap() async {
    final selected = _selected;
    if (selected == null) return;
    final changed = await showGeoMapView(context, _api, selected, french: _copy.isFrench, initialSearch: _search, filterFieldId: _filterFieldId, filterOperator: _filterOperator, filterValue: _filterValue, viewId: _selectedViewId, onOpenEntry: (id) async { await _editEntry(await _api.entry(selected.id, id)); });
    if (changed && mounted) await _loadEntries();
  }

  String _formatTimestamp(DateTime timestamp, {bool compact = false}) {
    final local = timestamp.toLocal();
    final formatting = MaterialLocalizations.of(context);
    final date = compact ? formatting.formatCompactDate(local) : formatting.formatFullDate(local);
    final time = formatting.formatTimeOfDay(
      TimeOfDay.fromDateTime(local),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    return '$date · $time';
  }

  Future<void> _showQuickCapture([Map<String, String>? shared]) async {
    if (_collections.isEmpty) return;
    final entry = await showQuickCaptureSheet(context, api: _api, collections: _collections, userId: widget.user.id, french: _copy.isFrench, incoming: shared, onOpenExisting: (collection, existing) { setState(() => _selectedId = collection.id); _editEntry(existing); });
    if (entry == null || !mounted) return;
    final owner = _collections.firstWhere((item) => item.formats.any((format) => format.id == entry.formatId), orElse: () => _selected ?? _collections.first);
    setState(() => _selectedId = owner.id);
    await _loadEntries();
  }

  Future<void> _showQuickEntry() async {
    final collection = _selected;
    if (collection == null) return;
    final entry = await showQuickEntrySheet(context, api: _api, collection: collection, userId: widget.user.id, french: _copy.isFrench);
    if (entry != null && mounted) await _loadEntries();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _dark ? BrainyColors.darkCanvas : BrainyColors.lightCanvas,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 860;
            return Row(
              children: [
                if (wide) SizedBox(width: 292, child: _sidebar()),
                Expanded(
                  child: Column(
                    children: [
                      _header(wide),
                      if (!wide && _collections.isNotEmpty)
                        _mobileCollectionPicker(),
                      Expanded(child: _content()),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _header(bool wide) => Container(
    height: 72,
    padding: EdgeInsets.symmetric(horizontal: wide ? 36 : 18),
    decoration: BoxDecoration(
      color: wide ? _panel : _dark ? BrainyColors.darkSidebar : BrainyColors.lightSidebar,
      border: Border(bottom: BorderSide(color: _panelBorder)),
    ),
    child: Row(
      children: [
        if (!wide) ...[
          const BrainyMark(size: 28),
          if (MediaQuery.sizeOf(context).width >= 350) ...[
            const SizedBox(width: 8),
            Text(
              'brainy',
              style: TextStyle(
                color: wide ? _panelInk : BrainyColors.navigationInk,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          const Spacer(),
        ] else ...[
          Expanded(
            child: Text(
              _t('Your workspace'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: wide ? _panelInk : BrainyColors.navigationInk,
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (MediaQuery.sizeOf(context).width > 1060)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                widget.user.name,
                style: TextStyle(color: _panelMuted),
              ),
            ),
        ],
        LanguageMenu(onChanged: widget.onLanguageChanged, onDark: !wide),
        if (MediaQuery.sizeOf(context).width >= 430)
          IconButton(tooltip: _copy.isFrench ? 'Capture rapide' : 'Quick capture', onPressed: _collections.isEmpty ? null : () => _showQuickCapture(), icon: Icon(Icons.add_link_rounded, color: wide ? _actionAccent : BrainyColors.navigationInk)),
        if (widget.themeButton != null) Theme(data: Theme.of(context).copyWith(colorScheme: Theme.of(context).colorScheme.copyWith(primary: wide ? _actionAccent : BrainyColors.navigationInk)), child: widget.themeButton!),
        if (MediaQuery.sizeOf(context).width >= 430)
          IconButton(
            tooltip: _t('Import and export'),
            onPressed: _openTransfer,
            icon: Icon(Icons.import_export_rounded, color: wide ? _actionAccent : BrainyColors.navigationInk),
          ),
        PopupMenuButton<String>(
          tooltip: _t('Account'),
          icon: CircleAvatar(
            backgroundColor: _dark
                ? const Color(0xFF35353A)
                : const Color(0xFFE6F1FC),
            child: Icon(Icons.person_outline, color: _actionAccent),
          ),
          onSelected: (value) {
            if (value == 'signout') widget.onSignOut();
            if (value == 'profile') widget.onEditProfile?.call();
            if (value == 'quickcapture') _showQuickCapture();
            if (value == 'transfer') _openTransfer();
            if (value == 'workspaceTools') {
              showWorkspaceToolsDialog(
                context,
                api: _api,
                collections: _collections,
                onRestored: () => _load(),
              );
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(enabled: false, child: Text(widget.user.email)),
            if (MediaQuery.sizeOf(context).width < 430 && _collections.isNotEmpty)
              PopupMenuItem(value: 'quickcapture', child: Text(_copy.isFrench ? 'Capture rapide' : 'Quick capture')),
            if (MediaQuery.sizeOf(context).width < 430)
              PopupMenuItem(value: 'transfer', child: Text(_t('Import and export'))),
            if (widget.onEditProfile != null)
              PopupMenuItem(value: 'profile', child: Text(_t('Edit profile'))),
            PopupMenuItem(value: 'signout', child: Text(_t('Sign out'))),
          ],
        ),
      ],
    ),
  );

  Widget _sidebar() => WorkspaceNavigation(
    collections: _collections, selectedId: _selectedId,
    onSelect: _select, onCreate: _createCollection,
  );

  Widget _mobileCollectionPicker() => WorkspaceMobileCollections(
    collections: _collections, selectedId: _selectedId, onSelect: _select,
    onCreate: _createCollection, onManual: _createCollectionManually, onTransfer: _openTransfer,
  );

  Widget _content() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _collections.isEmpty) {
      return _message(
        Icons.cloud_off_outlined,
        _copy.error(_error!),
        _t('Try again'),
        _load,
      );
    }
    if (_collections.isEmpty) {
      return Column(children: [Expanded(child: _message(
        Icons.library_add_outlined,
        _t(
          'Start with a collection. Give it a name and choose the fields you want to keep.',
        ),
        _t('Create collection'),
        _createCollection,
        secondaryAction: _copy.isFrench
            ? 'Créer manuellement'
            : 'Create manually',
        onSecondaryPressed: _createCollectionManually,
      )), OfflineSyncPanel(api: _api, userId: widget.user.id, collections: _collections, onSynced: () { _load(); })]);
    }
    final collection = _selected;
    if (collection == null) return const SizedBox.shrink();
    return RefreshIndicator(
      onRefresh: _loadEntries,
      child: ListView(
        padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.sizeOf(context).width < 760 ? 16 : 32,
          vertical: 26,
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1020),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _overviewBanner(collection),
                  OfflineSyncPanel(api: _api, userId: widget.user.id, collections: _collections, onSynced: () { _loadEntries(); }),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _t('Saved entries'),
                          maxLines: 2,
                          style: TextStyle(
                            color: _panelInk,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${_entries.length}${_pageCursor != null ? '+' : ''}',
                        style: TextStyle(color: _panelMuted, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _savedViewBar(collection),
                  if (_selectedView == null) _entrySearchTools(collection),
                  const SizedBox(height: 14),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _copy.error(_error!),
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  if (_loadingEntries)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_entries.isEmpty &&
                      _selectedView?['layout'] != 'CALENDAR')
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 38,
                      ),
                      decoration: BoxDecoration(
                        color: _panel,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _panelBorder),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: _dark
                                  ? BrainyColors.darkAccentSoft
                                  : const Color(0xFFE8F2FE),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.note_add_outlined,
                              color: _actionAccent,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _t('Nothing written yet'),
                            style: TextStyle(
                              color: _panelInk,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _t(
                              'Add an entry using the fields in this collection.',
                            ),
                            style: TextStyle(color: _panelMuted),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 18),
                          FilledButton(
                            onPressed: () => _editEntry(),
                            child: Text(_t('Write an entry')),
                          ),
                        ],
                      ),
                    )
                  else
                    _entryPresentation(collection),
                  if (!_loadingEntries &&
                      (_pageCursor != null || _previousPages.isNotEmpty))
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Wrap(
                          spacing: 8,
                          children: [
                            if (_previousPages.isNotEmpty)
                              OutlinedButton(
                                onPressed: _loadingMore ? null : _loadPreviousEntries,
                                child: Text(_copy.isFrench ? 'Page précédente' : 'Previous page'),
                              ),
                            if (_pageCursor != null)
                              OutlinedButton(
                                onPressed: _loadingMore ? null : _loadMoreEntries,
                                child: Text(_loadingMore
                                    ? _t('Loading...')
                                    : _copy.isFrench ? 'Page suivante' : 'Next page'),
                              ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 30),
                  _collectionFormat(collection),
                  const SizedBox(height: 18),
                  CollectionToolsHub(
                    collection: collection,
                    userId: widget.user.id,
                    isFrench: _copy.isFrench,
                    isDark: _dark,
                    onStock: () => showStockScreen(context, _api, collection, widget.user.id),
                    onLedger: () async {
                      await showLedgerScreen(context, _api, collection, french: _copy.isFrench, userId: widget.user.id);
                      if (mounted) await _load();
                    },
                    onInsights: () => _showInsights(collection),
                    onUnits: _manageUnits,
                    onObjects: _manageObjects,
                    onClassifications: _manageClassifications,
                    onSensitivity: () async {
                      if (await showSensitivityScreen(context, _api, collection, french: _copy.isFrench) && mounted) {
                        await _load();
                      }
                    },
                    onWorkflow: () async {
                      if (await showWorkflowScreen(context, _api, collection, widget.user.id, french: _copy.isFrench) && mounted) {
                        await _load();
                      }
                    },
                    onContributions: () async {
                      await showContributionScreen(context, _api, collection, french: _copy.isFrench);
                      if (mounted) await _load();
                    },
                    onMap: _showGeoMap,
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _savedViewBar(BrainyCollection collection) {
    final view = _selectedView;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 210,
          child: DropdownButtonFormField<String>(
            key: ValueKey('view-${collection.id}-$_selectedViewId'),
            initialValue: _selectedViewId ?? '',
            isExpanded: true,
            decoration: InputDecoration(
              labelText: _t('View'),
              border: const OutlineInputBorder(),
            ),
            items: [
              DropdownMenuItem(value: '', child: Text(_t('Default list'))),
              for (final item in collection.savedViews)
                DropdownMenuItem(
                  value: item['id'] as String,
                  child: Text(item['name'] as String),
                ),
            ],
            onChanged: (value) {
              setState(
                () => _selectedViewId = value?.isEmpty == true ? null : value,
              );
              _loadEntries();
            },
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => _editSavedView(collection),
          icon: const Icon(Icons.add, size: 18),
          label: Text(_t('Save a view')),
        ),
        if (view != null)
          OutlinedButton(
            onPressed: () => _editSavedView(collection, view),
            child: Text(_t('Edit view')),
          ),
        if (view != null)
          TextButton(
            onPressed: () => _deleteSavedView(collection, view),
            child: Text(_t('Delete view')),
          ),
      ],
    );
  }

  Widget _entryPresentation(BrainyCollection collection) {
    final view = _selectedView;
    if (view?['layout'] == 'CALENDAR') {
      return CalendarView(
        key: ValueKey('calendar-${view!['id']}-$_entryRequest'),
        api: _api,
        collection: collection,
        view: view,
        onEdit: (entry) => _editEntry(entry),
        onRemind: (entry) => showEntryReminderDialog(
          context,
          api: _api,
          collection: collection,
          entry: entry,
          push: _push,
          view: view,
        ),
      );
    }
    if (view?['layout'] == 'TASKS') {
      final doneId = view?['taskDoneFieldId'] as String?;
      final dueId = view?['taskDueFieldId'] as String?;
      final priorityId = view?['taskPriorityFieldId'] as String?;
      return Column(
        children: [
          for (final entry in _entries)
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                child: Row(
                  children: [
                    Checkbox(
                      value: entry.values[doneId] == 'true',
                      onChanged: (done) async {
                        try {
                          final updated = await _api.setTaskCompleted(
                            collection.id,
                            view!['id'] as String,
                            entry.id,
                            done ?? false,
                          );
                          if (mounted) {
                            setState(() {
                              _entries = _entries
                                  .map(
                                    (item) =>
                                        item.id == updated.id ? updated : item,
                                  )
                                  .toList();
                            });
                          }
                        } catch (error) {
                          if (mounted) {
                            setState(() => _error = error.toString());
                          }
                        }
                      },
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.values[collection
                                    .formatFor(entry)
                                    .fields
                                    .where(
                                      (field) =>
                                          field.kind == BrainyFieldKind.title,
                                    )
                                    .firstOrNull
                                    ?.id] ??
                                collection.formatFor(entry).name,
                            style: TextStyle(
                              decoration: entry.values[doneId] == 'true'
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          if (entry.values[dueId] != null)
                            Text(
                              '${_t('Due date')}: ${entry.values[dueId]}',
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (entry.values[priorityId] != null)
                      Text(
                        entry.values[priorityId]!,
                        style: const TextStyle(color: _muted),
                      ),
                    IconButton(
                      onPressed: () => showEntryReminderDialog(
                        context,
                        api: _api,
                        collection: collection,
                        entry: entry,
                        push: _push,
                        view: view,
                      ),
                      tooltip: _copy.isFrench ? 'Rappels' : 'Reminders',
                      icon: const Icon(Icons.notifications_outlined),
                    ),
                    IconButton(
                      onPressed: () => _editEntry(entry),
                      tooltip: collection.formatFor(entry).appendOnly ? (_copy.isFrench ? 'Ouvrir le registre' : 'Open register') : _t('Edit'),
                      icon: Icon(collection.formatFor(entry).appendOnly ? Icons.receipt_long_outlined : Icons.edit_outlined),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    }
    if (view?['layout'] == 'TABLE') {
      final ids = (view?['columnFieldIds'] as List<dynamic>? ?? const [])
          .cast<String>();
      final fields = collection.formats
          .expand((format) => format.fields)
          .toList();
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: [
            DataColumn(label: Text(_t('Data format'))),
            DataColumn(label: Text(_t('Created'))),
            for (final id in ids)
              DataColumn(
                label: Text(
                  fields.where((field) => field.id == id).firstOrNull?.name ??
                      id,
                ),
              ),
            DataColumn(label: Text(_t('Action'))),
          ],
          rows: [
            for (final entry in _entries)
              DataRow(
                cells: [
                  DataCell(Text(collection.formatFor(entry).name)),
                  DataCell(
                    Text(
                      MaterialLocalizations.of(context)
                          .formatMediumDate(entry.createdAt.toLocal()),
                    ),
                  ),
                  for (final id in ids) DataCell(Text(entry.values[id] ?? '—')),
                  DataCell(
                    TextButton(
                      onPressed: () => _editEntry(entry),
                      child: Text(collection.formatFor(entry).appendOnly ? (_copy.isFrench ? 'Ouvrir le registre' : 'Open register') : _t('Edit')),
                    ),
                  ),
                ],
              ),
          ],
        ),
      );
    }
    final groups = view?['groupByFormat'] == true
        ? collection.formats
              .where(
                (format) =>
                    _entries.any((entry) => entry.formatId == format.id),
              )
              .toList()
        : <BrainyFormat>[];
    if (groups.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final format in groups) ...[
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Text(
                format.name,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _viewCards(
              collection,
              _entries.where((entry) => entry.formatId == format.id).toList(),
              view?['layout'] == 'CARDS',
            ),
          ],
        ],
      );
    }
    return _viewCards(collection, _entries, view?['layout'] == 'CARDS');
  }

  Widget _viewCards(
    BrainyCollection collection,
    List<BrainyEntry> entries,
    bool cards,
  ) {
    if (!cards) {
      return Column(
        children: [for (final entry in entries) _entryCard(collection, entry)],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth >= 700
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            for (final entry in entries)
              SizedBox(width: width, child: _entryCard(collection, entry)),
          ],
        );
      },
    );
  }

  Widget _entrySearchTools(BrainyCollection collection) {
    final format = collection.formats
        .where((item) => item.id == _filterFormatId)
        .firstOrNull;
    final field = format?.fields
        .where((item) => item.id == _filterFieldId)
        .firstOrNull;
    final comparable =
        field != null &&
        [
          BrainyFieldKind.number,
          BrainyFieldKind.duration,
          BrainyFieldKind.date,
          BrainyFieldKind.datetime,
          BrainyFieldKind.time,
        ].contains(field.kind);
    final contains =
        field != null &&
        [
          BrainyFieldKind.title,
          BrainyFieldKind.text,
          BrainyFieldKind.longText,
          BrainyFieldKind.link,
          BrainyFieldKind.character,
          BrainyFieldKind.attachment,
        ].contains(field.kind);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _panel.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _panelBorder),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          SizedBox(
            width: 240,
            child: TextField(
              controller: _searchController,
              onChanged: (_) => _scheduleEntries(),
              decoration: InputDecoration(
                labelText: _t('Search entries'),
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          SizedBox(
            width: 185,
            child: DropdownButtonFormField<String>(
              key: ValueKey('format-$_selectedId-$_filterFormatId'),
              isExpanded: true,
              initialValue: _filterFormatId ?? '',
              decoration: InputDecoration(
                labelText: _t('Data format'),
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(
                  value: '',
                  child: Text(
                    _t('All data formats'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                for (final item in collection.formats)
                  DropdownMenuItem(
                    value: item.id,
                    child: Text(item.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (value) {
                setState(() {
                  _filterFormatId = value?.isEmpty == true ? null : value;
                  _filterFieldId = null;
                  _filterOperator = 'EQ';
                  _filterValue = '';
                  _filterController.clear();
                });
                _loadEntries();
              },
            ),
          ),
          if (format != null)
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<String>(
                key: ValueKey('field-$_filterFormatId-$_filterFieldId'),
                isExpanded: true,
                initialValue: _filterFieldId ?? '',
                decoration: InputDecoration(
                  labelText: _t('Filter by field'),
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(
                    value: '',
                    child: Text(
                      _t('No field filter'),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  for (final item in format.fields)
                    DropdownMenuItem(
                      value: item.id,
                      child: Text(item.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (value) {
                  setState(() {
                    _filterFieldId = value?.isEmpty == true ? null : value;
                    _filterOperator = 'EQ';
                    _filterValue = '';
                    _filterController.clear();
                  });
                  _loadEntries();
                },
              ),
            ),
          if (field != null)
            SizedBox(
              width: 150,
              child: DropdownButtonFormField<String>(
                key: ValueKey('operator-$_filterFieldId-$_filterOperator'),
                isExpanded: true,
                initialValue: _filterOperator,
                decoration: InputDecoration(
                  labelText: _t('Filter by field'),
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(value: 'EQ', child: Text(_t('Equals'))),
                  if (contains)
                    DropdownMenuItem(
                      value: 'CONTAINS',
                      child: Text(_t('Contains')),
                    ),
                  if (comparable) ...[
                    DropdownMenuItem(
                      value: 'GT',
                      child: Text(_t('Greater than')),
                    ),
                    DropdownMenuItem(value: 'LT', child: Text(_t('Less than'))),
                  ],
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _filterOperator = value);
                  _loadEntries();
                },
              ),
            ),
          if (field != null)
            SizedBox(
              width: 180,
              child:
                  field.kind == BrainyFieldKind.boolean ||
                      field.kind == BrainyFieldKind.select ||
                      field.kind == BrainyFieldKind.multiSelect
                  ? DropdownButtonFormField<String>(
                      key: ValueKey('value-$_filterFieldId-$_filterValue'),
                      isExpanded: true,
                      initialValue: _filterValue,
                      decoration: InputDecoration(
                        labelText: _t('Filter value'),
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(value: '', child: Text('—')),
                        for (final option
                            in field.kind == BrainyFieldKind.boolean
                                ? ['true', 'false']
                                : field.options)
                          DropdownMenuItem(
                            value: option,
                            child: Text(
                              option == 'true'
                                  ? _t('Yes')
                                  : option == 'false'
                                  ? _t('No')
                                  : option,
                            ),
                          ),
                      ],
                      onChanged: (value) {
                        setState(() => _filterValue = value ?? '');
                        _loadEntries();
                      },
                    )
                  : TextField(
                      controller: _filterController,
                      onChanged: (_) => _scheduleEntries(),
                      decoration: InputDecoration(
                        labelText: _t('Filter value'),
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                    ),
            ),
        ],
      ),
    );
  }

  Widget _overviewBanner(BrainyCollection collection) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [Color.lerp(_panel, _actionAccent, .06)!, _panel]),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: _panelBorder,
      ),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final heroOutlineStyle = OutlinedButton.styleFrom(
          foregroundColor: _actionAccent,
          backgroundColor: _panel,
          side: BorderSide(
            color: _dark ? BrainyColors.darkControl : BrainyColors.lightControl,
          ),
        );
        final action = FilledButton.icon(
          onPressed: () => _editEntry(),
          icon: const Icon(Icons.add_rounded, size: 20),
          label: Text(_t('New entry')),
          style: FilledButton.styleFrom(
            backgroundColor: _actionAccent,
            foregroundColor: _dark
                ? BrainyColors.darkOnAccent
                : BrainyColors.lightSurface,
            minimumSize: const Size(0, 46),
          ),
        );
        final quickAction = OutlinedButton.icon(
          onPressed: _showQuickEntry,
          icon: const Icon(Icons.bolt_rounded, size: 18),
          label: Text(_copy.isFrench ? 'Saisie rapide' : 'Quick entry'),
          style: heroOutlineStyle,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: _actionAccent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    Icons.folder_copy_outlined,
                    color: _panelInk,
                    size: 27,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _t('Collection').toUpperCase(),
                        style: TextStyle(
                          color: _panelMuted,
                          fontSize: 13,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        collection.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _panelInk,
                          fontSize: 27,
                          fontWeight: FontWeight.w800,
                          height: 1.12,
                          letterSpacing: -0.8,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        _t('Save information in your own data format.'),
                        style: TextStyle(
                          color: _panelMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(width: 14),
                  OutlinedButton.icon(
                    onPressed: () => _showInsights(collection),
                    icon: const Icon(Icons.auto_graph_rounded, size: 18),
                    label: Text(_copy.isFrench ? 'Calculs' : 'Insights'),
                    style: heroOutlineStyle,
                  ),
                  const SizedBox(width: 8),
                  quickAction,
                  const SizedBox(width: 8),
                  action,
                ],
              ],
            ),
            if (compact) ...[
              const SizedBox(height: 18),
              SizedBox(width: double.infinity, child: action),
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, child: quickAction),
            ],
            const SizedBox(height: 20),
            Wrap(
              spacing: 9,
              runSpacing: 9,
              children: [
                _statBadge(
                  Icons.grid_view_rounded,
                  '${collection.formats.length} ${_t(collection.formats.length == 1 ? 'data format' : 'data formats')}',
                ),
                _statBadge(
                  Icons.notes_rounded,
                  '${_entries.length} ${_t(_entries.length == 1 ? 'entry' : 'entries')} ${_copy.isFrench ? 'sur cette page' : 'on this page'}',
                ),
              ],
            ),
          ],
        );
      },
    ),
  );

  Widget _statBadge(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
    decoration: BoxDecoration(
      color: _actionAccent.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: _actionAccent, size: 15),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _panelInk,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _collectionFormat(BrainyCollection collection) => WorkspaceFormatCards(
    collection: collection,
    entryCounts: {for (final format in collection.formats) format.id: _entries.where((entry) => entry.formatId == format.id).length},
    partialCounts: _loadingEntries || _pageCursor != null || _previousPages.isNotEmpty || _search.isNotEmpty || _filterFormatId != null || _filterFieldId != null || _selectedViewId != null,
    onAdd: _addFormat, onAddEntry: (format) => _editEntry(null, format.id),
    onEdit: _editFormat, onColor: _changeFormatColor,
    onCopy: (format) async { if (await showCopyToCollection(context, api: _api, source: collection, formatId: format.id)) await _load(); },
    onLink: (format) async { if (await showCopyToCollection(context, api: _api, source: collection, formatId: format.id, link: true)) await _load(); },
    onReview: (format) async { if (await showLinkedFormatUpdate(context, api: _api, collection: collection, format: format)) await _load(); },
    onRename: _renameCollection, onDelete: _deleteCollection,
  );

  Widget _message(
    IconData icon,
    String message,
    String action,
    VoidCallback onPressed, {
    String? secondaryAction,
    VoidCallback? onSecondaryPressed,
  }) => Center(
    child: Padding(
      padding: const EdgeInsets.all(25),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54, color: _blue),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: _panelInk, fontSize: 19, height: 1.4),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: onPressed, child: Text(action)),
            if (secondaryAction != null && onSecondaryPressed != null) ...[
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: onSecondaryPressed,
                child: Text(secondaryAction),
              ),
            ],
          ],
        ),
      ),
    ),
  );

  Future<void> _showEntryDetails(BrainyCollection collection, BrainyEntry entry) async {
    final format = collection.formatFor(entry);
    final edited = entry.updatedAt.isAfter(entry.createdAt.add(const Duration(seconds: 2)));
    final shouldEdit = await showEntryDetailsDialog(
      context,
      collection: collection,
      entry: entry,
      formatName: _displayFormatName(context, format),
      created: _formatTimestamp(entry.createdAt),
      edited: edited ? _formatTimestamp(entry.updatedAt) : null,
      copy: _copy,
      onCopy: () => _copyEntry(collection, entry),
      onReference: (field) => _showObjectReferences(entry, field),
      onAttachment: (field) => _downloadAttachment(entry, field),
      onLink: _openSavedLink,
    );
    if (shouldEdit && mounted) await _editEntry(entry);
  }

  Widget _entryCard(BrainyCollection collection, BrainyEntry entry) {
    final format = collection.formatFor(entry);
    final visible = format.fields.where((field) => entry.values[field.id]?.trim().isNotEmpty ?? false);
    final titleField = visible.where((field) => field.kind == BrainyFieldKind.title).firstOrNull;
    final firstField = visible.firstOrNull;
    final previewField = visible.where((field) => field.id != titleField?.id && field.kind != BrainyFieldKind.attachment && field.kind != BrainyFieldKind.objectRef).firstOrNull;
    final title = titleField != null ? entry.values[titleField.id]! : firstField != null ? displayEntryValue(firstField, entry.values[firstField.id]!, _copy, snapshot: entry.unitSnapshots[firstField.id], collection: collection) : _displayFormatName(context, format);
    return WorkspaceEntryRow(
      key: ValueKey(entry.id), color: format.color, title: title,
      formatName: _displayFormatName(context, format), appendOnly: format.appendOnly,
      preview: titleField != null && previewField != null ? displayEntryValue(previewField, entry.values[previewField.id]!, _copy, snapshot: entry.unitSnapshots[previewField.id], collection: collection) : null,
      created: _formatTimestamp(entry.createdAt, compact: true),
      edited: entry.updatedAt.isAfter(entry.createdAt.add(const Duration(seconds: 2))) ? _formatTimestamp(entry.updatedAt, compact: true) : null,
      onDetails: () => _showEntryDetails(collection, entry),
      onAction: (action) {
        if (action == 'copy') _copyEntry(collection, entry);
        if (action == 'edit') _editEntry(entry);
        if (action == 'reminder') showEntryReminderDialog(context, api: _api, collection: collection, entry: entry, push: _push, view: _selectedView);
        if (action == 'links') showEntryLinksDialog(context, _api, collection, entry).then((linked) { if (linked != null && mounted) _editEntry(linked); });
        if (action == 'delete') _deleteEntry(entry);
      },
    );
  }

  Future<void> _showObjectReferences(
    BrainyEntry entry,
    BrainyField field,
  ) async {
    try {
      final references = await _api.entryObjectReferences(entry.id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(field.name),
          content: SizedBox(
            width: 480,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final reference in references.where(
                  (item) => item['fieldId'] == field.id,
                ))
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            reference['name'] as String? ??
                                reference['objectId'] as String,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            reference['mode'] == 'SNAPSHOT'
                                ? (_copy.isFrench
                                      ? 'Valeurs figées'
                                      : 'Snapshot')
                                : (_copy.isFrench
                                      ? 'Valeurs actuelles'
                                      : 'Current values'),
                          ),
                          if (reference['missing'] == true)
                            Text(
                              _copy.isFrench
                                  ? 'Objet indisponible'
                                  : 'Object unavailable',
                            )
                          else
                            for (final property
                                in (reference['properties'] as List<dynamic>)
                                    .cast<Map<String, dynamic>>())
                              Text(
                                '${property['name']}: ${property['value']}${property['unitSnapshot'] is Map<String, dynamic> ? ' ${(property['unitSnapshot'] as Map<String, dynamic>)['symbol']}' : ''}',
                              ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_t('Close')),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_copy.error(error))));
      }
    }
  }

  Future<void> _openSavedLink(String value) async {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !['http', 'https'].contains(uri.scheme)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _copy.isFrench ? 'Lien web invalide' : 'Invalid web link',
          ),
        ),
      );
      return;
    }
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('Could not open link');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _copy.isFrench
                  ? 'Impossible d’ouvrir le lien'
                  : 'Could not open link',
            ),
          ),
        );
      }
    }
  }

}

class _DraftField {
  _DraftField({
    String name = '',
    this.kind = BrainyFieldKind.text,
    this.id,
    String options = '',
  }) : controller = TextEditingController(text: name),
       optionsController = TextEditingController(text: options);
  final String? id;
  final TextEditingController controller;
  final TextEditingController customUnit = TextEditingController();
  final TextEditingController optionsController;
  final TextEditingController variableController = TextEditingController();
  BrainyFieldKind kind;
  String? targetObjectFormatId;
  bool multiple = false;
  String referenceMode = 'SNAPSHOT';
  String? codeListId;
  String unitChoice = '';
  String? get unit => unitChoice == 'custom'
      ? customUnit.text.trim()
      : (unitChoice.isEmpty ? null : unitChoice);

  void dispose() {
    controller.dispose();
    customUnit.dispose();
    optionsController.dispose();
    variableController.dispose();
  }
}

class _CollectionEditor extends StatefulWidget {
  const _CollectionEditor({
    required this.api,
    this.collection,
    this.editingFormat,
  });
  final CollectionsApi api;
  final BrainyCollection? collection;
  final BrainyFormat? editingFormat;
  @override
  State<_CollectionEditor> createState() => _CollectionEditorState();
}

class _CollectionEditorState extends State<_CollectionEditor> {
  String _t(String value) => AppStrings.of(context).text(value);
  String _copyText(String french, String english) =>
      AppStrings.of(context).isFrench ? french : english;
  final _name = TextEditingController();
  final _formatName = TextEditingController();
  final List<_DraftField> _fields = [];
  bool _saving = false;
  bool _objectModel = false;
  String? _error;

  String? _selectedColor;
  ({int entryCount, List<String> populatedFieldIds})? _impact;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_formatName.text.isEmpty) {
      _formatName.text =
          widget.editingFormat?.name ??
          '${_t('Data format')} ${widget.collection == null ? 1 : widget.collection!.formats.length + 1}';
    }
    if (_fields.isEmpty) {
      if (widget.editingFormat case final format?) {
        _selectedColor = format.color;
        for (final field in format.fields) {
          final draft = _DraftField(
            id: field.id,
            name: field.name,
            kind: field.kind,
            options: field.options.join('\n'),
          );
          if (field.unit != null) {
            if (numberUnit(field.unit) == null &&
                !field.unit!.startsWith('local:')) {
              draft.unitChoice = 'custom';
              draft.customUnit.text = field.unit!;
            } else {
              draft.unitChoice = field.unit!;
            }
          }
          draft.targetObjectFormatId = field.targetObjectFormatId;
          draft.multiple = field.multiple;
          draft.variableController.text = field.variableName ?? '';
          draft.referenceMode = field.referenceMode;
          draft.codeListId = field.codeListId;
          _fields.add(draft);
        }
        widget.api
            .formatImpact(widget.collection!.id, format.id)
            .then((impact) {
              if (mounted) setState(() => _impact = impact);
            })
            .catchError((Object error) {
              if (mounted) {
                setState(() => _error = AppStrings.of(context).error(error));
              }
            });
      } else {
        _fields.add(
          _DraftField(name: _t('Title'), kind: BrainyFieldKind.title),
        );
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _formatName.dispose();
    for (final field in _fields) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final formatName = _formatName.text.trim();
    final fields = [
      for (final item in _fields)
        (
          name: item.controller.text.trim(),
          kind: item.kind,
          unit: item.kind == BrainyFieldKind.number ? item.unit : null,
          options:
              item.kind == BrainyFieldKind.select ||
                  item.kind == BrainyFieldKind.multiSelect
              ? item.optionsController.text
                    .split('\n')
                    .map((value) => value.trim())
                    .where((value) => value.isNotEmpty)
                    .toList()
              : null,
        ),
    ];
    if (formatName.isEmpty) {
      setState(() => _error = 'Name the data format.');
      return;
    }
    if (_objectModel &&
        !fields.any((field) => field.kind == BrainyFieldKind.title)) {
      setState(
        () => _error = AppStrings.of(context).isFrench
            ? 'Un modèle d’objet a besoin d’un champ titre.'
            : 'An object model needs a title field.',
      );
      return;
    }
    if (_selectedColor == null && widget.editingFormat == null) {
      setState(() => _error = 'Choose a color for this data format.');
      return;
    }
    if ((widget.collection == null && name.isEmpty) ||
        fields.any((item) => item.name.isEmpty)) {
      setState(() => _error = 'Name the collection and every field.');
      return;
    }
    if (fields.map((item) => item.name.toLowerCase()).toSet().length !=
        fields.length) {
      setState(() => _error = 'Field names must be unique.');
      return;
    }
    if (_fields.any(
      (item) =>
          item.kind == BrainyFieldKind.number &&
          item.unitChoice == 'custom' &&
          (item.unit?.isEmpty ?? true),
    )) {
      setState(() => _error = 'Enter a unit');
      return;
    }
    if (_fields.any((item) => item.unit != null && item.unit!.length > 24)) {
      setState(() => _error = 'A unit can be at most 24 characters.');
      return;
    }
    if (fields.any(
      (item) =>
          item.options != null &&
          (item.options!.length < 2 ||
              item.options!.length > 30 ||
              item.options!
                      .map((value) => value.toLowerCase())
                      .toSet()
                      .length !=
                  item.options!.length),
    )) {
      setState(() => _error = _t('Add 2 to 30 different choices.'));
      return;
    }
    if (_fields.any(
      (field) =>
          field.kind == BrainyFieldKind.objectRef &&
          field.targetObjectFormatId == null,
    )) {
      setState(
        () => _error = _copyText(
          'Choisissez un modèle d’objets.',
          'Choose an object model.',
        ),
      );
      return;
    }
    if (_fields.any((field) => field.kind == BrainyFieldKind.code && field.codeListId == null)) {
      setState(() => _error = _copyText('Choisissez une liste de codes de cette collection.', 'Choose a code list in this collection.'));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final collection = widget.editingFormat != null
          ? await widget.api.updateFormat(
              widget.collection!.id,
              widget.editingFormat!,
              formatName,
              [
                for (var index = 0; index < _fields.length; index++)
                  {
                    if (_fields[index].id != null) 'id': _fields[index].id,
                    'name': fields[index].name,
                    'kind': fields[index].kind.wireName,
                    if (fields[index].unit != null) 'unit': fields[index].unit,
                    if (fields[index].options != null)
                      'options': fields[index].options,
                    if (_fields[index].kind == BrainyFieldKind.code)
                      'codeListId': _fields[index].codeListId,
                    if (_fields[index].kind == BrainyFieldKind.objectRef) ...{
                      'targetObjectFormatId':
                          _fields[index].targetObjectFormatId,
                      'multiple': _fields[index].multiple,
                      'variableName': _fields[index].variableController.text
                          .trim(),
                      'referenceMode': _fields[index].referenceMode,
                    },
                  },
              ],
            )
          : widget.collection == null
          ? await widget.api.createCollection(
              name,
              fields,
              formatName: formatName,
              color: _selectedColor!,
              objectModel: _objectModel,
            )
          : _fields.any((field) => field.kind == BrainyFieldKind.code)
          ? await widget.api.addFormatWithCode(widget.collection!.id, formatName, _selectedColor!, [for (var index = 0; index < fields.length; index++) {'name': fields[index].name, 'kind': fields[index].kind.wireName, if (fields[index].unit != null) 'unit': fields[index].unit, if (fields[index].options != null) 'options': fields[index].options, if (_fields[index].kind == BrainyFieldKind.code) 'codeListId': _fields[index].codeListId}], objectModel: _objectModel)
          : await widget.api.addFormat(widget.collection!.id, formatName, _selectedColor!, fields, objectModel: _objectModel);
      if (mounted) Navigator.pop(context, collection);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = AppStrings.of(context).error(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560, maxHeight: 700),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t(
                widget.collection == null
                    ? 'Create a collection'
                    : widget.editingFormat == null
                    ? 'Add data format'
                    : 'Edit data format',
              ),
              style: TextStyle(
                color: _dialogInk(context),
                fontSize: 23,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              _t(
                widget.collection == null
                    ? 'Choose what each entry can hold. Keep one field or mix several types.'
                    : widget.editingFormat == null
                    ? 'Give this data format a name and choose its fields.'
                    : 'Rename, reorder or add fields. Saved values stay safe.',
              ),
              style: TextStyle(color: _dialogMuted(context)),
            ),
            const SizedBox(height: 22),
            Expanded(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  if (widget.collection == null)
                    TextField(
                      controller: _name,
                      maxLength: 80,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: _t('Collection name'),
                        hintText: _t('Ideas, recipes, contacts…'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  TextField(
                    controller: _formatName,
                    maxLength: 80,
                    autofocus: widget.collection != null,
                    decoration: InputDecoration(
                      labelText: _t('Data format name'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  if (widget.editingFormat != null) ...[
                    Text(
                      '${_t('Entries using this data format')}: ${_impact?.entryCount ?? '…'}',
                      style: TextStyle(color: _dialogMuted(context)),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (widget.editingFormat == null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _t('Data format color'),
                      style: TextStyle(
                        color: _dialogInk(context),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _t(
                        'Every entry in this data format uses this soft background.',
                      ),
                      style: TextStyle(
                        color: _dialogMuted(context),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (
                          var index = 0;
                          index < brainyFormatColors.length;
                          index++
                        )
                          Builder(
                            builder: (context) {
                              final color = brainyFormatColors[index];
                              final used =
                                  widget.collection?.formats.any(
                                    (format) => format.color == color,
                                  ) ??
                                  false;
                              return Tooltip(
                                message: '${_t('Color')} ${index + 1}',
                                child: InkWell(
                                  onTap: used
                                      ? null
                                      : () => setState(
                                          () => _selectedColor = color,
                                        ),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Opacity(
                                    opacity: used ? 0.35 : 1,
                                    child: Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        color: _pastelColor(color),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: _selectedColor == color
                                              ? _blue
                                              : const Color(0xFFCCD9E7),
                                          width: _selectedColor == color
                                              ? 2.5
                                              : 1,
                                        ),
                                      ),
                                      child: _selectedColor == color
                                          ? const Icon(
                                              Icons.check_rounded,
                                              size: 20,
                                              color: _blue,
                                            )
                                          : null,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    _t('FIELDS'),
                    style: TextStyle(
                      color: _dialogMuted(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (var index = 0; index < _fields.length; index++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final narrow = constraints.maxWidth < 420;
                          final protected =
                              _fields[index].id != null &&
                              (_impact?.populatedFieldIds.contains(
                                    _fields[index].id,
                                  ) ??
                                  false);
                          final name = TextField(
                            controller: _fields[index].controller,
                            maxLength: 80,
                            decoration: InputDecoration(
                              labelText: '${_t('Field')} ${index + 1}',
                              counterText: '',
                              border: const OutlineInputBorder(),
                            ),
                          );
                          final kind = DropdownButtonFormField<BrainyFieldKind>(
                            key: ObjectKey(_fields[index]),
                            initialValue: _fields[index].kind,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: _t('Type'),
                              border: const OutlineInputBorder(),
                            ),
                            items: [
                              for (final type in BrainyFieldKind.values)
                                if ((type != BrainyFieldKind.code || (widget.collection?.codeLists.isNotEmpty ?? false)) &&
                                    (type != BrainyFieldKind.objectRef ||
                                    (widget.editingFormat != null &&
                                        (widget.collection!.formats.any(
                                              (format) => format.objectModel,
                                            ) ||
                                            widget.collection!.sharedObjects
                                                .any(
                                                  (grant) =>
                                                      grant['revokedAt'] ==
                                                      null,
                                                )))))
                                  DropdownMenuItem(
                                    value: type,
                                    child: Text(_t(type.label)),
                                  ),
                            ],
                            onChanged: protected
                                ? null
                                : (type) {
                                    if (type != null) {
                                      setState(() { _fields[index].kind = type; _fields[index].codeListId = null; });
                                    }
                                  },
                          );
                          final remove = IconButton(
                            tooltip: _t('Remove field'),
                            onPressed: _fields.length == 1 || protected
                                ? null
                                : () => setState(() {
                                    _fields.removeAt(index).dispose();
                                  }),
                            icon: const Icon(Icons.close),
                          );
                          final fieldRow = narrow
                              ? Column(
                                  children: [
                                    name,
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(child: kind),
                                        remove,
                                      ],
                                    ),
                                  ],
                                )
                              : Row(
                                  children: [
                                    Expanded(flex: 3, child: name),
                                    const SizedBox(width: 8),
                                    Expanded(flex: 2, child: kind),
                                    remove,
                                  ],
                                );
                          final field = _fields[index];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              fieldRow,
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    tooltip: _t('Move up'),
                                    onPressed: index == 0
                                        ? null
                                        : () => setState(() {
                                            final item = _fields.removeAt(
                                              index,
                                            );
                                            _fields.insert(index - 1, item);
                                          }),
                                    icon: const Icon(
                                      Icons.arrow_upward,
                                      size: 18,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: _t('Move down'),
                                    onPressed: index == _fields.length - 1
                                        ? null
                                        : () => setState(() {
                                            final item = _fields.removeAt(
                                              index,
                                            );
                                            _fields.insert(index + 1, item);
                                          }),
                                    icon: const Icon(
                                      Icons.arrow_downward,
                                      size: 18,
                                    ),
                                  ),
                                ],
                              ),
                              if (field.kind == BrainyFieldKind.select ||
                                  field.kind == BrainyFieldKind.multiSelect)
                                TextField(
                                  controller: field.optionsController,
                                  enabled: true,
                                  minLines: 2,
                                  maxLines: 5,
                                  decoration: InputDecoration(
                                    labelText: _t('Choices (one per line)'),
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                              if (field.kind == BrainyFieldKind.code && widget.collection != null)
                                DropdownButtonFormField<String>(
                                  initialValue: field.codeListId,
                                  decoration: InputDecoration(labelText: _copyText('Liste de codes locale', 'Local code list'), border: const OutlineInputBorder()),
                                  items: [for (final list in widget.collection!.codeLists) DropdownMenuItem(value: list['id'] as String, child: Text(list['name'] as String))],
                                  onChanged: protected ? null : (value) => setState(() => field.codeListId = value),
                                ),
                              if (field.kind == BrainyFieldKind.objectRef) ...[
                                const SizedBox(height: 10),
                                DropdownButtonFormField<String>(
                                  initialValue: field.targetObjectFormatId,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    labelText: _copyText(
                                      'Modèle d’objets cible',
                                      'Target object model',
                                    ),
                                    border: const OutlineInputBorder(),
                                  ),
                                  items: [
                                    for (final model
                                        in widget.collection!.formats)
                                      if (model.objectModel)
                                        DropdownMenuItem(
                                          value: model.id,
                                          child: Text(model.name),
                                        ),
                                    for (final grant in {
                                      for (final item
                                          in widget.collection!.sharedObjects)
                                        if (item['revokedAt'] == null)
                                          item['sourceFormatId'] as String:
                                              item,
                                    }.values)
                                      DropdownMenuItem(
                                        value:
                                            grant['sourceFormatId'] as String,
                                        child: Text(
                                          '${grant['sourceName']} · ${grant['objectName']}',
                                        ),
                                      ),
                                  ],
                                  onChanged: protected
                                      ? null
                                      : (value) => setState(
                                          () => field.targetObjectFormatId =
                                              value,
                                        ),
                                ),
                                TextField(
                                  controller: field.variableController,
                                  maxLength: 40,
                                  decoration: InputDecoration(
                                    labelText: _copyText(
                                      'Variable d’objet (facultatif)',
                                      'Object variable (optional)',
                                    ),
                                    hintText: 'produit',
                                  ),
                                ),
                                SwitchListTile(
                                  value: field.multiple,
                                  title: Text(
                                    _copyText(
                                      'Plusieurs objets',
                                      'Multiple objects',
                                    ),
                                  ),
                                  onChanged: protected
                                      ? null
                                      : (value) => setState(
                                          () => field.multiple = value,
                                        ),
                                ),
                                DropdownButtonFormField<String>(
                                  initialValue: field.referenceMode,
                                  decoration: InputDecoration(
                                    labelText: _copyText(
                                      'Valeurs des propriétés',
                                      'Property values',
                                    ),
                                  ),
                                  items: [
                                    DropdownMenuItem(
                                      value: 'SNAPSHOT',
                                      child: Text(
                                        _copyText(
                                          'Figées à l’enregistrement',
                                          'Snapshot when saved',
                                        ),
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'CURRENT',
                                      child: Text(
                                        _copyText(
                                          'Valeurs actuelles',
                                          'Current values',
                                        ),
                                      ),
                                    ),
                                  ],
                                  onChanged: protected
                                      ? null
                                      : (value) => setState(
                                          () => field.referenceMode =
                                              value ?? 'SNAPSHOT',
                                        ),
                                ),
                              ],
                              if (field.kind == BrainyFieldKind.number) ...[
                                const SizedBox(height: 10),
                                DropdownButtonFormField<String>(
                                  key: ObjectKey(field.customUnit),
                                  initialValue: field.unitChoice,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    labelText: _t('Unit'),
                                    helperText: _t(
                                      'Choose a unit or leave the number plain.',
                                    ),
                                    border: const OutlineInputBorder(),
                                  ),
                                  items: [
                                    DropdownMenuItem(
                                      value: '',
                                      child: Text(_t('No unit')),
                                    ),
                                    DropdownMenuItem(
                                      value: 'custom',
                                      child: Text(_t('Custom unit')),
                                    ),
                                    for (final option in numberUnits)
                                      DropdownMenuItem(
                                        value: option.code,
                                        child: Text(
                                          unitChoiceLabel(
                                            AppStrings.of(context),
                                            option,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    for (final unit
                                        in widget.collection?.units ??
                                            <BrainyUnit>[])
                                      DropdownMenuItem(
                                        value: 'local:${unit.id}',
                                        child: Text(
                                          '${unit.name} (${unit.symbol})',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                  ],
                                  onChanged: protected
                                      ? null
                                      : (choice) => setState(
                                          () => field.unitChoice = choice ?? '',
                                        ),
                                ),
                                if (field.unitChoice == 'custom') ...[
                                  const SizedBox(height: 10),
                                  TextField(
                                    controller: field.customUnit,
                                    enabled: !protected,
                                    maxLength: 24,
                                    decoration: InputDecoration(
                                      labelText: _t('Custom unit'),
                                      hintText: _t('Enter a unit'),
                                      border: const OutlineInputBorder(),
                                    ),
                                  ),
                                ],
                              ],
                            ],
                          );
                        },
                      ),
                    ),
                  TextButton.icon(
                    onPressed: _fields.length >= 30
                        ? null
                        : () => setState(() => _fields.add(_DraftField())),
                    icon: const Icon(Icons.add),
                    label: Text(_t('Add field')),
                  ),
                  if (widget.editingFormat == null)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _objectModel,
                      onChanged: (value) =>
                          setState(() => _objectModel = value ?? false),
                      title: Text(
                        AppStrings.of(context).isFrench
                            ? 'Utiliser ce format de données pour des objets'
                            : 'Use this data format for objects',
                      ),
                    ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  AppStrings.of(context).error(_error!),
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 4,
              children: [
                TextButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  child: Text(_t('Cancel')),
                ),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(
                    _saving
                        ? _t('Creating…')
                        : _t(
                            widget.collection == null
                                ? 'Create collection'
                                : widget.editingFormat == null
                                ? 'Add data format'
                                : 'Save',
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _EntryEditor extends StatefulWidget {
  const _EntryEditor({
    required this.api,
    required this.collection,
    required this.userId,
    this.entry,
    this.initialFormatId,
  });
  final CollectionsApi api;
  final String userId;
  final BrainyCollection collection;
  final BrainyEntry? entry;
  final String? initialFormatId;
  @override
  State<_EntryEditor> createState() => _EntryEditorState();
}

class _EntryEditorState extends State<_EntryEditor> {
  String _t(String value) => AppStrings.of(context).text(value);
  AppStrings get _copy => AppStrings.of(context);
  late String _selectedFormatId;
  BrainyFormat get _activeFormat => widget.collection.formats.firstWhere(
    (format) => format.id == _selectedFormatId,
    orElse: () => widget.collection.formats.first,
  );
  late final Map<String, TextEditingController> _controllers = {
    for (final format in widget.collection.formats)
      for (final field in format.fields)
        field.id: TextEditingController(
          text: field.kind == BrainyFieldKind.number && _copy.isFrench
              ? (widget.entry?.values[field.id] ?? '').replaceAll('.', ',')
              : widget.entry?.values[field.id] ?? '',
        ),
  };
  bool _saving = false;
  String? _error;
  final Map<String, Uint8List> _attachments = {};
  final Map<String, String> _objectNames = {};

  @override
  void initState() {
    super.initState();
    _selectedFormatId =
        widget.entry?.formatId ??
        widget.initialFormatId ??
        widget.collection.formats.first.id;
    if (widget.entry != null) {
      widget.api
          .entryObjectReferences(widget.entry!.id)
          .then((references) {
            if (mounted) {
              setState(() {
                for (final item in references) {
                  _objectNames[item['objectId'] as String] =
                      item['name'] as String? ?? item['objectId'] as String;
                }
              });
            }
          })
          .catchError((Object _) {});
    }
  }

  Future<void> _chooseObjects(BrainyField field) async {
    final targetId = field.targetObjectFormatId;
    if (targetId == null) return;
    final localTarget = widget.collection.formats
        .where((item) => item.id == targetId)
        .firstOrNull;
    final linked = widget.collection.sharedObjects
        .where(
          (grant) =>
              grant['sourceFormatId'] == targetId &&
              grant['revokedAt'] == null &&
              (grant['mode'] == 'CURRENT' || field.referenceMode == 'SNAPSHOT'),
        )
        .toList();
    final titleId =
        localTarget?.fields
            .where((item) => item.kind == BrainyFieldKind.title)
            .firstOrNull
            ?.id ??
        ((linked.firstOrNull?['snapshot'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>()
                .where((item) => item['kind'] == 'TITLE')
                .firstOrNull?['fieldId']
            as String?);
    Future<BrainyEntryPage> loadPage(String query, {String? after}) async {
      if (localTarget != null) {
        return widget.api.objectsPage(
          widget.collection.id,
          targetId,
          search: query,
          after: after,
        );
      }
      return BrainyEntryPage(
        entries: [
          for (final grant in linked)
            if ((grant['objectName'] as String).toLowerCase().contains(
              query.toLowerCase(),
            ))
              BrainyEntry(
                id: grant['objectId'] as String,
                formatId: targetId,
                values: {
                  ?titleId: grant['objectName'] as String,
                },
                createdAt: DateTime.parse(grant['createdAt'] as String),
                updatedAt: DateTime.parse(grant['createdAt'] as String),
              ),
        ],
        hasMore: false,
      );
    }

    List<String> selected;
    try {
      selected = (jsonDecode(_controllers[field.id]!.text) as List<dynamic>)
          .cast<String>();
    } catch (_) {
      selected = [];
    }
    final search = TextEditingController();
    BrainyEntryPage page;
    try {
      page = await loadPage('');
    } catch (error) {
      if (mounted) setState(() => _error = _copy.error(error));
      search.dispose();
      return;
    }
    if (!mounted) {
      search.dispose();
      return;
    }
    final result = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(_copy.isFrench ? 'Choisir des objets' : 'Choose objects'),
          content: SizedBox(
            width: 450,
            height: 420,
            child: Column(
              children: [
                TextField(
                  controller: search,
                  decoration: InputDecoration(
                    labelText: _copy.isFrench
                        ? 'Rechercher des objets'
                        : 'Search objects',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () async {
                        final next = await loadPage(search.text);
                        update(() => page = next);
                      },
                    ),
                  ),
                  onSubmitted: (text) async {
                    final next = await loadPage(text);
                    update(() => page = next);
                  },
                ),
                Expanded(
                  child: ListView(
                    children: [
                      for (final object in page.entries)
                        CheckboxListTile(
                          value: selected.contains(object.id),
                          title: Text(object.values[titleId] ?? object.id),
                          onChanged: (value) => update(() {
                            if (field.multiple) {
                              if (value == true) {
                                if (!selected.contains(object.id)) {
                                  selected.add(object.id);
                                }
                              } else {
                                selected.remove(object.id);
                              }
                            } else {
                              selected = value == true ? [object.id] : [];
                            }
                          }),
                        ),
                      if (page.hasMore)
                        TextButton(
                          onPressed: () async {
                            final next = await loadPage(
                              search.text,
                              after: page.nextCursor,
                            );
                            update(
                              () => page = BrainyEntryPage(
                                entries: [...page.entries, ...next.entries],
                                hasMore: next.hasMore,
                                nextCursor: next.nextCursor,
                              ),
                            );
                          },
                          child: Text(
                            _copy.isFrench ? 'Voir plus' : 'Load more',
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(_t('Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, selected),
              child: Text(_t('Save')),
            ),
          ],
        ),
      ),
    );
    if (mounted && result != null) {
      setState(() {
        _controllers[field.id]!.text = result.isEmpty ? '' : jsonEncode(result);
        for (final object in page.entries) {
          _objectNames[object.id] = object.values[titleId] ?? object.id;
        }
      });
    }
    search.dispose();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final values = {
      for (final field in _activeFormat.fields)
        field.id: field.kind == BrainyFieldKind.number
            ? normalizeFieldNumber(_controllers[field.id]!.text)
            : field.kind == BrainyFieldKind.multiSelect &&
                  _controllers[field.id]!.text == '[]'
            ? ''
            : _controllers[field.id]!.text.trim(),
    };
    if (values.values.every((value) => value.isEmpty)) {
      setState(() => _error = _t('Write something before saving.'));
      return;
    }
    if (_attachments.values.fold<int>(0, (sum, bytes) => sum + bytes.length) >
        8_388_608) {
      setState(
        () => _error = _t(
          'Choose a file smaller than 2 MB. An entry can hold at most 8 MB of files.',
        ),
      );
      return;
    }
    for (final field in _activeFormat.fields) {
      final value = values[field.id]!;
      if (field.kind == BrainyFieldKind.character && value.runes.length > 1) {
        setState(
          () => _error = '${field.name} ${_t('must contain one character.')}',
        );
        return;
      }
      if (field.kind == BrainyFieldKind.number &&
          value.isNotEmpty &&
          (!RegExp(r'^[+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?$')
                  .hasMatch(value) ||
              double.tryParse(value)?.isFinite != true)) {
        setState(() => _error = _t('Enter a valid number.'));
        return;
      }
      if (field.kind == BrainyFieldKind.link && value.isNotEmpty) {
        final uri = Uri.tryParse(value);
        if (uri == null ||
            !uri.hasAuthority ||
            !['http', 'https'].contains(uri.scheme)) {
          setState(
            () => _error =
                '${field.name} ${_t('must be a full web link, starting with https://.')}',
          );
          return;
        }
      }
      if (field.kind == BrainyFieldKind.duration &&
          value.isNotEmpty &&
          !RegExp(r'^\d{1,6}:[0-5]\d$').hasMatch(value)) {
        setState(() => _error = _t('Enter a duration as hours:minutes.'));
        return;
      }
    }
    try {
      if (!await confirmDuplicateLinks(context: context, api: widget.api, collectionId: widget.collection.id, formatId: _selectedFormatId, entryId: widget.entry?.id, fields: _activeFormat.fields, values: values, isFrench: _copy.isFrench)) return;
    } catch (cause) {
      if (mounted) setState(() => _error = _copy.error(cause));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final queue = OfflineEntryQueue(widget.userId);
    final mutationId = OfflineEntryQueue.newId();
    try {
      if (widget.entry?.offlinePending == true) {
        if (_attachments.isNotEmpty) throw const FormatException('Attachments need a connection');
        await queue.revise(widget.entry!.id, values);
        if (mounted) Navigator.pop(context, BrainyEntry(id: widget.entry!.id, values: values, formatId: _selectedFormatId, createdAt: widget.entry!.createdAt, updatedAt: DateTime.now(), offlinePending: true));
        return;
      }
      final saved = await widget.api.saveEntry(
        widget.collection.id,
        values,
        entryId: widget.entry?.id,
        formatId: _selectedFormatId,
        attachments: _attachments,
        clientMutationId: mutationId,
        expectedUpdatedAt: widget.entry?.updatedAt,
      );
      if (mounted) Navigator.pop(context, saved);
    } catch (error) {
      final networkFailure = error is AuthApiException && (error.message.contains('Could not reach') || error.message.contains('temporarily unavailable'));
      if (networkFailure && _attachments.isEmpty && !_activeFormat.fields.any((field) => field.kind == BrainyFieldKind.objectRef && (values[field.id]?.isNotEmpty ?? false))) {
        try {
          await queue.enqueue({'id': mutationId, 'collectionId': widget.collection.id, if (widget.entry != null) 'entryId': widget.entry!.id, 'formatId': _selectedFormatId, 'values': values, if (widget.entry != null) 'expectedUpdatedAt': widget.entry!.updatedAt.toUtc().toIso8601String(), 'createdAt': DateTime.now().toUtc().toIso8601String(), 'status': 'pending'});
          if (mounted) Navigator.pop(context, BrainyEntry(id: widget.entry?.id ?? 'offline:$mutationId', values: values, formatId: _selectedFormatId, createdAt: widget.entry?.createdAt ?? DateTime.now(), updatedAt: DateTime.now(), offlinePending: true));
          return;
        } catch (queueError) { if (mounted) setState(() { _saving = false; _error = _copy.error(queueError); }); return; }
      }
      if (mounted) {
        setState(() {
          _saving = false;
          _error = _copy.error(error);
        });
      }
    }
  }

  Future<void> _pickDate(BrainyField field) => pickEntryDate(context, _controllers[field.id]!);

  Future<void> _pickTime(BrainyField field) => pickEntryTime(context, _controllers[field.id]!);

  Future<void> _pickDateTime(BrainyField field) async {
    await pickEntryDateTime(context, _controllers[field.id]!);
    if (mounted) setState(() {});
  }

  Future<void> _pickAttachment(BrainyField field) async {
    try {
      final picked = await pickEntryAttachment();
      if (picked == null || !mounted) return;
      if (picked.bytes == null) {
        setState(() => _error = _t('Choose a file smaller than 2 MB. An entry can hold at most 8 MB of files.'));
        return;
      }
      setState(() {
        _controllers[field.id]!.text = picked.name;
        _attachments[field.id] = picked.bytes!;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = _copy.error(error));
    }
  }

  Widget _field(BrainyField field) {
    final kind = field.kind;
    if (kind == BrainyFieldKind.position || kind == BrainyFieldKind.zone) {
      return GeoFieldInput(key: ValueKey(field.id), field: field, controller: _controllers[field.id]!, french: _copy.isFrench);
    }
    if (kind == BrainyFieldKind.code) {
      final list = widget.collection.codeLists.where((item) => item['id'] == field.codeListId).firstOrNull;
      final value = _controllers[field.id]!.text;
      final codes = (list?['codes'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>().where((item) => item['active'] == true || item['code'] == value).toList();
      return Padding(padding: const EdgeInsets.only(bottom: 16), child: DropdownButtonFormField<String>(initialValue: value.isEmpty ? '' : value, decoration: InputDecoration(labelText: field.name, border: const OutlineInputBorder()), items: [DropdownMenuItem(value: '', child: Text(_t('Choose a value'))), for (final item in codes) DropdownMenuItem(value: item['code'] as String, child: Text('${item[_copy.isFrench ? 'labelFr' : 'labelEn']} (${item['code']})${item['active'] == true ? '' : _copy.isFrench ? ' · obsolète' : ' · obsolete'}'))], onChanged: (next) => setState(() => _controllers[field.id]!.text = next ?? '')));
    }
    if (kind == BrainyFieldKind.objectRef) {
      return entryObjectRefField(context: context, field: field, controller: _controllers[field.id]!, objectNames: _objectNames, isFrench: _copy.isFrench, onChoose: () => _chooseObjects(field), ink: _dialogInk(context));
    }
    if (kind == BrainyFieldKind.attachment) {
      final name = _controllers[field.id]!.text;
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              field.name,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: _dialogInk(context),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _pickAttachment(field),
              icon: const Icon(Icons.attach_file),
              label: Text(_t('Choose a file')),
            ),
            if (name.isNotEmpty)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: _t('Remove file'),
                    onPressed: () => setState(() {
                      _controllers[field.id]!.clear();
                      _attachments.remove(field.id);
                    }),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
          ],
        ),
      );
    }
    if (kind == BrainyFieldKind.boolean || kind == BrainyFieldKind.select) {
      final value = _controllers[field.id]!.text;
      final options = kind == BrainyFieldKind.boolean
          ? <String>['true', 'false']
          : field.options;
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: DropdownButtonFormField<String>(
          key: ValueKey('${field.id}-$value'),
          initialValue: value.isEmpty ? '' : value,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: field.name,
            border: const OutlineInputBorder(),
          ),
          items: [
            DropdownMenuItem(value: '', child: Text(_t('Choose a value'))),
            for (final option in options)
              DropdownMenuItem(
                value: option,
                child: Text(
                  kind == BrainyFieldKind.boolean
                      ? _t(option == 'true' ? 'Yes' : 'No')
                      : option,
                ),
              ),
          ],
          onChanged: (selected) =>
              setState(() => _controllers[field.id]!.text = selected ?? ''),
        ),
      );
    }
    if (kind == BrainyFieldKind.multiSelect) {
      List<String> selected;
      try {
        selected = (jsonDecode(_controllers[field.id]!.text) as List<dynamic>)
            .cast<String>();
      } catch (_) {
        selected = [];
      }
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              field.name,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: _dialogInk(context),
              ),
            ),
            const SizedBox(height: 7),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final option in field.options)
                  FilterChip(
                    label: Text(option),
                    selected: selected.contains(option),
                    onSelected: (checked) => setState(() {
                      final next = [...selected];
                      checked ? next.add(option) : next.remove(option);
                      _controllers[field.id]!.text = jsonEncode(next);
                    }),
                  ),
              ],
            ),
          ],
        ),
      );
    }
    final symbol = numberUnit(field.unit)?.symbol ?? field.unit;
    final currency = ['EUR', 'USD', 'GBP', 'NGN'].contains(field.unit);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: _controllers[field.id],
        maxLines: kind == BrainyFieldKind.longText
            ? 8
            : kind == BrainyFieldKind.text
            ? 4
            : 1,
        maxLength: kind == BrainyFieldKind.character
            ? 2
            : (kind == BrainyFieldKind.longText
                  ? 50000
                  : kind == BrainyFieldKind.text
                  ? 10000
                  : 500),
        keyboardType: kind == BrainyFieldKind.number
            ? const TextInputType.numberWithOptions(decimal: true, signed: true)
            : kind == BrainyFieldKind.link
            ? TextInputType.url
            : TextInputType.text,
        readOnly:
            kind == BrainyFieldKind.date ||
            kind == BrainyFieldKind.time ||
            kind == BrainyFieldKind.datetime,
        onTap: kind == BrainyFieldKind.date
            ? () => _pickDate(field)
            : kind == BrainyFieldKind.time
            ? () => _pickTime(field)
            : kind == BrainyFieldKind.datetime
            ? () => _pickDateTime(field)
            : null,
        decoration: InputDecoration(
          labelText: field.name,
          helperText: kind == BrainyFieldKind.character
              ? _t('One character')
              : kind == BrainyFieldKind.link
              ? 'https://example.com'
              : null,
          hintText: kind == BrainyFieldKind.number
              ? _t(_copy.isFrench ? 'Number example French' : 'Number example')
              : null,
          prefixText:
              kind == BrainyFieldKind.number && currency && symbol != null
              ? '$symbol '
              : null,
          suffixText: kind == BrainyFieldKind.number && !currency
              ? symbol
              : null,
          suffixIcon: kind == BrainyFieldKind.date
              ? IconButton(
                  onPressed: () => _pickDate(field),
                  icon: const Icon(Icons.calendar_today_outlined),
                )
              : kind == BrainyFieldKind.time
              ? IconButton(
                  onPressed: () => _pickTime(field),
                  icon: const Icon(Icons.schedule_outlined),
                )
              : kind == BrainyFieldKind.datetime
              ? IconButton(
                  onPressed: () => _pickDateTime(field),
                  icon: const Icon(Icons.event_outlined),
                )
              : null,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Dialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 580, maxHeight: 700),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _activeFormat.objectModel
                  ? (AppStrings.of(context).isFrench
                        ? widget.entry == null
                              ? 'Créer un objet'
                              : 'Modifier l’objet'
                        : widget.entry == null
                        ? 'Create object'
                        : 'Edit object')
                  : widget.entry == null
                  ? _t('New entry')
                  : _t('Edit entry'),
              style: TextStyle(
                color: _dialogInk(context),
                fontSize: 23,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              widget.collection.name,
              style: TextStyle(color: _dialogMuted(context)),
            ),
            const SizedBox(height: 20),
            if (widget.entry == null && widget.initialFormatId == null)
              DropdownButtonFormField<String>(
                initialValue: _selectedFormatId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: _t('Data format'),
                  border: const OutlineInputBorder(),
                ),
                items: [
                  for (final format in widget.collection.formats)
                    DropdownMenuItem(
                      value: format.id,
                      child: Row(
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: _formatTint(format),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: const Color(0xFFD9E3EE),
                              ),
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              _displayFormatName(context, format),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _selectedFormatId = value);
                },
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: _formatTint(_activeFormat),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  _displayFormatName(context, _activeFormat),
                  style: const TextStyle(color: _ink),
                ),
              ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final field in _activeFormat.fields) _field(field),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 4,
              children: [
                TextButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  child: Text(_t('Cancel')),
                ),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(
                    _saving
                        ? _t('Saving…')
                        : _activeFormat.objectModel
                        ? (AppStrings.of(context).isFrench
                              ? 'Enregistrer l’objet'
                              : 'Save object')
                        : _t('Save entry'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
