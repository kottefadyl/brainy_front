// T48: WhatsApp-like preview of a saved link (image, title, description, site) for Saved links collections.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'collections_api.dart';

class LinkPreviewData {
  const LinkPreviewData({required this.url, required this.available, this.title, this.description, this.siteName, this.image, this.video = false});
  final String url;
  final bool available, video;
  final String? title, description, siteName;
  final Uint8List? image;

  factory LinkPreviewData.fromJson(Map<String, dynamic> json) {
    final image = json['image'] as String?;
    Uint8List? bytes;
    if (image != null && image.startsWith('data:image/')) {
      try {
        bytes = base64Decode(image.substring(image.indexOf(',') + 1));
      } catch (_) {}
    }
    return LinkPreviewData(url: json['url'] as String, available: json['available'] as bool? ?? false, title: json['title'] as String?, description: json['description'] as String?, siteName: json['siteName'] as String?, image: bytes, video: json['video'] as bool? ?? false);
  }
}

/// A value is previewed only when it is a public web address (http or https).
String? previewableUrl(String? value) {
  final uri = Uri.tryParse(value?.trim() ?? '');
  if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https') || !uri.host.contains('.')) return null;
  return uri.toString();
}

String linkHost(String url) => (Uri.tryParse(url)?.host ?? url).replaceFirst(RegExp(r'^www\.'), '');

final _previews = <String, Future<LinkPreviewData>>{};

extension LinkPreviewApi on CollectionsApi {
  Future<LinkPreviewData> linkPreview(String url) => _previews.putIfAbsent(url, () async {
        try {
          final data = await auth.authenticatedRequest('query(\$url:String!){linkPreview(url:\$url){url available title description siteName image video}}', {'url': url}, timeout: const Duration(seconds: 20));
          return LinkPreviewData.fromJson(data['linkPreview'] as Map<String, dynamic>);
        } catch (_) {
          _previews.remove(url);
          rethrow;
        }
      });
}

/// The card for an entry, or null when the collection is not a Saved links one or no link is set.
Widget? linkPreviewFor(CollectionsApi api, BrainyCollection collection, BrainyFormat format, BrainyEntry entry, {required bool french, bool compact = false}) {
  final field = previewedLinkField(collection, format, entry);
  if (field == null) return null;
  final url = previewableUrl(entry.values[field.id])!;
  return LinkPreviewCard(key: ValueKey('preview-$url'), api: api, url: url, french: french, compact: compact);
}

/// The link field shown as a preview (Saved links collections only), or null.
BrainyField? previewedLinkField(BrainyCollection collection, BrainyFormat format, BrainyEntry entry) {
  if (collection.templateId != 'links') return null;
  return format.fields.where((item) => item.kind == BrainyFieldKind.link && previewableUrl(entry.values[item.id]) != null).firstOrNull;
}

class LinkPreviewCard extends StatefulWidget {
  const LinkPreviewCard({super.key, required this.api, required this.url, required this.french, this.compact = false});
  final CollectionsApi api;
  final String url;
  final bool french;
  /// One slim line inside an entry row: small thumbnail, title and site, no description.
  final bool compact;
  @override
  State<LinkPreviewCard> createState() => _LinkPreviewCardState();
}

class _LinkPreviewCardState extends State<LinkPreviewCard> {
  late final Future<LinkPreviewData> preview = widget.api.linkPreview(widget.url);

