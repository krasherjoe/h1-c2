import 'package:flutter/material.dart';

class MenuCategoryHeader extends StatelessWidget {
  const MenuCategoryHeader({
    super.key,
    required this.title,
    this.description,
    this.showDescription = true,
    this.collapsible = false,
    this.collapsed = false,
    this.onToggle,
    this.padding = const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
    this.backgroundColor,
  });

  final String title;
  final String? description;
  final bool showDescription;
  final bool collapsible;
  final bool collapsed;
  final VoidCallback? onToggle;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold);
    final cs = Theme.of(context).colorScheme;
    final descriptionStyle = Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant);

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: titleStyle)),
            if (collapsible)
              AnimatedRotation(
                turns: collapsed ? 0.5 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.expand_more),
              ),
          ],
        ),
        if (showDescription && (description?.isNotEmpty ?? false))
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(description!, style: descriptionStyle),
          ),
      ],
    );

    if (collapsible) {
      content = InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(8),
        child: Padding(padding: padding, child: content),
      );
    } else {
      content = Padding(padding: padding, child: content);
    }

    if (backgroundColor != null) {
      content = Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: content,
      );
    }

    return content;
  }
}

class MenuCategoryDivider extends StatelessWidget {
  const MenuCategoryDivider({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = cs.outlineVariant;
    final titleStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: cs.onSurfaceVariant,
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: color, height: 1)),
          const SizedBox(width: 12),
          Text(title, style: titleStyle),
          const SizedBox(width: 12),
          Expanded(child: Divider(color: color, height: 1)),
        ],
      ),
    );
  }
}
