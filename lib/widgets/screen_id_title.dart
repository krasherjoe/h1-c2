import 'package:flutter/material.dart';

class ScreenAppBarTitle extends StatelessWidget {
  const ScreenAppBarTitle({
    super.key,
    required this.screenId,
    required this.title,
    this.caption,
  });

  final String screenId;
  final String title;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryStyle = theme.appBarTheme.titleTextStyle ??
        theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$screenId: $title', style: primaryStyle),
        if (caption != null)
          Text(
            caption!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onPrimary.withValues(alpha: 0.7),
            ),
          ),
      ],
    );
  }
}
