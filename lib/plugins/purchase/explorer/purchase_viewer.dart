import 'package:flutter/material.dart';
import '../models/purchase_model.dart';
import '../logic/purchase_converter.dart';
import '../services/purchase_repository.dart';
import '../../../services/error_reporter.dart';
import '../../inventory/services/stock_transaction_repository.dart';
import 'purchase_preview_page.dart';

class PurchaseViewer extends StatelessWidget {
  final PurchaseModel purchase;

  const PurchaseViewer({super.key, required this.purchase});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHeader(context, theme),
        const Divider(height: 24),
        _buildItemsSection(context, theme),
        const Divider(height: 24),
        _buildTotalSection(theme),
        const SizedBox(height: 12),
        _buildPreviewButton(context),
        if (purchase.isConfirmed) ...[
          const Divider(height: 24),
          _buildConvertButton(context),
        ],
      ],
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Chip(label: Text(purchase.purchaseType.label)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: purchase.isDraft ? theme.colorScheme.tertiaryContainer : theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                purchase.isDraft ? '下書き' : '確定',
                style: TextStyle(
                  fontSize: 12,
                  color: purchase.isDraft ? theme.colorScheme.onTertiaryContainer : theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(purchase.documentNumber, style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text('仕入先: ${purchase.supplierName}'),
        Text('日付: ${_formatDate(purchase.date)}'),
        if (purchase.linkedDocumentId != null)
          Text('元伝票: ${purchase.linkedDocumentId}'),
      ],
    );
  }

  Widget _buildItemsSection(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('明細', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        ...purchase.items.map((item) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.productName),
                    Text(
                      '${_formatQty(item.quantity)} × ${_formatMoney(item.unitPrice)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Text(_formatMoney(item.subtotal)),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildTotalSection(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('合計', style: theme.textTheme.titleMedium),
        Text(_formatMoney(purchase.total), style: theme.textTheme.titleMedium),
      ],
    );
  }

  Widget _buildConvertButton(BuildContext context) {
    final next = nextPurchaseType(purchase.purchaseType);
    if (next == null) return const SizedBox.shrink();
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.arrow_forward),
        label: Text('${next.label}へ変換'),
        onPressed: () async {
          try {
            final repo = PurchaseRepository();
            final newPurchase = convertPurchase(purchase.copyWith(
              id: repo.generateId(),
              documentNumber: await repo.generateDocumentNumber(next),
            ));
            await repo.save(newPurchase);

            // 入荷伝票の場合、在庫を自動入庫
            if (next == PurchaseType.receipt) {
              try {
                final stockRepo = StockTransactionRepository();
                for (final item in newPurchase.items) {
                  if (item.productId.isNotEmpty) {
                    await stockRepo.inbound(
                      productId: item.productId,
                      productName: item.productName,
                      quantity: item.quantity.round(),
                      referenceId: newPurchase.id,
                      referenceNumber: newPurchase.documentNumber,
                      notes: '発注 ${purchase.documentNumber} → 入荷による自動入庫',
                    );
                    debugPrint('[PurchaseViewer] Stock inbound: ${item.productName} x ${item.quantity}');
                  }
                }
              } catch (e) {
                debugPrint('[PurchaseViewer] Stock inbound error: $e');
                // 入庫失敗は伝票保存には影響しない
              }
            }

            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${next.label}伝票を作成しました')),
            );
          } catch (e) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('変換エラー: $e')),
            );
          }
        },
      ),
    );
  }

  Widget _buildPreviewButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.preview),
        label: const Text('プレビュー'),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PurchasePreviewPage(
                purchase: purchase,
                isUnlocked: purchase.isDraft,
                onFormalIssue: () async {
                  try {
                    final repo = PurchaseRepository();
                    final updated = purchase.copyWith(status: 'confirmed');
                    await repo.save(updated);
                    return true;
                  } catch (e, st) {
                    ErrorReporter.sendError(
                      message: '正式発行失敗: $e',
                      screenId: '/purchase/viewer',
                      stackTrace: st,
                    );
                    return false;
                  }
                },
                showShare: true,
                showPrint: true,
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime dt) =>
    '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';

  String _formatMoney(int amount) =>
    '¥${amount.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';

  String _formatQty(double qty) =>
    qty == qty.roundToDouble() ? qty.toInt().toString() : qty.toStringAsFixed(1);
}
