import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/product_model.dart';
import '../../../services/product_repository.dart';
import '../../../services/master_csv_exporter.dart';
import '../../../widgets/generic_csv_import_screen.dart';

Future<void> importCsv(BuildContext context, VoidCallback onComplete) async {
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => GenericCsvImportScreen<Product>(
        screenId: 'P1',
        entityName: '商品',
        columns: const [
          ImportColumn(label: '商品名', required: true, matchKeywords: ['商品名', '品名', 'name', 'product']),
          ImportColumn(label: '販売価格', matchKeywords: ['販売', '価格', 'price', '単価']),
          ImportColumn(label: '仕入価格', matchKeywords: ['仕入', 'wholesale', '原価']),
          ImportColumn(label: 'バーコード', matchKeywords: ['バーコード', 'barcode', 'jan']),
          ImportColumn(label: 'カテゴリ', matchKeywords: ['カテゴリ', 'category', '分類']),
          ImportColumn(label: '型番', matchKeywords: ['型番', 'model']),
          ImportColumn(label: 'メーカー', matchKeywords: ['メーカー', 'manufacturer', 'maker']),
          ImportColumn(label: '在庫数', matchKeywords: ['在庫', 'stock', 'quantity']),
        ],
        onImport: (p) => ProductRepository().saveProduct(p),
        parser: (row, colMap, id) => Product(
          id: id,
          name: row[colMap[0]].trim(),
          defaultUnitPrice: colMap[1] >= 0 && colMap[1] < row.length
              ? int.tryParse(row[colMap[1]].replaceAll(',', '').replaceAll('¥', '').replaceAll('￥', '')) ?? 0
              : 0,
          wholesalePrice: colMap[2] >= 0 && colMap[2] < row.length
              ? int.tryParse(row[colMap[2]].replaceAll(',', '').replaceAll('¥', '').replaceAll('￥', '')) ?? 0
              : 0,
          barcode: colMap[3] >= 0 && colMap[3] < row.length ? row[colMap[3]].trim() : null,
          category: colMap[4] >= 0 && colMap[4] < row.length ? row[colMap[4]].trim() : null,
          modelNumber: colMap[5] >= 0 && colMap[5] < row.length ? row[colMap[5]].trim() : null,
          manufacturer: colMap[6] >= 0 && colMap[6] < row.length ? row[colMap[6]].trim() : null,
          stockQuantity: colMap[7] >= 0 && colMap[7] < row.length
              ? int.tryParse(row[colMap[7]].replaceAll(',', ''))
              : null,
        ),
        previewText1: (p) => p.name,
        previewText2: (p) => '¥${NumberFormat("#,###").format(p.defaultUnitPrice)}',
      ),
    ),
  );
  if (!context.mounted) return;
  onComplete();
}

void exportCsv(List<Product> products) {
  MasterCsvExporter.export(
    entityName: '商品',
    headers: ['商品名', '販売価格', '仕入価格', 'バーコード', 'カテゴリ', '型番', 'メーカー', '在庫数'],
    rows: products.map((p) => [
      p.name,
      p.defaultUnitPrice.toString(),
      p.wholesalePrice.toString(),
      p.barcode ?? '',
      p.category ?? '',
      p.modelNumber ?? '',
      p.manufacturer ?? '',
      p.stockQuantity?.toString() ?? '',
    ]).toList(),
  );
}
