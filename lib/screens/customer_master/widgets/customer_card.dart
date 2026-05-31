import 'package:flutter/material.dart';
import '../../../models/customer_model.dart';
import '../../../widgets/customer_rank_badge.dart';

class CustomerCard extends StatelessWidget {
  final Customer customer;
  final bool showHidden;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const CustomerCard({
    super.key,
    required this.customer,
    this.showHidden = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final c = customer;
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 1,
      color: c.isHidden
          ? theme.colorScheme.surfaceContainerHighest
          : theme.cardColor,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(
                c.isLocked ? Icons.link : Icons.person,
                size: 20,
                color: c.isLocked
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            c.displayName,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: c.isHidden
                                  ? theme.colorScheme.onSurfaceVariant
                                  : theme.colorScheme.onSurface,
                              decoration: c.isHidden ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        CustomerRankBadge(rank: c.rank),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${c.formalName}  ${c.title}',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18),
                onSelected: (v) {},
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'detail', child: ListTile(leading: Icon(Icons.info_outline), title: Text('詳細'), dense: true)),
                  const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit), title: Text('編集'), dense: true)),
                  const PopupMenuItem(value: 'contact', child: ListTile(leading: Icon(Icons.contact_mail), title: Text('連絡先更新'), dense: true)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
