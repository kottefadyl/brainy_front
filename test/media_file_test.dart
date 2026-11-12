import 'package:brainy/media_file.dart';
import 'package:flutter_test/flutter_test.dart';

// Vercel's free plan: pictures, videos, sound and PDF files are refused before upload.
void main() {
  test('media files are recognised by their name', () {
    for (final name in ['photo.JPG', 'scan.pdf', 'clip.mp4', 'voice.m4a', 'image.heic', 'logo.svg']) {
      expect(isMediaFileName(name), isTrue, reason: name);
    }
    for (final name in ['notes.txt', 'budget.xlsx', 'contract.docx', 'data.csv', 'pdf-notes.txt']) {
      expect(isMediaFileName(name), isFalse, reason: name);
    }
    expect(mediaRefusedText(true), contains('PDF'));
  });
}
