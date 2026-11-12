// T47/1: the book as a PDF on mobile and desktop, laid out with the book view settings (page size,
// margins, font size, line spacing, first-line indent, justified text, chapter on a new page).
// Pure Dart (package pdf): the file is then saved with the system file dialog.
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'book_model.dart';

const _pageMm = {'A5': (148.0, 210.0), 'A4': (210.0, 297.0), 'POCKET': (110.0, 178.0)};

/// The built-in PDF fonts only cover Latin-1: typographic signs become their plain equivalents.
String pdfSafe(String text) {
  const replacements = {'’': "'", '‘': "'", '“': '"', '”': '"', '«': '«', '»': '»', '–': '-', '—': '-', '…': '...', 'œ': 'oe', 'Œ': 'OE', ' ': ' ', ' ': ' '};
  final buffer = StringBuffer();
  for (final rune in text.runes) {
    final char = String.fromCharCode(rune);
    final replaced = replacements[char];
    if (replaced != null) {
      buffer.write(replaced);
    } else if (rune < 256) {
      buffer.write(char);
    } else {
      buffer.write('?');
    }
  }
  return buffer.toString();
}

Future<pw.ThemeData> _theme(BookSettings settings) async {
  if (settings.bodyFont == 'SANS') {
    final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-400.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-700.ttf'));
    return pw.ThemeData.withFont(base: regular, bold: bold, italic: regular, boldItalic: bold);
  }
  if (settings.bodyFont == 'MONO') return pw.ThemeData.withFont(base: pw.Font.courier(), bold: pw.Font.courierBold(), italic: pw.Font.courierOblique(), boldItalic: pw.Font.courierBoldOblique());
  return pw.ThemeData.withFont(base: pw.Font.times(), bold: pw.Font.timesBold(), italic: pw.Font.timesItalic(), boldItalic: pw.Font.timesBoldItalic());
}

