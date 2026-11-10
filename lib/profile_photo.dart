import 'dart:convert';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import 'app_strings.dart';
import 'auth_api.dart';

/// Largest stored profile photo in bytes (1 MiB), matching the API limit.
const profilePhotoMaxBytes = 1024 * 1024;

/// The signed-in user's profile photo as a data URL, shared by the profile
/// screen and the workspace account footer.
final profilePhotoNotifier = ValueNotifier<String?>(null);

/// Loads the user's photo when the account has one; clears it otherwise.
Future<void> refreshProfilePhoto(AuthApi api, AppUser? user) async {
  if (user == null || !user.hasProfilePhoto) {
    profilePhotoNotifier.value = null;
    return;
  }
  try {
    profilePhotoNotifier.value = await api.profilePhoto();
  } catch (_) {
    // The initial stays visible when the photo cannot be loaded.
  }
}

enum ProfilePhotoProblem { unreadable, tooLarge }

class ProfilePhotoException implements Exception {
  const ProfilePhotoException(this.problem);
  final ProfilePhotoProblem problem;
}

class PreparedPhoto {
  const PreparedPhoto(this.dataUrl, this.bytes, {required this.compressed});
  final String dataUrl;
  final int bytes;
  final bool compressed;
}

String? _mimeOf(Uint8List bytes) {
  if (bytes.length > 3 && bytes[0] == 0xff && bytes[1] == 0xd8 && bytes[2] == 0xff) return 'image/jpeg';
  if (bytes.length > 8 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4e && bytes[3] == 0x47) return 'image/png';
  if (bytes.length > 12 && ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
      ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP') {
    return 'image/webp';
  }
  return null;
}

/// Keeps JPEG, PNG and WebP photos of 1 MiB or less unchanged; anything larger
/// (or another decodable format) is re-encoded as JPEG, lowering quality and
/// then size until it fits. Runs synchronously; call through [prepareProfilePhoto].
PreparedPhoto prepareProfilePhotoSync(Uint8List bytes) {
  final mime = _mimeOf(bytes);
  if (mime != null && bytes.length <= profilePhotoMaxBytes) {
    return PreparedPhoto('data:$mime;base64,${base64Encode(bytes)}', bytes.length, compressed: false);
  }
  final decoded = img.decodeImage(bytes);
  if (decoded == null || decoded.width == 0 || decoded.height == 0) {
    throw const ProfilePhotoException(ProfilePhotoProblem.unreadable);
  }
  final source = img.bakeOrientation(decoded);
  final longest = math.max(source.width, source.height);
  var side = math.min(1600, longest);
  var quality = 86;
  while (side >= 160) {
    var frame = side < longest
        ? img.copyResize(
            source,
            width: source.width >= source.height ? side : null,
            height: source.height > source.width ? side : null,
            interpolation: img.Interpolation.average,
          )
        : source;
    if (frame.hasAlpha) {
      final background = img.Image(width: frame.width, height: frame.height);
      img.fill(background, color: img.ColorRgb8(255, 255, 255));
      frame = img.compositeImage(background, frame);
    }
    final jpeg = img.encodeJpg(frame, quality: quality);
    if (jpeg.length <= profilePhotoMaxBytes) {
      return PreparedPhoto('data:image/jpeg;base64,${base64Encode(jpeg)}', jpeg.length, compressed: true);
    }
    if (quality > 60) {
      quality -= 13;
    } else {
      side = (side * 0.75).floor();
    }
  }
  throw const ProfilePhotoException(ProfilePhotoProblem.tooLarge);
}

/// Prepares a photo off the UI thread.
Future<PreparedPhoto> prepareProfilePhoto(Uint8List bytes) => compute(prepareProfilePhotoSync, bytes);

Uint8List? _decodeDataUrl(String? dataUrl) {
  if (dataUrl == null) return null;
  try {
    return UriData.parse(dataUrl).contentAsBytes();
  } catch (_) {
    return null;
  }
}

/// Round avatar showing the photo, or the first letter of [name].
class ProfileAvatar extends StatefulWidget {
  const ProfileAvatar({super.key, required this.name, required this.photo, this.size = 36, this.gradient, this.initialColor});
  final String name;
  final String? photo;
  final double size;
  final List<Color>? gradient;
  final Color? initialColor;

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  String? _source;
  Uint8List? _bytes;

