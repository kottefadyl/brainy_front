import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:brainy/profile_photo.dart';
import 'package:brainy/profile_suggest_field.dart';
import 'package:brainy/profile_suggestions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('suggestions match either language, ignore accents and skip chosen values', () {
    expect(searchProfileSuggestions(occupationSuggestions, 'infirm', french: true), contains('Infirmier'));
    expect(searchProfileSuggestions(occupationSuggestions, 'nurse', french: true).first, 'Infirmier');
    expect(searchProfileSuggestions(occupationSuggestions, 'developpeur', french: true), contains('Développeur web'));
    expect(searchProfileSuggestions(hobbySuggestions, 'rand', french: true, exclude: ['Randonnée']), isNot(contains('Randonnée')));
    expect(searchProfileSuggestions(interestSuggestions, '', french: false).length, interestSuggestions.length);
    expect(occupationSuggestions.length, greaterThan(350));
  });

  test('small photos are kept and large photos are compressed under 1 MiB', () {
    final small = Uint8List.fromList(img.encodePng(img.Image(width: 20, height: 20)));
    final kept = prepareProfilePhotoSync(small);
    expect(kept.compressed, isFalse);
    expect(kept.dataUrl, startsWith('data:image/png;base64,'));

    final random = Random(7);
    final noisy = img.Image(width: 1400, height: 1000);
    for (final pixel in noisy) {
      pixel
        ..r = random.nextInt(256)
        ..g = random.nextInt(256)
        ..b = random.nextInt(256);
    }
    final large = Uint8List.fromList(img.encodePng(noisy));
    expect(large.length, greaterThan(profilePhotoMaxBytes));
    final prepared = prepareProfilePhotoSync(large);
    expect(prepared.compressed, isTrue);
    expect(prepared.bytes, lessThanOrEqualTo(profilePhotoMaxBytes));
    expect(base64Decode(prepared.dataUrl.split(',').last).length, prepared.bytes);
    expect(prepared.dataUrl, startsWith('data:image/jpeg;base64,'));
  });

  test('unreadable files are rejected', () {
    expect(
      () => prepareProfilePhotoSync(Uint8List.fromList(utf8.encode('not an image'))),
      throwsA(isA<ProfilePhotoException>()),
    );
  });
}
