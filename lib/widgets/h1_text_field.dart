import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/input_style_service.dart';

class H1TextField extends StatelessWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final InputDecoration? decoration;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final TextStyle? style;
  final TextAlign textAlign;
  final bool obscureText;
  final bool? autocorrect;
  final bool enableSuggestions;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final MaxLengthEnforcement? maxLengthEnforcement;
  final bool expands;
  final bool readOnly;
  final bool autofocus;
  final bool? enabled;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onEditingComplete;
  final List<TextInputFormatter>? inputFormatters;
  final double cursorWidth;
  final double? cursorHeight;
  final Radius? cursorRadius;
  final Color? cursorColor;
  final bool? enableInteractiveSelection;
  final InputCounterWidgetBuilder? buildCounter;
  final ScrollController? scrollController;
  final ScrollPhysics? scrollPhysics;
  final Iterable<String>? autofillHints;

  const H1TextField({
    super.key,
    this.controller,
    this.focusNode,
    this.decoration = const InputDecoration(),
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.style,
    this.textAlign = TextAlign.start,
    this.obscureText = false,
    this.autocorrect,
    this.enableSuggestions = true,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.maxLengthEnforcement,
    this.expands = false,
    this.readOnly = false,
    this.autofocus = false,
    this.enabled,
    this.onChanged,
    this.onSubmitted,
    this.onEditingComplete,
    this.inputFormatters,
    this.cursorWidth = 2.0,
    this.cursorHeight,
    this.cursorRadius,
    this.cursorColor,
    this.enableInteractiveSelection,
    this.buildCounter,
    this.scrollController,
    this.scrollPhysics,
    this.autofillHints,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: inputStyleNotifier,
      builder: (context, inputStyle, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final field = TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: decoration,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          style: style,
          textAlign: textAlign,
          obscureText: obscureText,
          autocorrect: autocorrect,
          enableSuggestions: enableSuggestions,
          maxLines: maxLines,
          minLines: minLines,
          maxLength: maxLength,
          maxLengthEnforcement: maxLengthEnforcement,
          expands: expands,
          readOnly: readOnly,
          autofocus: autofocus,
          enabled: enabled,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          onEditingComplete: onEditingComplete,
          inputFormatters: inputFormatters,
          cursorWidth: cursorWidth,
          cursorHeight: cursorHeight,
          cursorRadius: cursorRadius,
          cursorColor: cursorColor,
          enableInteractiveSelection: enableInteractiveSelection,
          buildCounter: buildCounter,
          scrollController: scrollController,
          scrollPhysics: scrollPhysics,
          autofillHints: autofillHints,
        );
        final Widget inkHost = Material(
          type: MaterialType.transparency,
          child: field,
        );
        if (inputStyle == 'raised') {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.12),
                ),
                BoxShadow(
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.08),
                ),
              ],
            ),
            child: inkHost,
          );
        }
        return inkHost;
      },
    );
  }
}