/// Builds the PDF of the book outline.
Future<Uint8List> buildBookPdf({required BookOutline outline, required BookSettings settings, required String bookTitle, required bool french}) async {
  final sanitize = settings.bodyFont == 'SANS' ? (String text) => text : pdfSafe;
  final (widthMm, heightMm) = _pageMm[settings.pageSize] ?? _pageMm['A5']!;
  final format = PdfPageFormat(widthMm * PdfPageFormat.mm, heightMm * PdfPageFormat.mm, marginAll: settings.marginMm * PdfPageFormat.mm);
  final size = settings.fontSize * .75; // CSS pixels to points
  final body = pw.TextStyle(fontSize: size, lineSpacing: size * (settings.lineHeight - 1));
  final muted = PdfColor.fromInt(0xFF555555);
  final align = settings.textAlign == 'JUSTIFY' ? pw.TextAlign.justify : pw.TextAlign.left;
  final document = pw.Document(theme: await _theme(settings), title: sanitize(bookTitle));

  pw.Widget rich(String text, {pw.TextStyle? style, pw.TextAlign? textAlign}) => pw.RichText(
        textAlign: textAlign ?? align,
        text: pw.TextSpan(style: style ?? body, children: [
          for (final run in inlineRuns(text))
            pw.TextSpan(text: sanitize(run.text), style: pw.TextStyle(fontWeight: run.bold ? pw.FontWeight.bold : null, fontStyle: run.italic ? pw.FontStyle.italic : null)),
        ]),
      );

  List<pw.Widget> prose(String text) => [
        for (final block in textBlocks(text))
          switch (block.kind) {
            'break' => pw.Padding(padding: pw.EdgeInsets.symmetric(vertical: size * .6), child: pw.Center(child: pw.Text('*   *   *', style: body))),
            'heading' => pw.Padding(padding: pw.EdgeInsets.only(top: size * .8, bottom: size * .4), child: rich(block.text, style: body.copyWith(fontSize: size * 1.2, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.left)),
            'quote' => pw.Padding(padding: pw.EdgeInsets.fromLTRB(size * 2, size * .3, size, size * .3), child: rich(block.text, style: body.copyWith(fontStyle: pw.FontStyle.italic))),
            _ => pw.Padding(
                padding: pw.EdgeInsets.only(bottom: size * settings.paragraphSpacing),
                // The first-line indent is drawn as leading spaces, which the PDF text keeps.
                child: rich('${(settings.bodyFont == 'SANS' ? ' ' : '  ') * (settings.firstLineIndent * 2).round()}${block.text}'),
              ),
          },
      ];

  pw.Widget heading(String text, double scale, {pw.TextAlign textAlign = pw.TextAlign.left}) =>
      pw.Padding(padding: pw.EdgeInsets.only(bottom: size * .8), child: pw.Text(sanitize(text), textAlign: textAlign, style: body.copyWith(fontSize: size * scale, fontWeight: pw.FontWeight.bold)));
  pw.Widget kicker(String text) => pw.Padding(padding: pw.EdgeInsets.only(top: size * 2, bottom: size * .4), child: pw.Text(sanitize(text.toUpperCase()), style: body.copyWith(fontSize: size * .8, color: muted, letterSpacing: 1.5)));

  pw.Widget footer(pw.Context context) => pw.Center(child: pw.Text('${context.pageNumber}', style: body.copyWith(fontSize: size * .75, color: muted)));
  void page(List<pw.Widget> content, {bool numbered = true}) => document.addPage(pw.MultiPage(pageFormat: format, footer: numbered ? footer : null, build: (_) => content));

  final cover = outline.front.where((item) => item.role == 'COVER').firstOrNull;
  if (cover != null) {
    document.addPage(pw.Page(pageFormat: format, build: (_) => pw.Column(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
          if (cover.values('TEXT').length > 1 && cover.values('TEXT')[1].isNotEmpty) pw.Text(sanitize(cover.values('TEXT')[1]), style: body.copyWith(color: muted)),
          pw.SizedBox(height: size),
          pw.Text(sanitize(cover.title.isEmpty ? bookTitle : cover.title), textAlign: pw.TextAlign.center, style: body.copyWith(fontSize: size * 2.4, fontWeight: pw.FontWeight.bold)),
          if (cover.value('TEXT').isNotEmpty) pw.Padding(padding: pw.EdgeInsets.only(top: size), child: pw.Text(sanitize(cover.value('TEXT')), textAlign: pw.TextAlign.center, style: body.copyWith(fontStyle: pw.FontStyle.italic))),
        ])));
  }
  for (final item in outline.front.where((item) => item.role != 'COVER')) {
    page([heading(item.title.isEmpty ? bookRoleLabel(item.role, french) : item.title, 1.5), ...prose(item.text), for (final line in item.values('TEXT').where((value) => value.isNotEmpty)) pw.Text(sanitize(line), style: body.copyWith(color: muted))]);
  }

  final chapters = outline.chapters;
  if (chapters.isNotEmpty) {
    page([
      heading(french ? 'Table des matières' : 'Contents', 1.5),
      for (final part in outline.parts) ...[
        pw.Text(sanitize('${bookRoleLabel('PART', french)} ${romanNumeral(part.number)}  ${part.title}'), style: body.copyWith(fontWeight: pw.FontWeight.bold)),
        for (final chapter in part.children) pw.Padding(padding: pw.EdgeInsets.only(left: size * 1.5), child: pw.Text(sanitize('${chapter.number}.  ${chapter.title}'), style: body)),
      ],
      for (final chapter in outline.looseChapters) pw.Text(sanitize('${chapter.number}.  ${chapter.title}'), style: body),
    ]);
  }

  List<pw.Widget> chapterContent(BookNode chapter) => [
        kicker('${bookRoleLabel('CHAPTER', french)} ${chapter.number}'),
        heading(chapter.title, 1.7),
        ...prose(chapter.text),
        for (final section in chapter.children) ...[
          heading('${chapter.number}.${section.number}  ${section.title}', 1.25),
          ...prose(section.text),
          for (final sub in section.children) ...[heading('${chapter.number}.${section.number}.${sub.number}  ${sub.title}', 1.1), ...prose(sub.text)],
        ],
      ];
  void chapterPages(List<BookNode> list) {
    if (list.isEmpty) return;
    if (settings.chapterOnNewPage) {
      for (final chapter in list) { page(chapterContent(chapter)); }
    } else {
      page([for (final chapter in list) ...chapterContent(chapter)]);
    }
  }
  for (final part in outline.parts) {
    page([pw.SizedBox(height: size * 8), pw.Center(child: kicker('${bookRoleLabel('PART', french)} ${romanNumeral(part.number)}')), pw.Center(child: heading(part.title, 2, textAlign: pw.TextAlign.center)), ...prose(part.text)]);
    chapterPages(part.children);
  }
  chapterPages(outline.looseChapters);

  for (final item in outline.back) { page([heading(item.title.isEmpty ? bookRoleLabel(item.role, french) : item.title, 1.5), ...prose(item.text)]); }
  for (var index = 0; index < outline.appendices.length; index++) {
    final item = outline.appendices[index];
    page([kicker('${bookRoleLabel('APPENDIX', french)} ${String.fromCharCode(65 + index)}'), heading(item.title, 1.5), ...prose(item.text)]);
  }
  if (outline.glossary.isNotEmpty) {
    page([heading(french ? 'Glossaire' : 'Glossary', 1.5), for (final term in outline.glossary) pw.Padding(padding: pw.EdgeInsets.only(bottom: size * .5), child: rich('**${term.title}** : ${term.text}'))]);
  }
  if (outline.sources.isNotEmpty) {
    page([heading(french ? 'Bibliographie' : 'Bibliography', 1.5), for (final source in outline.sources) pw.Padding(padding: pw.EdgeInsets.only(bottom: size * .4), child: rich([source.values('TEXT').firstOrNull ?? '', '*${source.title}*'].where((part) => part.isNotEmpty).join('. ')))]);
  }
  if (outline.indexTerms.isNotEmpty) {
    page([heading('Index', 1.5), for (final term in outline.indexTerms) pw.Text(sanitize('${term.term}  ${term.chapters.isEmpty ? '-' : '${french ? 'chap.' : 'ch.'} ${term.chapters.join(', ')}'}'), style: body)]);
  }
  if (document.document.pdfPageList.pages.isEmpty) page([heading(bookTitle, 1.5)]);
  return document.save();
}
