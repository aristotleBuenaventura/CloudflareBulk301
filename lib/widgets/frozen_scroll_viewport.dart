import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Keeps [child] laid out at least [minWidth]×[minHeight]. When the parent
/// viewport is smaller, scroll bars appear instead of reflowing the layout.
class FrozenScrollViewport extends StatelessWidget {
  const FrozenScrollViewport({
    super.key,
    required this.minWidth,
    required this.minHeight,
    required this.child,
  });

  final double minWidth;
  final double minHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final frozen = constraints.maxWidth < minWidth ||
            constraints.maxHeight < minHeight;

        if (!frozen) {
          return child;
        }

        final width = math.max(constraints.maxWidth, minWidth);
        final height = math.max(constraints.maxHeight, minHeight);

        return SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width,
              height: height,
              child: child,
            ),
          ),
        );
      },
    );
  }
}