  Uint8List? get _image {
    if (widget.photo != _source) {
      _source = widget.photo;
      _bytes = _decodeDataUrl(widget.photo);
    }
    return _bytes;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bytes = _image;
    final name = widget.name.trim();
    return Container(
      width: widget.size,
      height: widget.size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: bytes == null
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: widget.gradient ?? [scheme.primary, Color.lerp(scheme.primary, const Color(0xFF22A55A), .45)!],
              )
            : null,
      ),
      child: bytes != null
          ? Image.memory(bytes, width: widget.size, height: widget.size, fit: BoxFit.cover, gaplessPlayback: true, excludeFromSemantics: true)
          : Text(
              name.isEmpty ? '?' : name.characters.first.toUpperCase(),
              style: TextStyle(color: widget.initialColor ?? Colors.white, fontWeight: FontWeight.w700, fontSize: widget.size * .38),
            ),
    );
  }
}

String _sizeLabel(int bytes, bool french) {
  final kilobytes = bytes / 1024;
  if (kilobytes < 1000) return '${math.max(1, kilobytes.round())} ${french ? 'Ko' : 'KB'}';
  final megabytes = (bytes / (1024 * 1024)).toStringAsFixed(2);
  return '${french ? megabytes.replaceAll('.', ',') : megabytes} ${french ? 'Mo' : 'MB'}';
}

/// Profile photo preview with choose/remove actions. Large photos are compressed
/// before [onChanged] receives the data URL.
class ProfilePhotoPicker extends StatefulWidget {
  const ProfilePhotoPicker({super.key, required this.name, required this.photo, required this.onChanged, this.onBusy});
  final String name;
  final String? photo;
  final ValueChanged<String?> onChanged;
  final ValueChanged<bool>? onBusy;

  @override
  State<ProfilePhotoPicker> createState() => _ProfilePhotoPickerState();
}

class _ProfilePhotoPickerState extends State<ProfilePhotoPicker> {
  bool _preparing = false;
  String? _status;
  bool _error = false;

  Future<void> _choose() async {
    final copy = AppStrings.of(context);
    final file = await FilePicker.pickFile(type: FileType.image);
    if (file == null || !mounted) return;
    setState(() {
      _preparing = true;
      _status = null;
      _error = false;
    });
    widget.onBusy?.call(true);
    try {
      final prepared = await prepareProfilePhoto(await file.readAsBytes());
      if (!mounted) return;
      widget.onChanged(prepared.dataUrl);
      setState(() => _status = prepared.compressed
          ? copy.text('Photo compressed to {size} to fit the 1 MB limit.').replaceAll('{size}', _sizeLabel(prepared.bytes, copy.isFrench))
          : null);
    } catch (error) {
      if (!mounted) return;
      final tooLarge = error is ProfilePhotoException && error.problem == ProfilePhotoProblem.tooLarge;
      setState(() {
        _error = true;
        _status = copy.text(tooLarge
            ? 'This photo can’t be reduced below 1 MB. Choose a smaller one.'
            : 'This image can’t be read. Choose a JPEG, PNG or WebP photo.');
      });
    } finally {
      if (mounted) setState(() => _preparing = false);
      widget.onBusy?.call(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final compact = MediaQuery.sizeOf(context).width < 490;
    final muted = scheme.onSurfaceVariant;
    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.tonalIcon(
          onPressed: _preparing ? null : _choose,
          icon: _preparing
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.photo_camera_outlined, size: 18),
          label: Text(copy.text(_preparing ? 'Preparing photo…' : widget.photo == null ? 'Choose a photo' : 'Change photo')),
        ),
        if (widget.photo != null && !_preparing)
          TextButton.icon(
            onPressed: () {
              widget.onChanged(null);
              setState(() => _status = null);
            },
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: Text(copy.text('Remove photo')),
          ),
      ],
    );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: theme.brightness == Brightness.dark ? .45 : .55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: compact ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          ProfileAvatar(name: widget.name, photo: widget.photo, size: compact ? 64 : 84),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(TextSpan(children: [
                  TextSpan(text: copy.text('Profile photo'), style: const TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: '  ${copy.text('Optional')}', style: TextStyle(color: muted, fontSize: 12)),
                ])),
                const SizedBox(height: 8),
                actions,
                const SizedBox(height: 6),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _status ?? copy.text('JPEG, PNG or WebP. Photos over 1 MB are compressed automatically.'),
                    style: TextStyle(color: _error ? scheme.error : muted, fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
