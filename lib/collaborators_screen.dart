// T52: "Collaborators" screen, link pasted from a message, collection sharing and shared banner.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_strings.dart';
import 'auth_api.dart';
import 'collaborators_api.dart';
import 'collections_api.dart';

const _teal = Color(0xFF0E6E66), _tealSoft = Color(0xFFE3F6F4), _tealDark = Color(0xFF5EEAD4), _tealDarkSoft = Color(0x242DD4BF);
Color _ink(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? _tealDark : _teal;
Color _soft(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? _tealDarkSoft : _tealSoft;

Future<void> openCollaborators(BuildContext context, AuthApi auth, {VoidCallback? onChanged, String? pastedLink}) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => CollaboratorsScreen(auth: auth, onChanged: onChanged, pastedLink: pastedLink)));

class CollaboratorsScreen extends StatefulWidget {
  const CollaboratorsScreen({super.key, required this.auth, this.onChanged, this.pastedLink});
  final AuthApi auth;
  final VoidCallback? onChanged;
  final String? pastedLink;

  @override
  State<CollaboratorsScreen> createState() => _CollaboratorsScreenState();
}

class _CollaboratorsScreenState extends State<CollaboratorsScreen> {
  late final _api = CollaboratorsApi(widget.auth);
  late final _paste = TextEditingController(text: widget.pastedLink ?? '');
  String? _link, _error, _notice;
  List<BrainyCollaborator>? _people;
  CollaborationInvitePreview? _preview;
  String? _previewToken;
  bool _busy = false;

