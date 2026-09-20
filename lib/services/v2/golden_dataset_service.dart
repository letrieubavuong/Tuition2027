// File: lib/services/v2/golden_dataset_service.dart

import 'package:sqflite/sqflite.dart';
import '../../utils/db_v2.dart';

class GoldenDatasetService {
  final DBV2 _dbHelper = DBV2.instance;

  Future<void> loadGoldenData() async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      // Clear all
      await txn.delete('hoc_sinh');
      await txn.delete('lop');
      await txn.delete('tham_gia_lop');
      await txn.delete('lich_hoc');
      await txn.delete('phan_ca_hoc_sinh');
      await txn.delete('buoi_hoc');
      await txn.delete('diem_danh');
      await txn.delete('thanh_toan');

      final now = DateTime.now().toIso8601String();

      // 1. Students
      await txn.insert('hoc_sinh', {'id': 1, 'ho_ten': 'An', 'sdt_phu_huynh': '0905111111', 'created_at': now, 'updated_at': now});
      await txn.insert('hoc_sinh', {'id': 2, 'ho_ten': 'Bình', 'sdt_phu_huynh': '0905111111', 'created_at': now, 'updated_at': now}); // Sibling
      await txn.insert('hoc_sinh', {'id': 3, 'ho_ten': 'Cường', 'created_at': now, 'updated_at': now});
      
      // 2. Classes
      await txn.insert('lop', {'id': 1, 'ten_lop': 'Toán 10A', 'khoi': 10, 'hoc_phi_moi_buoi': 50000, 'so_buoi_chuan_thang': 12, 'created_at': now, 'updated_at': now});
      
      // 3. Membership
      await txn.insert('tham_gia_lop', {'id_hoc_sinh': 1, 'id_lop': 1, 'tu_ngay': '2026-09-01', 'created_at': now, 'updated_at': now});
      
      // 4. Schedule
      await txn.insert('lich_hoc', {'id': 1, 'id_lop': 1, 'thu_trong_tuan': 1, 'gio_bat_dau': '17:30', 'gio_ket_thuc': '19:00', 'hieu_luc_tu': '2026-09-01', 'created_at': now, 'updated_at': now});
    });
  }
}
