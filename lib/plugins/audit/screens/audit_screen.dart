import 'package:flutter/material.dart';
import '../../../services/database_helper.dart';
import '../../../services/hash_chain_verify_result.dart';
import '../services/audit_service.dart';

class AuditScreen extends StatefulWidget {
  const AuditScreen({super.key});

  @override
  State<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends State<AuditScreen> {
  AuditResult? _result;
  bool _isLoading = true;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final db = await DatabaseHelper().database;
    final result = await AuditService.runFullAudit(db);
    if (!mounted) return;
    setState(() {
      _result = result;
      _isLoading = false;
    });
  }

  Future<void> _verify() async {
    setState(() => _isVerifying = true);
    final db = await DatabaseHelper().database;
    final result = await AuditService.runFullAudit(db);
    if (!mounted) return;
    setState(() {
      _result = result;
      _isVerifying = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('AD:ハッシュチェーン監査'),
        actions: [
          IconButton(
            icon: _isVerifying
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: _isVerifying ? null : _verify,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(theme),
    );
  }

  Widget _buildContent(ThemeData theme) {
    final result = _result!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildStatusCard(theme, result),
        const SizedBox(height: 16),
        _buildDetailCard(theme, '顧客', result.lastCustomerCheck),
        const SizedBox(height: 8),
        _buildDetailCard(theme, '商品', result.lastProductCheck),
        const SizedBox(height: 8),
        _buildDetailCard(theme, '請求書', result.lastInvoiceCheck),
        const SizedBox(height: 8),
        _buildDetailCard(theme, '伝票', result.lastDocumentCheck),
      ],
    );
  }

  Widget _buildStatusCard(ThemeData theme, AuditResult result) {
    final healthy = result.chainHealthy;
    return Card(
      color: healthy
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              healthy ? Icons.verified_rounded : Icons.error_outline_rounded,
              size: 48,
              color: healthy
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.onErrorContainer,
            ),
            const SizedBox(height: 12),
            Text(
              healthy ? 'チェーン整合性: OK' : '改ざん検出',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: healthy
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ハッシュエントリ: ${result.totalHashEntries}件',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: healthy
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onErrorContainer,
              ),
            ),
            if (result.lastFullVerifyAt != null)
              Text(
                '最終検証: ${_formatDateTime(result.lastFullVerifyAt!)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: healthy
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onErrorContainer,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard(
    ThemeData theme,
    String label,
    HashChainVerifyResult? check,
  ) {
    if (check == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(label, style: theme.textTheme.titleSmall),
              const Spacer(),
              Text('データなし', style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      );
    }
    return Card(
      color: check.isHealthy ? null : theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(label, style: theme.textTheme.titleSmall),
                const Spacer(),
                Icon(
                  check.isHealthy ? Icons.check_circle : Icons.cancel,
                  size: 18,
                  color: check.isHealthy
                      ? theme.colorScheme.primary
                      : theme.colorScheme.error,
                ),
                const SizedBox(width: 4),
                Text(
                  check.isHealthy ? '正常' : '${check.brokenCount}件異常',
                  style: TextStyle(
                    color: check.isHealthy
                        ? theme.colorScheme.primary
                        : theme.colorScheme.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${check.checked}件検証 @ ${_formatDateTime(check.verifiedAt)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (!check.isHealthy)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '異常ID: ${check.brokenIds.join(", ")}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/'
        '${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}
