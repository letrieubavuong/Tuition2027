// File: test/services/sync_queue_service_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tuition2025/utils/db.dart';
import 'package:tuition2025/services/sync_queue_service.dart';

void main() {
  late Database db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 33,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE sync_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            entity_type TEXT NOT NULL,
            record_key TEXT NOT NULL,
            operation TEXT NOT NULL,
            payload_json TEXT,
            created_at TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'DIRTY',
            retry_count INTEGER NOT NULL DEFAULT 0,
            last_error TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE sync_metadata (
            entity_type TEXT NOT NULL,
            record_key TEXT NOT NULL,
            local_version INTEGER NOT NULL DEFAULT 1,
            cloud_version INTEGER NOT NULL DEFAULT 0,
            local_updated_at TEXT NOT NULL,
            last_synced_at TEXT,
            content_hash TEXT NOT NULL,
            sync_status TEXT NOT NULL DEFAULT 'DIRTY',
            PRIMARY KEY (entity_type, record_key)
          )
        ''');
      },
    );
    DBHelper.setTestDatabase(db);
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'TEST 1: Canonical Content Hash is deterministic & ignores metadata keys',
    () {
      final payload1 = {
        'ten': 'Học sinh A',
        'id': 100,
        'updated_at': '2026-09-17T10:00:00.000',
        'sync_status': 'DIRTY',
      };

      final payload2 = {
        'sync_status': 'SYNCED',
        'id': 100,
        'updated_at': '2026-09-17T18:00:00.000',
        'ten': 'Học sinh A',
      };

      final hash1 = SyncQueueService.computeCanonicalContentHash(payload1);
      final hash2 = SyncQueueService.computeCanonicalContentHash(payload2);

      expect(hash1, equals(hash2));
      expect(hash1.length, equals(64)); // SHA-256 hex string length
    },
  );

  test(
    'TEST 2: Enqueue mutation creates DIRTY sync_queue item & updates sync_metadata',
    () async {
      await SyncQueueService.instance.enqueueMutation(
        entityType: 'hoc_sinh',
        recordKey: '101',
        operation: SyncOperation.upsert,
        payload: {'id': 101, 'ten': 'Học sinh B'},
      );

      final queueRows = await db.query('sync_queue');
      expect(queueRows.length, equals(1));
      expect(queueRows.first['entity_type'], equals('hoc_sinh'));
      expect(queueRows.first['record_key'], equals('101'));
      expect(queueRows.first['status'], equals('DIRTY'));

      final metaRows = await db.query('sync_metadata');
      expect(metaRows.length, equals(1));
      expect(metaRows.first['sync_status'], equals('DIRTY'));
    },
  );

  test(
    'TEST 3: Coalesce queue merges multiple non-financial edits for same record key',
    () async {
      await SyncQueueService.instance.enqueueMutation(
        entityType: 'hoc_sinh',
        recordKey: '102',
        operation: SyncOperation.upsert,
        payload: {'id': 102, 'ten': 'Học sinh V1'},
      );

      await SyncQueueService.instance.enqueueMutation(
        entityType: 'hoc_sinh',
        recordKey: '102',
        operation: SyncOperation.upsert,
        payload: {'id': 102, 'ten': 'Học sinh V2'},
      );

      final queueRows = await db.query(
        'sync_queue',
        where: 'record_key = ?',
        whereArgs: ['102'],
      );
      expect(queueRows.length, equals(1)); // Coalesced into 1 item
      expect(queueRows.first['payload_json'], contains('Học sinh V2'));
    },
  );

  test(
    'TEST 4: Financial mutations (payment_transactions) do NOT coalesce',
    () async {
      await SyncQueueService.instance.enqueueMutation(
        entityType: 'payment_transactions',
        recordKey: 'tx_1',
        operation: SyncOperation.upsert,
        payload: {'transaction_id': 'tx_1', 'amount': 500000},
      );

      await SyncQueueService.instance.enqueueMutation(
        entityType: 'payment_transactions',
        recordKey: 'tx_1',
        operation: SyncOperation.upsert,
        payload: {'transaction_id': 'tx_1', 'amount': 500000},
      );

      final queueRows = await db.query(
        'sync_queue',
        where: 'entity_type = ?',
        whereArgs: ['payment_transactions'],
      );
      expect(queueRows.length, equals(2)); // Preserved as distinct events
    },
  );

  test(
    'TEST 5: Delete mutation creates Tombstone DELETED_PENDING_SYNC metadata',
    () async {
      await SyncQueueService.instance.enqueueMutation(
        entityType: 'hoc_sinh',
        recordKey: '105',
        operation: SyncOperation.delete,
      );

      final queueRows = await db.query(
        'sync_queue',
        where: 'record_key = ?',
        whereArgs: ['105'],
      );
      expect(queueRows.length, equals(1));
      expect(queueRows.first['operation'], equals('DELETE'));

      final metaRows = await db.query(
        'sync_metadata',
        where: 'record_key = ?',
        whereArgs: ['105'],
      );
      expect(metaRows.length, equals(1));
      expect(metaRows.first['sync_status'], equals('DELETED_PENDING_SYNC'));
    },
  );
}
