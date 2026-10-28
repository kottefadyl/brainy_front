// Regenerate platform icons after changing assets/branding/brainy_mark.png:
//   dart run tool/generate_brand_icons.dart
import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  final source = img.decodePng(
    File('assets/branding/brainy_mark.png').readAsBytesSync(),
  );
  if (source == null || source.width != source.height) {
    throw StateError('The Brainy mark must be a square PNG.');
  }

  img.Image resized(int size) => img.copyResize(
    source,
    width: size,
    height: size,
    interpolation: img.Interpolation.cubic,
  );

  img.Image onCanvas(int size, {double scale = 1, img.Color? background}) {
    final canvas = img.Image(width: size, height: size, numChannels: 4);
    if (background != null) img.fill(canvas, color: background);
    final markSize = (size * scale).round();
    img.compositeImage(
      canvas,
      resized(markSize),
      dstX: (size - markSize) ~/ 2,
      dstY: (size - markSize) ~/ 2,
    );
    return canvas;
  }

  void save(String path, img.Image image) {
    final file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(img.encodePng(image));
  }

  const androidSizes = {
    'mdpi': 48,
    'hdpi': 72,
    'xhdpi': 96,
    'xxhdpi': 144,
    'xxxhdpi': 192,
  };
  for (final entry in androidSizes.entries) {
    save(
      'android/app/src/main/res/mipmap-${entry.key}/ic_launcher.png',
      resized(entry.value),
    );
  }
  save(
    'android/app/src/main/res/drawable-nodpi/ic_launcher_foreground.png',
    onCanvas(432, scale: 0.67),
  );

  final iosDir = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
  final iosManifest = jsonDecode(
    File('$iosDir/Contents.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  for (final item in iosManifest['images'] as List<dynamic>) {
    final icon = item as Map<String, dynamic>;
    final filename = icon['filename'] as String?;
    if (filename == null) continue;
    final points = double.parse((icon['size'] as String).split('x').first);
    final scale = int.parse((icon['scale'] as String).replaceAll('x', ''));
    final size = (points * scale).round();
    save(
      '$iosDir/$filename',
      onCanvas(size, background: img.ColorRgb8(255, 255, 255)),
    );
  }

  final macDir = 'macos/Runner/Assets.xcassets/AppIcon.appiconset';
  for (final size in [16, 32, 64, 128, 256, 512, 1024]) {
    save('$macDir/app_icon_$size.png', resized(size));
  }

  final ico = resized(16);
  for (final size in [24, 32, 48, 64, 128, 256]) {
    ico.addFrame(resized(size));
  }
  File('windows/runner/resources/app_icon.ico')
      .writeAsBytesSync(img.encodeIco(ico));
}
