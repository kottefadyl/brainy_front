import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// A web link that leads to a picture, a sound or a video is shown in place
/// (cards, entry details). Brainy never downloads or stores the file.
enum LinkMediaKind { image, audio, video, youtube, vimeo }

final _image = RegExp(r'\.(png|jpe?g|gif|webp|avif|bmp|ico)$', caseSensitive: false);
final _audio = RegExp(r'\.(mp3|ogg|oga|wav|m4a|aac|opus|flac|weba)$', caseSensitive: false);
final _video = RegExp(r'\.(mp4|webm|ogv|mov|m4v)$', caseSensitive: false);
/// Picture services whose addresses carry no file extension (search thumbnails, photo hosts).
final _imageHosts = RegExp(r'(^|\.)(encrypted-tbn\d\.gstatic\.com|images\.unsplash\.com|lh\d\.googleusercontent\.com|i\.imgur\.com|i\.pinimg\.com|pbs\.twimg\.com|upload\.wikimedia\.org|picsum\.photos)$', caseSensitive: false);

Uri? _web(String value) {
  final uri = Uri.tryParse(value.trim());
  return uri != null && (uri.scheme == 'https' || uri.scheme == 'http') && uri.host.contains('.') ? uri : null;
}

/// The YouTube video id of a link, if any.
String? youtubeId(String value) {
  final uri = _web(value);
  if (uri == null) return null;
  final host = uri.host.replaceFirst(RegExp(r'^(www\.|m\.)'), '');
  String? id;
  if (host == 'youtu.be') {
    id = uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
  } else if (host == 'youtube.com' || host == 'youtube-nocookie.com') {
    id = uri.path == '/watch' ? uri.queryParameters['v'] : RegExp(r'^/(embed|shorts|live)/([\w-]+)').firstMatch(uri.path)?.group(2);
  }
  return id != null && RegExp(r'^[\w-]{6,20}$').hasMatch(id) ? id : null;
}

/// What a link shows, from the address alone; null when the address gives no clue.
LinkMediaKind? linkMediaKind(String value) {
  final uri = _web(value);
  if (uri == null) return null;
  if (_image.hasMatch(uri.path) || _imageHosts.hasMatch(uri.host)) return LinkMediaKind.image;
  if (_audio.hasMatch(uri.path)) return LinkMediaKind.audio;
  if (_video.hasMatch(uri.path)) return LinkMediaKind.video;
  if (youtubeId(value) != null) return LinkMediaKind.youtube;
  if (uri.host.replaceFirst('www.', '') == 'vimeo.com' && RegExp(r'^/\d+').hasMatch(uri.path)) return LinkMediaKind.vimeo;
  return null;
}

/// Shows a picture in place, a video as a playable thumbnail, a sound as a play button.
/// With [probe], an address with no clue is still tried as a picture; on failure [fallback] is shown.
class LinkMediaView extends StatelessWidget {
  const LinkMediaView({super.key, required this.url, required this.french, required this.fallback, this.probe = false, this.maxHeight = 240});

  final String url;
  final bool french;
  final Widget fallback;
  final bool probe;
  final double maxHeight;

  void _open() => launchUrl(Uri.parse(url.trim()), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    final kind = linkMediaKind(url);
    if (kind == null && !(probe && _web(url) != null)) return fallback;
    switch (kind) {
      case null:
      case LinkMediaKind.image:
        return _picture(url.trim(), onTap: null, play: false, onError: fallback);
      case LinkMediaKind.youtube:
        return _picture('https://img.youtube.com/vi/${youtubeId(url)}/hqdefault.jpg', onTap: _open, play: true, onError: _button(Icons.smart_display_outlined, french ? 'Regarder la vidéo' : 'Watch the video'));
      case LinkMediaKind.audio:
        return _button(Icons.play_circle_outline, french ? 'Écouter le son' : 'Play the sound');
      case LinkMediaKind.video:
      case LinkMediaKind.vimeo:
        return _button(Icons.smart_display_outlined, french ? 'Regarder la vidéo' : 'Watch the video');
    }
  }

  Widget _button(IconData icon, String label) => Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(onPressed: _open, icon: Icon(icon, size: 18), label: Text(label)),
      );

  Widget _picture(String src, {required VoidCallback? onTap, required bool play, required Widget onError}) {
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Stack(alignment: Alignment.center, children: [
          Image.network(src, fit: BoxFit.contain, errorBuilder: (_, _, _) => onError),
          if (play)
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), shape: BoxShape.circle),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
            ),
        ]),
      ),
    );
    return Center(
      child: onTap == null
          ? image
          : Semantics(button: true, label: french ? 'Regarder la vidéo' : 'Watch the video', child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12), child: image)),
    );
  }
}