  bool get _fr => AppStrings.of(context).isFrench;
  String _t(String en, String fr) => _fr ? fr : en;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _paste.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([_api.inviteToken(), _api.list()]);
      if (!mounted) return;
      setState(() {
        _link = collaborationLink(results[0] as String);
        _people = results[1] as List<BrainyCollaborator>;
      });
    } catch (error) {
      if (mounted) setState(() => _error = collaboratorError(error, _fr));
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() { _busy = true; _error = null; _notice = null; });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _error = collaboratorError(error, _fr));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  Future<bool> _confirm(String title, String body, String action, {bool danger = false}) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(_t('Cancel', 'Annuler'))),
            FilledButton(
              style: danger ? FilledButton.styleFrom(backgroundColor: Theme.of(dialogContext).colorScheme.error) : null,
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _check() async {
    final token = inviteTokenFrom(_paste.text);
    if (token == null) {
      setState(() { _error = _t('Paste the whole link you received, for example …/invite/abc…', 'Collez le lien reçu en entier, par exemple …/invite/abc…'); _preview = null; });
      return;
    }
    await _run(() async {
      final preview = await _api.preview(token);
      if (mounted) setState(() { _preview = preview; _previewToken = token; });
    });
  }

  Future<void> _accept() => _run(() async {
        final person = await _api.accept(_previewToken!);
        _paste.clear();
        widget.onChanged?.call();
        await _load();
        if (mounted) setState(() { _preview = null; _notice = _t('You and ${person.name} are now collaborators.', '${person.name} et vous êtes maintenant collaborateurs.'); });
      });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final link = _link;
    final message = _t('Let\'s collaborate on Brainy: $link', 'Collaborons sur Brainy : $link');
    return Scaffold(
      appBar: AppBar(title: Text(_t('Collaborators', 'Collaborateurs'))),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Text(
                  _t('Send your link to a colleague. Once it is accepted, you are collaborators: you can then share a collection with them, in read only or read and write.',
                      'Envoyez votre lien à un collègue. Dès que ce lien est accepté, vous êtes collaborateurs : vous pouvez alors partager une collection avec cette personne, en lecture seule ou en lecture et écriture.'),
                  style: theme.textTheme.bodyMedium?.copyWith(color: muted, height: 1.5),
                ),
                if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: TextStyle(color: theme.colorScheme.error))),
                if (_notice != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Semantics(liveRegion: true, child: Row(children: [Icon(Icons.check_circle_outline, color: _ink(context), size: 18), const SizedBox(width: 8), Expanded(child: Text(_notice!))])),
                  ),
                const SizedBox(height: 16),
                _Section(
                  title: _t('Your collaboration link', 'Votre lien de collaboration'),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: theme.dividerColor)),
                      child: SelectableText(link ?? _t('Loading…', 'Chargement…'), style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
                    ),
                    const SizedBox(height: 12),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      FilledButton.icon(
                        onPressed: link == null ? null : () async {
                          await Clipboard.setData(ClipboardData(text: link));
                          if (mounted) setState(() => _notice = _t('Link copied.', 'Lien copié.'));
                        },
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: Text(_t('Copy link', 'Copier le lien')),
                      ),
                      OutlinedButton.icon(onPressed: link == null ? null : () => _open('https://wa.me/?text=${Uri.encodeComponent(message)}'), icon: const Icon(Icons.chat_outlined, size: 18), label: const Text('WhatsApp')),
                      OutlinedButton.icon(onPressed: link == null ? null : () => _open('https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(link)}'), icon: const Icon(Icons.facebook_rounded, size: 18), label: const Text('Facebook')),
                    ]),
                    const SizedBox(height: 12),
                    _Help(_t('Being collaborators gives no access to your data. You choose, collection by collection, what each collaborator can see.', 'Être collaborateurs ne donne accès à aucune de vos données. Vous choisissez, collection par collection, ce que chaque collaborateur peut voir.')),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _busy ? null : () async {
                          if (!await _confirm(_t('Create a new link?', 'Créer un nouveau lien ?'), _t('The current link will stop working. People who already accepted stay your collaborators.', 'Le lien actuel cessera de fonctionner. Les personnes qui l’ont déjà accepté restent vos collaborateurs.'), _t('Create a new link', 'Créer un nouveau lien'))) return;
                          await _run(() async {
                            final token = await _api.regenerate();
                            if (mounted) setState(() { _link = collaborationLink(token); _notice = _t('New link ready. The previous link no longer works.', 'Nouveau lien prêt. L’ancien lien ne fonctionne plus.'); });
                          });
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: Text(_t('Create a new link', 'Créer un nouveau lien')),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _Section(
                  title: _t('Accept a link you received', 'Accepter un lien reçu'),
                  children: [
                    TextField(
                      controller: _paste,
                      decoration: InputDecoration(labelText: _t('Collaboration link', 'Lien de collaboration'), hintText: _t('Paste the link here', 'Collez le lien ici')),
                      onSubmitted: (_) => _check(),
                    ),
                    const SizedBox(height: 10),
                    if (_preview == null)
                      Align(alignment: Alignment.centerLeft, child: OutlinedButton(onPressed: _busy ? null : _check, child: Text(_t('Check the link', 'Vérifier le lien'))))
                    else if (_preview!.isSelf)
                      Text(_t('This is your own link: send it to a colleague.', 'C’est votre propre lien : envoyez-le à un collègue.'))
                    else if (_preview!.alreadyCollaborator)
                      Text(_t('You already collaborate with ${_preview!.inviterName}.', 'Vous collaborez déjà avec ${_preview!.inviterName}.'))
                    else ...[
                      Text(_t('${_preview!.inviterName} invites you to collaborate.', '${_preview!.inviterName} vous invite à collaborer.'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      _Help(_t('Accepting gives nobody access to your data. Each person decides what they share.', 'Accepter ne donne accès à aucune de vos données. Chacun décide de ce qu’il partage.')),
                      const SizedBox(height: 10),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        OutlinedButton(onPressed: () => setState(() => _preview = null), child: Text(_t('Not now', 'Pas maintenant'))),
                        FilledButton(onPressed: _busy ? null : _accept, child: Text(_t('Accept the collaboration', 'Accepter la collaboration'))),
                      ]),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                _Section(
                  title: '${_t('Your collaborators', 'Vos collaborateurs')}${_people == null ? '' : ' (${_people!.length})'}',
                  children: [
                    if (_people == null && _error == null) Text(_t('Loading…', 'Chargement…'), style: TextStyle(color: muted)),
                    if (_people?.isEmpty ?? false)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(children: [
                          Icon(Icons.group_outlined, size: 32, color: muted),
                          const SizedBox(height: 8),
                          Text(_t('No collaborator yet. Send your link to a colleague to get started.', 'Aucun collaborateur pour l’instant. Envoyez votre lien à un collègue pour commencer.'), textAlign: TextAlign.center, style: TextStyle(color: muted)),
                        ]),
                      ),
                    for (final person in _people ?? const <BrainyCollaborator>[])
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(backgroundColor: _soft(context), foregroundColor: _ink(context), child: Text(person.name.characters.first.toUpperCase())),
                        title: Text(person.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text('${person.email}\n${_t('Since', 'Depuis le')} ${MaterialLocalizations.of(context).formatMediumDate(person.since)}', maxLines: 2, overflow: TextOverflow.ellipsis),
                        isThreeLine: true,
                        trailing: IconButton(
                          tooltip: _t('End collaboration with ${person.name}', 'Mettre fin à la collaboration avec ${person.name}'),
                          icon: const Icon(Icons.person_remove_outlined),
                          onPressed: _busy ? null : () async {
                            if (!await _confirm(
                              _t('End the collaboration?', 'Mettre fin à la collaboration ?'),
                              _t('Every collection shared between you and ${person.name} will be unshared, both ways.', 'Toutes les collections partagées entre vous et ${person.name} cesseront de l’être, dans les deux sens.'),
                              _t('End', 'Mettre fin'),
                              danger: true,
                            )) { return; }
                            await _run(() async {
                              await _api.end(person.userId);
                              widget.onChanged?.call();
                              if (mounted) setState(() { _people = _people?.where((item) => item.userId != person.userId).toList(); _notice = _t('Collaboration with ${person.name} ended.', 'Collaboration avec ${person.name} terminée.'); });
                            });
                          },
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Semantics(header: true, child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
            const SizedBox(height: 12),
            ...children,
          ]),
        ),
      );
}

class _Help extends StatelessWidget {
  const _Help(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.verified_user_outlined, size: 16, color: _ink(context)),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.45))),
      ]);
}

