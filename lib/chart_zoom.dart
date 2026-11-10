import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'design_tokens.dart';

/// Zoom on a chart's horizontal axis (T23/4): consecutive points from [start]
/// to [end], end excluded. Same rules as `brainy_web_app/lib/chart-zoom.ts`.
@immutable
class ChartWindow {
  const ChartWindow(this.start, this.end);
  const ChartWindow.full(int total) : start = 0, end = total;

  final int start;
  final int end;

  int get span => end - start;

  @override
  bool operator ==(Object other) => other is ChartWindow && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'ChartWindow($start, $end)';
}

/// The narrowest window keeps enough points to read a trend.
const minZoomPoints = 5;
const zoomStep = 0.5;

bool isZoomed(ChartWindow window, int total) => window.start > 0 || window.end < total;
bool canZoomIn(ChartWindow window, int total) => window.span > math.min(total, minZoomPoints);

ChartWindow clampWindow(num start, num end, int total) {
  if (total <= 0) return const ChartWindow(0, 0);
  final floor = math.min(total, minZoomPoints);
  final span = math.min(total, math.max(floor, (end - start).round()));
  final first = math.max(0, math.min(total - span, start.round()));
  return ChartWindow(first, first + span);
}

/// Scales the window by [factor] (below 1 zooms in) around [anchor], a share
/// of the visible width from 0 to 1: the point under the pointer stays there.
ChartWindow zoomWindow(ChartWindow window, int total, double factor, [double anchor = 0.5]) {
  final span = window.span;
  final next = math.min(total, math.max(math.min(total, minZoomPoints), (span * factor).round()));
  if (next == span) return clampWindow(window.start, window.end, total);
  final share = anchor.clamp(0.0, 1.0);
  final focus = window.start + share * span;
  return clampWindow(focus - share * next, focus - share * next + next, total);
}

ChartWindow shiftWindow(ChartWindow window, int total, int delta) =>
    clampWindow(window.start + delta, window.end + delta, total);

/// Zoom and pan state shared by the analysis charts.
class ChartZoom extends ChangeNotifier {
  ChartZoom(this._total) : _window = ChartWindow.full(_total);

  int _total;
  ChartWindow _window;
  final _touches = <int, double>{};
  ({double distance, ChartWindow window, double anchor})? _pinch;

  int get total => _total;
  ChartWindow get window => _window;
  bool get zoomed => isZoomed(_window, _total);
  bool get canZoomIn => _window.span > math.min(_total, minZoomPoints);

  set total(int value) {
    if (value == _total) return;
    _total = value;
    _window = ChartWindow.full(value);
    notifyListeners();
  }

  void _set(ChartWindow next) {
    if (next == _window) return;
    _window = next;
    notifyListeners();
  }

  void zoomBy(double factor, [double anchor = 0.5]) => _set(zoomWindow(_window, _total, factor, anchor));
  void shift(int delta) => _set(shiftWindow(_window, _total, delta));
  void moveTo(int start) => _set(clampWindow(start, start + _window.span, _total));
  void reset() => _set(ChartWindow.full(_total));

  /// + and − zoom around [anchor], 0 shows everything.
  KeyEventResult onKey(KeyEvent event, double anchor) {
    final character = event.character;
    if (character == '+' || character == '=' || event.logicalKey == LogicalKeyboardKey.numpadAdd) {
      zoomBy(zoomStep, anchor);
      return KeyEventResult.handled;
    }
    if (character == '-' || event.logicalKey == LogicalKeyboardKey.numpadSubtract) {
      zoomBy(1 / zoomStep, anchor);
      return KeyEventResult.handled;
    }
    if ((character == '0' || event.logicalKey == LogicalKeyboardKey.numpad0) && zoomed) {
      reset();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Trackpad pinch, or Ctrl + wheel; a plain wheel keeps scrolling the page.
  void onPointerSignal(PointerSignalEvent event, double Function(Offset) shareAt) {
    if (event is PointerScaleEvent) {
      zoomBy(1 / event.scale, shareAt(event.localPosition));
    } else if (event is PointerScrollEvent && HardwareKeyboard.instance.isControlPressed) {
      GestureBinding.instance.pointerSignalResolver.register(event, (_) => zoomBy(math.exp(event.scrollDelta.dy * 0.01), shareAt(event.localPosition)));
    }
  }

  /// Two fingers pinch on a touch screen; one finger keeps selecting points.
  void onPointerDown(PointerDownEvent event, double Function(Offset) shareAt) {
    if (event.kind != PointerDeviceKind.touch) return;
    _touches[event.pointer] = event.localPosition.dx;
    if (_touches.length == 2) {
      final xs = _touches.values.toList();
      _pinch = (distance: math.max(8, (xs[0] - xs[1]).abs()), window: _window, anchor: shareAt(Offset((xs[0] + xs[1]) / 2, 0)));
    }
  }

  void onPointerMove(PointerMoveEvent event) {
    if (!_touches.containsKey(event.pointer)) return;
    _touches[event.pointer] = event.localPosition.dx;
    final pinch = _pinch;
    if (pinch == null || _touches.length != 2) return;
    final xs = _touches.values.toList();
    _set(zoomWindow(pinch.window, _total, pinch.distance / math.max(8, (xs[0] - xs[1]).abs()), pinch.anchor));
  }

  void onPointerEnd(PointerEvent event) {
    _touches.remove(event.pointer);
    if (_touches.length < 2) _pinch = null;
  }

  bool get pinching => _pinch != null;
}

class ChartZoomButtons extends StatelessWidget {
  const ChartZoomButtons({super.key, required this.zoom, required this.french});

  final ChartZoom zoom;
  final bool french;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: zoom,
    builder: (context, _) {
      Widget button(String label, IconData icon, VoidCallback? onPressed) => IconButton(
        tooltip: label,
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
      );
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(french ? 'Zoom avant' : 'Zoom in', Icons.zoom_in_rounded, zoom.canZoomIn ? () => zoom.zoomBy(zoomStep) : null),
          button(french ? 'Zoom arrière' : 'Zoom out', Icons.zoom_out_rounded, zoom.zoomed ? () => zoom.zoomBy(1 / zoomStep) : null),
          if (zoom.zoomed) button(french ? 'Tout afficher' : 'Show all', Icons.fit_screen_rounded, zoom.reset),
        ],
      );
    },
  );
}

