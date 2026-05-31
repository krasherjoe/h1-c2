import 'package:flutter/material.dart';

class KeyboardInsetWrapper extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry basePadding;
  final double extraBottom;

  const KeyboardInsetWrapper({
    super.key,
    required this.child,
    this.basePadding = EdgeInsets.zero,
    this.extraBottom = 0,
  });

  @override
  Widget build(BuildContext context) {
    if (basePadding == EdgeInsets.zero && extraBottom == 0) return child;
    return Padding(
      padding: basePadding.add(EdgeInsets.only(bottom: extraBottom)),
      child: child,
    );
  }
}