/// The owner chooses, collaborator by collaborator, who can see [collection] and how. Returns true when something changed.
Future<bool> showCollectionShareSheet(BuildContext context, {required AuthApi auth, required BrainyCollection collection, VoidCallback? onOpenCollaborators}) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ShareSheet(auth: auth, collection: collection, onOpenCollaborators: onOpenCollaborators),
    ) ??
    false;

class _ShareSheet extends StatefulWidget {
  const _ShareSheet({required this.auth, required this.collection, this.onOpenCollaborators});
  final AuthApi auth;
  final BrainyCollection collection;
  final VoidCallback? onOpenCollaborators;

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  late final _api = CollaboratorsApi(widget.auth);
  List<BrainyCollaborator>? _people;
  late final Map<String, BrainyCollectionRole?> _access = {for (final member in widget.collection.members) member.userId: member.role};
  String? _error, _saving, _saved;
  bool _changed = false;

  bool get _fr => AppStrings.of(context).isFrench;
  String _t(String en, String fr) => _fr ? fr : en;

  @override
  void initState() {
    super.initState();
    _api.list().then((people) { if (mounted) setState(() => _people = people); }).catchError((Object error) { if (mounted) setState(() => _error = collaboratorError(error, _fr)); });
  }

  Future<void> _change(BrainyCollaborator person, BrainyCollectionRole? role) async {
    setState(() { _saving = person.userId; _error = null; _saved = null; });
    try {
      if (role == null) {
        await _api.unshare(widget.collection.id, person.userId);
      } else {
        await _api.share(widget.collection, person.userId, role);
      }
      if (mounted) setState(() { _access[person.userId] = role; _saved = person.userId; _changed = true; });
    } catch (error) {
      if (mounted) setState(() => _error = collaboratorError(error, _fr));
    } finally {
      if (mounted) setState(() => _saving = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) Navigator.of(context).pop(_changed); },
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .85),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              Text(_t('Share “${widget.collection.name}”', 'Partager « ${widget.collection.name} »'), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              _Help(_t('Read only: they see the entries. Read and write: they can also add, edit and delete entries. Data formats, the collection name and sharing stay yours.', 'Lecture seule : la personne voit les entrées. Lecture et écriture : elle peut aussi ajouter, modifier et supprimer des entrées. Les formats de données, le nom de la collection et le partage restent à vous.')),
              if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: TextStyle(color: theme.colorScheme.error))),
              const SizedBox(height: 12),
              if (_people == null && _error == null) Text(_t('Loading…', 'Chargement…'), style: TextStyle(color: muted)),
              if (_people?.isEmpty ?? false) ...[
                Text(_t('You have no collaborator yet. Send your collaboration link to a colleague first.', 'Vous n’avez pas encore de collaborateur. Envoyez d’abord votre lien de collaboration à un collègue.'), style: TextStyle(color: muted)),
                const SizedBox(height: 12),
                if (widget.onOpenCollaborators != null)
                  Align(alignment: Alignment.centerLeft, child: FilledButton(onPressed: () { Navigator.of(context).pop(_changed); widget.onOpenCollaborators!(); }, child: Text(_t('Get my link', 'Obtenir mon lien')))),
              ],
              for (final person in _people ?? const <BrainyCollaborator>[])
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      CircleAvatar(radius: 18, backgroundColor: _soft(context), foregroundColor: _ink(context), child: Text(person.name.characters.first.toUpperCase())),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(person.name, style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(_saved == person.userId ? _t('Saved', 'Enregistré') : person.email, style: TextStyle(color: _saved == person.userId ? _ink(context) : muted, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<BrainyCollectionRole?>(
                      key: ValueKey('access-${person.userId}'),
                      isExpanded: true,
                      initialValue: _access[person.userId] == BrainyCollectionRole.owner ? null : _access[person.userId],
                      decoration: InputDecoration(labelText: _t('Access for ${person.name}', 'Accès de ${person.name}'), isDense: true),
                      items: [
                        DropdownMenuItem(value: null, child: Text(_t('No access', 'Aucun accès'))),
                        DropdownMenuItem(value: BrainyCollectionRole.reader, child: Text(_t('Read only', 'Lecture seule'))),
                        DropdownMenuItem(value: BrainyCollectionRole.editor, child: Text(_t('Read and write', 'Lecture et écriture'))),
                      ],
                      onChanged: _saving == person.userId ? null : (role) => _change(person, role),
                    ),
                  ]),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// T52: reminds a collaborator what they can do in a collection shared with them.
class SharedCollectionBanner extends StatelessWidget {
  const SharedCollectionBanner({super.key, required this.ownerName, required this.canWrite});
  final String ownerName;
  final bool canWrite;

  @override
  Widget build(BuildContext context) {
    final fr = AppStrings.of(context).isFrench;
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: theme.dividerColor)),
      child: Wrap(spacing: 10, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Icon(Icons.drive_folder_upload_outlined, size: 18, color: _ink(context)),
        Text(fr ? 'Partagée par $ownerName' : 'Shared by $ownerName', style: const TextStyle(fontWeight: FontWeight.w700)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(color: _soft(context), borderRadius: BorderRadius.circular(999)),
          child: Text(canWrite ? (fr ? 'Lecture et écriture' : 'Read and write') : (fr ? 'Lecture seule' : 'Read only'), style: TextStyle(color: _ink(context), fontWeight: FontWeight.w600, fontSize: 13)),
        ),
        Text(
          canWrite
              ? (fr ? 'Vous pouvez ajouter, modifier et supprimer des entrées. La structure reste gérée par le propriétaire.' : 'You can add, edit and delete entries. The owner keeps managing the structure.')
              : (fr ? 'Vous pouvez consulter et copier les entrées, sans les modifier.' : 'You can view and copy entries, without changing them.'),
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
        ),
      ]),
    );
  }
}
