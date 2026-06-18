import 'database_helper.dart';
import 'project_repository.dart';
import '../models/project_model.dart';

class CollectionProjectService {
  static Future<int> autoCreateCollectionProjects() async {
    try {
      final db = await DatabaseHelper().database;
      final rows = await db.rawQuery('''
        SELECT customer_id, customer_name,
               COUNT(*) as invoice_count,
               SUM(total - COALESCE(received_amount, 0)) as unpaid
        FROM documents
        WHERE document_type = 'invoice' AND status = 'confirmed'
          AND deleted_at IS NULL AND is_current = 1
          AND (payment_status IS NULL OR payment_status IN ('unpaid', 'partial'))
          AND date < date('now', '-60 days')
        GROUP BY customer_id
      ''');

      int created = 0;
      for (final row in rows) {
        final cid = row['customer_id'] as String? ?? '';
        final cname = row['customer_name'] as String? ?? '';
        final unpaid = (row['unpaid'] as num?)?.toInt() ?? 0;
        if (cid.isEmpty || unpaid <= 0) continue;

        final existing = await ProjectRepository().getByCustomer(cid);
        if (existing.any((p) =>
            p.type == ProjectType.collection &&
            p.status == ProjectStatus.active)) {
          continue;
        }

        final name = cname.isNotEmpty
            ? '$cname 未回収(${unpaid >= 10000 ? "¥${(unpaid / 10000).round()}万" : unpaid}円)'
            : '未回収案件';
        await ProjectRepository().createProject(
          name: name,
          customerId: cid,
          customerName: cname,
          type: 'collection',
        );
        created++;
      }
      return created;
    } catch (e) {
      return 0;
    }
  }
}
