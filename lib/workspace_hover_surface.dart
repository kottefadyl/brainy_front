import 'package:flutter/material.dart';

/// Shared pointer and keyboard feedback; touch keeps all actions visible.
class WorkspaceHoverSurface extends StatefulWidget {
  const WorkspaceHoverSurface({
    super.key,
    required this.color,
    required this.marker,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });
  final Color color;
  final Color marker;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  State<WorkspaceHoverSurface> createState() => _WorkspaceHoverSurfaceState();
}

class _WorkspaceHoverSurfaceState extends State<WorkspaceHoverSurface> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Focus(
        canRequestFocus: false,
        onFocusChange: (value) => setState(() => _focused = value),
        child: AnimatedContainer(
          duration: reduced ? Duration.zero : const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(
            0,
            _hovered && !reduced ? -2 : 0,
            0,
          ),
          padding: widget.padding,
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Color.lerp(
                widget.color,
                widget.marker,
                _hovered || _focused ? .45 : .16,
              )!,
            ),
            boxShadow: [
              if (_focused)
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary,
                  spreadRadius: 2,
                ),
              if (_hovered && !dark)
                BoxShadow(
                  color: widget.marker.withValues(alpha: .08),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
