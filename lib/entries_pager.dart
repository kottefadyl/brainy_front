import 'package:flutter/material.dart';

import 'app_strings.dart';
import 'design_tokens.dart';
import 'view_memory.dart';

/// Navigation through long entry lists: the range shown, first / previous / next / last, a page number
/// to type, a date to jump to and the page size. Thousands of entries stay a few steps away.
/// Same meaning as the web's `entries-pager.tsx`.
class EntriesPager extends StatefulWidget {
  const EntriesPager({
    super.key,
    required this.offset,
    required this.pageSize,
    required this.total,
    required this.shown,
    required this.hasMore,
    required this.busy,
    required this.dateJump,
    required this.onGo,
    required this.onDate,
    required this.onPageSize,
  });

  /// Position of the first entry shown (0-based).
  final int offset;
  final int pageSize;
  /// Entries matching in all pages; null while unknown.
  final int? total;
  /// Entries on this page.
  final int shown;
  final bool hasMore;
  final bool busy;
  /// Date jump makes sense when entries follow their creation date (not a manual order).
  final bool dateJump;
  final ValueChanged<int> onGo;
  final ValueChanged<DateTime> onDate;
  final ValueChanged<int> onPageSize;

  /// Hidden when everything fits in one page of the smallest size.
  static bool needed({required int offset, required int? total, required int shown, required bool hasMore}) =>
      total != 0 && !(offset == 0 && !hasMore && (total ?? shown) <= entryPageSizes.first);

  @override
  State<EntriesPager> createState() => _EntriesPagerState();
}

class _EntriesPagerState extends State<EntriesPager> {
  final _page = TextEditingController();

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  int? get _pages => widget.total == null ? null : ((widget.total! + widget.pageSize - 1) ~/ widget.pageSize).clamp(1, 1 << 30);
  int get _current => widget.offset ~/ widget.pageSize + 1;

  void _go(int page) {
    final last = _pages;
    final target = page < 1 ? 1 : (last != null && page > last ? last : page);
    widget.onGo((target - 1) * widget.pageSize);
  }

  void _submitPage() {
    final page = int.tryParse(_page.text.trim());
    if (page == null || page < 1) return;
    _page.clear();
    FocusScope.of(context).unfocus();
    _go(page);
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(1900), lastDate: DateTime(2100));
    if (value != null) widget.onDate(value);
  }

  @override
  Widget build(BuildContext context) {
    final fr = AppStrings.of(context).isFrench;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? BrainyColors.darkInk : BrainyColors.lightInk;
    final muted = dark ? BrainyColors.darkMuted : BrainyColors.lightMuted;
    final line = dark ? BrainyColors.darkLine : BrainyColors.lightLine;
    String format(int value) => groupedNumber(value, french: fr);
    final pages = _pages;
    final atStart = widget.offset == 0;
    final atEnd = pages != null ? _current >= pages : !widget.hasMore;
    final from = widget.shown == 0 ? 0 : widget.offset + 1;
    final to = widget.offset + widget.shown;
    final enabled = !widget.busy;
    Widget step(IconData icon, String label, bool disabled, VoidCallback action) => IconButton(
      tooltip: label,
      onPressed: enabled && !disabled ? action : null,
      icon: Icon(icon, semanticLabel: label),
      constraints: const BoxConstraints.tightFor(width: 48, height: 48),
    );
    final range = Text.rich(
      TextSpan(
        style: TextStyle(color: muted, fontSize: 13.5),
        children: [
          TextSpan(text: fr ? 'Entrées ' : 'Entries '),
          TextSpan(text: '${format(from)}–${format(to)}', style: TextStyle(color: ink, fontWeight: FontWeight.w600, fontFeatures: const [FontFeature.tabularFigures()])),
          if (widget.total != null) ...[
            TextSpan(text: fr ? ' sur ' : ' of '),
            TextSpan(text: format(widget.total!), style: TextStyle(color: ink, fontWeight: FontWeight.w600, fontFeatures: const [FontFeature.tabularFigures()])),
          ],
        ],
      ),
    );
    final steps = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        step(Icons.first_page, fr ? 'Première page' : 'First page', atStart, () => _go(1)),
        step(Icons.chevron_left, fr ? 'Page précédente' : 'Previous page', atStart, () => _go(_current - 1)),
        SizedBox(
          width: 72,
          height: 40,
          child: TextField(
            controller: _page,
            enabled: enabled,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            textInputAction: TextInputAction.go,
            onSubmitted: (_) => _submitPage(),
            decoration: InputDecoration(
              isDense: true,
              hintText: format(_current),
              hintStyle: TextStyle(color: ink),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(9)),
            ),
            style: TextStyle(color: ink, fontFeatures: const [FontFeature.tabularFigures()]),
            // Screen readers hear the current page and what the field does.
            buildCounter: null,
          ),
        ),
        if (pages != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text('${fr ? 'sur' : 'of'} ${format(pages)}', style: TextStyle(color: muted, fontSize: 13.5)),
          ),
        TextButton(onPressed: enabled ? _submitPage : null, child: Text(fr ? 'Aller' : 'Go')),
        step(Icons.chevron_right, fr ? 'Page suivante' : 'Next page', atEnd, () => _go(_current + 1)),
        if (pages != null) step(Icons.last_page, fr ? 'Dernière page' : 'Last page', atEnd, () => _go(pages)),
      ],
    );
    final options = Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (widget.dateJump)
          TextButton.icon(
            onPressed: enabled ? _pickDate : null,
            icon: const Icon(Icons.event_outlined, size: 18),
            label: Text(fr ? 'Aller à la date' : 'Go to date'),
          ),
        MenuAnchor(
          builder: (context, controller, _) => TextButton.icon(
            onPressed: enabled ? () => controller.isOpen ? controller.close() : controller.open() : null,
            icon: const Icon(Icons.format_list_numbered, size: 18),
            label: Text('${fr ? 'Par page' : 'Per page'} : ${widget.pageSize}'),
          ),
          menuChildren: [
            for (final size in entryPageSizes)
              MenuItemButton(
                leadingIcon: Icon(size == widget.pageSize ? Icons.check : null, size: 18),
                onPressed: () => widget.onPageSize(size),
                child: Text(format(size)),
              ),
          ],
        ),
      ],
    );
    return Semantics(
      container: true,
      label: fr ? 'Pages d’entrées' : 'Entry pages',
      child: AnimatedOpacity(
        opacity: widget.busy ? .7 : 1,
        duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 120),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: dark ? BrainyColors.darkSurface : BrainyColors.lightSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: line),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) => constraints.maxWidth >= 760
                ? Row(children: [range, const Spacer(), steps, const SizedBox(width: 12), options])
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(padding: const EdgeInsets.only(top: 6), child: range),
                      FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: steps),
                      options,
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// 4512 → "4,512" (English) or "4 512" (French, narrow no-break space).
String groupedNumber(int value, {required bool french}) {
  final digits = value.abs().toString();
  final buffer = StringBuffer(value < 0 ? '-' : '');
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(french ? ' ' : ',');
    buffer.write(digits[index]);
  }
  return buffer.toString();
}
