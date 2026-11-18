import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A card that really turns over: front and back are the two sides of one card.
/// Once [turned], a tap turns it again to look at either side.
class FlipCard extends StatefulWidget {
  const FlipCard({super.key, required this.turned, required this.onTurn, required this.front, required this.back, required this.decoration, this.padding = const EdgeInsets.all(20)});

  final bool turned;
  final VoidCallback onTurn;
  final Widget front;
  final Widget back;
  final BoxDecoration decoration;
  final EdgeInsets padding;

  @override
  State<FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<FlipCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 560));
  late final Animation<double> _turn = CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic);
  bool _peekFront = false;

  bool get _showsBack => widget.turned && !_peekFront;

  @override
  void didUpdateWidget(covariant FlipCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.turned != oldWidget.turned) {
      _peekFront = false;
      _animate();
    }
  }

  void _animate() {
    if (MediaQuery.of(context).disableAnimations) {
      _controller.value = _showsBack ? 1 : 0;
    } else if (_showsBack) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  void _tap() {
    if (!widget.turned) {
      widget.onTurn();
    } else {
      setState(() => _peekFront = !_peekFront);
      _animate();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _side(Widget child) => SizedBox(width: double.infinity, child: child);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _tap,
      child: AnimatedBuilder(
        animation: _turn,
        builder: (context, _) {
          final angle = _turn.value * math.pi;
          final back = angle > math.pi / 2;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateY(angle),
            // Both sides keep their size so the card does not jump while turning.
            child: Container(padding: widget.padding, decoration: widget.decoration, child: Stack(alignment: Alignment.center, children: [
              Visibility(visible: !back, maintainSize: true, maintainAnimation: true, maintainState: true, child: ExcludeSemantics(excluding: back, child: _side(widget.front))),
              Visibility(
                visible: back,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: ExcludeSemantics(excluding: !back, child: Transform(alignment: Alignment.center, transform: Matrix4.identity()..rotateY(math.pi), child: _side(widget.turned ? widget.back : const SizedBox.shrink()))),
              ),
            ])),
          );
        },
      ),
    );
  }
}
