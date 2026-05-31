import 'package:flutter/material.dart';

class InvoiceTableCell extends StatelessWidget {
  final String text;
  final Color? textColor;
  const InvoiceTableCell(this.text, {super.key, this.textColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        text,
        textAlign: TextAlign.right,
        style: TextStyle(fontSize: 12, color: textColor),
      ),
    );
  }
}

class InvoiceEditableCell extends StatelessWidget {
  final String initialValue;
  final TextInputType keyboardType;
  final Function(String) onChanged;
  final Color? textColor;

  const InvoiceEditableCell({
    super.key,
    required this.initialValue,
    required this.onChanged,
    this.keyboardType = TextInputType.text,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: TextField(
        controller: TextEditingController(text: initialValue),
        keyboardType: keyboardType,
        style: TextStyle(fontSize: 14, color: textColor),
        onChanged: onChanged,
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.all(8),
        ),
      ),
    );
  }
}
