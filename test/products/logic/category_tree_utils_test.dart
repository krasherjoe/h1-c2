import 'package:flutter_test/flutter_test.dart';
import 'package:h_1_core/plugins/products/logic/category_tree_utils.dart';

void main() {
  group('wouldCreateCycle', () {
    test('ルートへの移動は循環しない', () {
      final parentOf = <String, String?>{
        '1': null,
        '2': '1',
        '3': '2',
      };
      expect(
        wouldCreateCycle(movingId: '3', newParentId: null, parentOf: parentOf),
        false,
      );
    });

    test('自分自身への移動は循環する', () {
      final parentOf = <String, String?>{
        '1': null,
        '2': '1',
        '3': '2',
      };
      expect(
        wouldCreateCycle(movingId: '3', newParentId: '3', parentOf: parentOf),
        true,
      );
    });

    test('自分の子孫への移動は循環する', () {
      final parentOf = <String, String?>{
        '1': null,
        '2': '1',
        '3': '2',
      };
      expect(
        wouldCreateCycle(movingId: '1', newParentId: '3', parentOf: parentOf),
        true,
      );
    });

    test('自分の孫への移動は循環する', () {
      final parentOf = <String, String?>{
        '1': null,
        '2': '1',
        '3': '2',
        '4': '3',
      };
      expect(
        wouldCreateCycle(movingId: '1', newParentId: '4', parentOf: parentOf),
        true,
      );
    });

    test('兄弟への移動は循環しない', () {
      final parentOf = <String, String?>{
        '1': null,
        '2': '1',
        '3': '1',
      };
      expect(
        wouldCreateCycle(movingId: '2', newParentId: '3', parentOf: parentOf),
        false,
      );
    });

    test('無関係なノードへの移動は循環しない', () {
      final parentOf = <String, String?>{
        '1': null,
        '2': '1',
        '3': null,
      };
      expect(
        wouldCreateCycle(movingId: '2', newParentId: '3', parentOf: parentOf),
        false,
      );
    });

    test('既存の循環を検出する', () {
      final parentOf = <String, String?>{
        '1': '2',
        '2': '1', // 循環
      };
      expect(
        wouldCreateCycle(movingId: '1', newParentId: '2', parentOf: parentOf),
        true,
      );
    });
  });
}
