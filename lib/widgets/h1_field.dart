import 'package:flutter/material.dart';
import '../services/input_style_service.dart';

class H1Field extends StatelessWidget {
  final Widget child;
  const H1Field(this.child, {super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: inputStyleNotifier,
      builder: (context, style, _) {
        if (style != 'raised') return child;
        return Material(
          elevation: 2,
          borderRadius: BorderRadius.circular(8),
          color: Colors.transparent,
          shadowColor: Colors.black26,
          type: MaterialType.card,
          child: child,
        );
      },
    );
  }
}