  Future<void> _open() async {
    final uri = Uri.parse(widget.url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.french ? 'Impossible d’ouvrir ce lien.' : 'This link could not be opened.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    final narrow = MediaQuery.sizeOf(context).width < 480;
    final thumb = narrow ? 84.0 : 112.0;
    return FutureBuilder<LinkPreviewData>(
      future: preview,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final waiting = snapshot.connectionState != ConnectionState.done;
        final rich = data != null && data.available;
        final site = (data?.siteName?.isNotEmpty ?? false) ? data!.siteName! : linkHost(widget.url);
        Widget box(Widget child, {double width = 56}) => ClipRRect(borderRadius: BorderRadius.circular(8), child: Container(width: width, height: width == 56 ? 56 : thumb, color: scheme.surfaceContainerHighest, child: child));
        final siteLine = Row(mainAxisSize: MainAxisSize.min, children: [Flexible(child: Text(site, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: muted, fontSize: 13))), const SizedBox(width: 4), Icon(Icons.open_in_new, size: 12, color: muted)]);
        if (widget.compact) return _compact(context, data, waiting, rich, site);
        Widget content;
        if (waiting) {
          content = Row(children: [box(const SizedBox.shrink(), width: thumb), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(height: 12, width: 200, decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(6))), const SizedBox(height: 8), Container(height: 12, width: 120, decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(6)))]))]);
        } else if (rich) {
          content = Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            if (data.image != null)
              box(Stack(fit: StackFit.expand, children: [
                Image.memory(data.image!, fit: BoxFit.cover, errorBuilder: (_, _, _) => Icon(Icons.link, color: scheme.primary)),
                if (data.video) Center(child: Container(width: 38, height: 38, decoration: const BoxDecoration(color: Color(0x9E000000), shape: BoxShape.circle), child: const Icon(Icons.play_arrow_rounded, color: Colors.white))),
              ]), width: thumb)
            else
              box(Icon(Icons.link, color: scheme.primary)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              if (data.title?.isNotEmpty ?? false) Text(data.title!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, fontSize: narrow ? 14 : 15, height: 1.3, color: scheme.onSurface)),
              if (data.description?.isNotEmpty ?? false) Padding(padding: const EdgeInsets.only(top: 2), child: Text(data.description!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: muted, fontSize: 13, height: 1.4))),
              const SizedBox(height: 3),
              siteLine,
            ])),
          ]);
        } else {
          content = Row(children: [
            Icon(Icons.link, size: 18, color: scheme.primary),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [siteLine, Text(widget.french ? 'Aperçu indisponible pour ce site' : 'No preview for this site', style: TextStyle(color: muted, fontSize: 12))])),
          ]);
        }
        return Semantics(
          link: true,
          label: '${widget.french ? 'Ouvrir le lien' : 'Open link'} : ${data?.title ?? site}',
          excludeSemantics: true,
          child: Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Material(
                color: scheme.surface.withValues(alpha: .85),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: scheme.outlineVariant)),
                clipBehavior: Clip.antiAlias,
                child: InkWell(onTap: _open, child: Padding(padding: EdgeInsets.all(rich || waiting ? 8 : 10), child: content)),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _compact(BuildContext context, LinkPreviewData? data, bool waiting, bool rich, String site) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    final image = rich ? data!.image : null;
    final thumb = ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: image != null ? 54 : 30,
        height: 30,
        color: scheme.surfaceContainerHighest,
        child: image != null
            ? Stack(fit: StackFit.expand, children: [
                Image.memory(image, fit: BoxFit.cover, errorBuilder: (_, _, _) => Icon(Icons.link, size: 16, color: scheme.primary)),
                if (data!.video) const Center(child: Icon(Icons.play_circle_fill, size: 16, color: Colors.white)),
              ])
            : waiting ? null : Icon(Icons.link, size: 16, color: scheme.primary),
      ),
    );
    final title = rich && (data!.title?.isNotEmpty ?? false) ? data.title! : site;
    return Semantics(
      link: true,
      label: '${widget.french ? 'Ouvrir le lien' : 'Open link'} : $title',
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Material(
          color: scheme.surface.withValues(alpha: .85),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9), side: BorderSide(color: scheme.outlineVariant)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _open,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(2, 2, 10, 2),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                thumb,
                const SizedBox(width: 8),
                Flexible(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: scheme.onSurface))),
                if (rich && title != site) ...[
                  const SizedBox(width: 8),
                  Flexible(flex: 0, child: Text(site, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: muted))),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
