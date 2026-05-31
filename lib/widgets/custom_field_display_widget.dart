import 'package:flutter/material.dart';
import '../models/custom_field_model.dart';

class CustomFieldDisplayWidget extends StatelessWidget {
  final String entityId;
  final String entityType;
  final List<CustomField> fields;

  const CustomFieldDisplayWidget({
    super.key,
    required this.entityId,
    required this.entityType,
    required this.fields,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (fields.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final field in fields) ...[
          _buildFieldRow(context, cs, field),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildFieldRow(BuildContext context, ColorScheme cs, CustomField field) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            field.fieldLabel,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            field.defaultValue ?? '',
            style: TextStyle(fontSize: 14, color: cs.onSurface),
          ),
        ),
      ],
    );
  }
}
