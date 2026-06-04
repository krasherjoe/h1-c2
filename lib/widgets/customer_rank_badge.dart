import 'package:flutter/material.dart';
import '../models/customer_model.dart';

class CustomerRankBadge extends StatelessWidget {
  final CustomerRank rank;
  final int? discountRateOverride;
  final bool compact;

  const CustomerRankBadge({
    super.key,
    required this.rank,
    this.discountRateOverride,
    this.compact = false,
  });

  static Color rankColor(CustomerRank r, BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    switch (r) {
      case CustomerRank.vip:
        return cs.tertiaryContainer;
      case CustomerRank.gold:
        return cs.secondaryContainer;
      case CustomerRank.silver:
        return cs.surfaceContainerHighest;
      case CustomerRank.bronze:
        return cs.primaryContainer;
      case CustomerRank.none:
        return Theme.of(context).disabledColor;
    }
  }

  static IconData iconFor(CustomerRank r) {
    switch (r) {
      case CustomerRank.vip:
        return Icons.diamond;
      case CustomerRank.gold:
        return Icons.star;
      case CustomerRank.silver:
        return Icons.star_half;
      case CustomerRank.bronze:
        return Icons.star_border;
      case CustomerRank.none:
        return Icons.person_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (rank == CustomerRank.none) return const SizedBox.shrink();
    final color = rankColor(rank, context);
    final discount = discountRateOverride ?? rank.defaultDiscountRate;
    final showDiscount = !compact && discount > 0;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconFor(rank), size: compact ? 12 : 14, color: color),
          const SizedBox(width: 3),
          Text(
            rank.label,
            style: TextStyle(
              color: color,
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          if (showDiscount) ...[
            const SizedBox(width: 4),
            Text(
              '-$discount%',
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
