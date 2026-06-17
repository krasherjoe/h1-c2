import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  late Map manifest;

  setUp(() {
    final file = File('docs/manifest.yaml');
    expect(file.existsSync(), isTrue, reason: 'docs/manifest.yaml が存在すること');
    final yamlString = file.readAsStringSync();
    final parsed = loadYaml(yamlString);
    expect(parsed, isA<YamlMap>(), reason: 'YAMLとしてパースできること');
    manifest = parsed as Map;
  });

  group('トップレベル', () {
    test('必須フィールドを持つ', () {
      expect(manifest, containsPair('version', '1.0.0'));
      expect(manifest, containsPair('last_updated', '2026-06-18'));
    });

    test('必須セクションを持つ', () {
      expect(manifest, contains('core_tables'));
      expect(manifest, contains('plugins'));
      expect(manifest, contains('services'));
    });
  });

  group('core_tables', () {
    test('全テーブルが必須フィールドを持つ', () {
      final tables = manifest['core_tables'] as Map;
      expect(tables, isNotEmpty);
      for (final entry in tables.entries) {
        final table = entry.value as Map;
        expect(table, contains('description'),
            reason: '${entry.key}: description が必要');
        expect(table, contains('columns'),
            reason: '${entry.key}: columns が必要');
        expect(table['columns'], isA<YamlList>(),
            reason: '${entry.key}: columns はリスト');
        expect(table, contains('used_by'),
            reason: '${entry.key}: used_by が必要');
      }
    });

    test('各カラムが必須フィールドを持つ', () {
      final tables = manifest['core_tables'] as Map;
      for (final entry in tables.entries) {
        final columns = entry.value['columns'] as List;
        for (final col in columns) {
          final c = col as Map;
          expect(c, contains('name'),
              reason: '${entry.key}.columns: name が必要');
          expect(c, contains('type'),
              reason: '${entry.key}.columns: type が必要');
        }
      }
    });
  });

  group('plugins', () {
    test('全プラグインが必須フィールドを持つ', () {
      final plugins = manifest['plugins'] as List;
      expect(plugins, isNotEmpty);
      for (final p in plugins) {
        final plugin = p as Map;
        expect(plugin, contains('id'),
            reason: 'plugin id が必要');
        expect(plugin, contains('name'),
            reason: '${plugin['id']}: name が必要');
        expect(plugin, contains('file'),
            reason: '${plugin['id']}: file が必要');
        expect(plugin, contains('screens'),
            reason: '${plugin['id']}: screens が必要');
        expect(plugin, contains('tables'),
            reason: '${plugin['id']}: tables が必要');
        expect(plugin, contains('services'),
            reason: '${plugin['id']}: services が必要');
      }
    });

    test('全プラグインのIDがユニーク', () {
      final plugins = manifest['plugins'] as List;
      final ids = plugins.map((p) => (p as Map)['id'] as String).toList();
      expect(ids.toSet().length, equals(ids.length),
          reason: 'プラグインIDが重複している');
    });

    test('全画面IDがユニーク', () {
      final plugins = manifest['plugins'] as List;
      final screenIds = <String>[];
      for (final p in plugins) {
        final screens = (p as Map)['screens'] as List;
        for (final s in screens) {
          screenIds.add((s as Map)['id'] as String);
        }
      }
      final duplicates =
          screenIds.groupBy((id) => id).entries.where((e) => e.value.length > 1).toList();
      expect(duplicates, isEmpty,
          reason: '画面IDが重複: ${duplicates.map((e) => e.key).join(', ')}');
    });

    test('各画面が id と route を持つ', () {
      final plugins = manifest['plugins'] as List;
      for (final p in plugins) {
        final screens = (p as Map)['screens'] as List;
        for (final s in screens) {
          final screen = s as Map;
          expect(screen, contains('id'),
              reason: '${p['id']}: screen.id が必要');
          expect(screen, contains('route'),
              reason: '${p['id']}: screen.route が必要');
        }
      }
    });

    test('各プラグインの file が実在する', () {
      final plugins = manifest['plugins'] as List;
      for (final p in plugins) {
        final filePath = (p as Map)['file'] as String;
        expect(File(filePath).existsSync(), isTrue,
            reason: '${p['id']}: $filePath が存在しない');
      }
    });
  });

  group('services', () {
    test('全サービスが必須フィールドを持つ', () {
      final services = manifest['services'] as List;
      expect(services, isNotEmpty);
      for (final s in services) {
        final svc = s as Map;
        expect(svc, contains('name'),
            reason: 'service name が必要');
        expect(svc, contains('file'),
            reason: '${svc['name']}: file が必要');
        expect(svc, contains('description'),
            reason: '${svc['name']}: description が必要');
        expect(svc, contains('methods'),
            reason: '${svc['name']}: methods が必要');
        expect(svc, contains('tables'),
            reason: '${svc['name']}: tables が必要');
      }
    });

    test('全サービスの file が実在する', () {
      final services = manifest['services'] as List;
      for (final s in services) {
        final filePath = (s as Map)['file'] as String;
        expect(File(filePath).existsSync(), isTrue,
            reason: '${s['name']}: $filePath が存在しない');
      }
    });

    test('各サービスが methods をリストとして持つ', () {
      final services = manifest['services'] as List;
      for (final s in services) {
        final methods = (s as Map)['methods'] as List;
        expect(methods, isA<YamlList>(),
            reason: '${s['name']}: methods はリスト型');
      }
    });
  });

  group('参照整合性', () {
    test('core_tables.used_by が plugins の id と一致する', () {
      final tables = manifest['core_tables'] as Map;
      final pluginIds = (manifest['plugins'] as List)
          .map((p) => (p as Map)['id'] as String)
          .toSet();
      for (final entry in tables.entries) {
        final usedBy = (entry.value as Map)['used_by'] as List;
        for (final ref in usedBy) {
          expect(pluginIds, contains(ref),
              reason: '${entry.key}.used_by に "$ref" が plugins に存在しない');
        }
      }
    });

    test('services.used_by が plugins の id と一致する', () {
      final services = manifest['services'] as List;
      final pluginIds = (manifest['plugins'] as List)
          .map((p) => (p as Map)['id'] as String)
          .toSet();
      for (final s in services) {
        final svc = s as Map;
        if (svc.containsKey('used_by')) {
          final usedBy = svc['used_by'] as List;
          for (final ref in usedBy) {
            expect(pluginIds, contains(ref),
                reason: '${svc['name']}.used_by に "$ref" が plugins に存在しない');
          }
        }
      }
    });
  });
}

extension GroupByExtension<T> on Iterable<T> {
  Map<K, List<T>> groupBy<K>(K Function(T) keyFn) {
    final map = <K, List<T>>{};
    for (final item in this) {
      final key = keyFn(item);
      map.putIfAbsent(key, () => []).add(item);
    }
    return map;
  }
}