/// A scroll bar for the zoomed window, operable by touch, mouse, keyboard and screen readers.
class ChartScrubber extends StatefulWidget {
  const ChartScrubber({super.key, required this.zoom, required this.french, required this.label});

  final ChartZoom zoom;
  final bool french;

  /// The first and last periods shown, for screen readers.
  final String label;

  @override
  State<ChartScrubber> createState() => _ChartScrubberState();
}

class _ChartScrubberState extends State<ChartScrubber> {
  final _focus = FocusNode(debugLabel: 'chart scroll bar');
  bool _focused = false;
  double? _grabX;
  int _grabStart = 0;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final zoom = widget.zoom;
    final window = zoom.window;
    final next = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowRight => window.start + 1,
      LogicalKeyboardKey.arrowLeft => window.start - 1,
      LogicalKeyboardKey.pageDown => window.start + window.span,
      LogicalKeyboardKey.pageUp => window.start - window.span,
      LogicalKeyboardKey.home => 0,
      LogicalKeyboardKey.end => zoom.total - window.span,
      _ => null,
    };
    if (next == null) return KeyEventResult.ignored;
    zoom.moveTo(next);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = ChartColors.of(theme.brightness);
    final zoom = widget.zoom;
    final french = widget.french;
    return ListenableBuilder(
      listenable: zoom,
      builder: (context, _) {
        if (!zoom.zoomed) return const SizedBox.shrink();
        final window = zoom.window;
        final total = zoom.total;
        return Semantics(
          slider: true,
          label: french ? 'Période affichée' : 'Shown period',
          value: widget.label,
          increasedValue: french ? 'Périodes suivantes' : 'Later periods',
          decreasedValue: french ? 'Périodes précédentes' : 'Earlier periods',
          onIncrease: () => zoom.shift(1),
          onDecrease: () => zoom.shift(-1),
          child: Focus(
            focusNode: _focus,
            onKeyEvent: _onKey,
            onFocusChange: (focused) => setState(() => _focused = focused),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                double toPoints(double dx) => dx / math.max(1, width) * total;
                return GestureDetector(
                  key: const ValueKey('chart-scrubber'),
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) {
                    _focus.requestFocus();
                    final at = toPoints(details.localPosition.dx);
                    if (at < window.start || at > window.end) zoom.moveTo((at - window.span / 2).round());
                  },
                  onHorizontalDragStart: (details) {
                    _grabX = details.localPosition.dx;
                    _grabStart = zoom.window.start;
                  },
                  onHorizontalDragUpdate: (details) {
                    final grab = _grabX;
                    if (grab != null) zoom.moveTo(_grabStart + toPoints(details.localPosition.dx - grab).round());
                  },
                  onHorizontalDragEnd: (_) => _grabX = null,
                  child: SizedBox(
                    height: 48,
                    child: Stack(
                      children: [
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 21,
                          height: 6,
                          child: DecoratedBox(decoration: BoxDecoration(color: colors.line, borderRadius: BorderRadius.circular(3))),
                        ),
                        Positioned(
                          left: width * window.start / total,
                          width: math.max(16, width * window.span / total),
                          top: 12,
                          height: 24,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: theme.colorScheme.primary, width: _focused ? 2 : 1),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
