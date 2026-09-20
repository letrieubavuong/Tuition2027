// File: lib/utils/test_database_seeder.dart

import 'dart:developer' as dev;
import 'package:sqflite/sqflite.dart';
import 'db.dart';

class TestDatabaseSeeder {
  static Future<void> seedTestData({bool clearExisting = false}) async {
    final db = await DBHelper.instance.database;

    if (clearExisting) {
      dev.log('Clearing existing test data...', name: 'TestDatabaseSeeder');
      await db.delete(DBHelper.tenBangDiemDanh);
      await db.delete(DBHelper.tenBangThanhToan);
      await db.delete(DBHelper.tenBangNhanXetThang);
      await db.delete(DBHelper.tenBangLopHS);
      await db.delete(DBHelper.tenBangLichHocChung);
      await db.delete(DBHelper.tenBangLop);
      await db.delete(DBHelper.tenBangHS);
    }

    // Check if data already exists
    final countLop =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM ${DBHelper.tenBangLop}'),
        ) ??
        0;

    if (countLop > 0 && !clearExisting) {
      dev.log(
        'Database already has $countLop classes. Skipping auto-seed.',
        name: 'TestDatabaseSeeder',
      );
      return;
    }

    dev.log(
      'Seeding rich test data into emulator database...',
      name: 'TestDatabaseSeeder',
    );

    // 1. Create Classes
    final lopToan10 = await db.insert(DBHelper.tenBangLop, {
      'ten': 'Toán 10A1',
      'khoi': 10,
    });
    final lopVan11 = await db.insert(DBHelper.tenBangLop, {
      'ten': 'Văn 11B2',
      'khoi': 11,
    });
    final lopLy12 = await db.insert(DBHelper.tenBangLop, {
      'ten': 'Lý 12A3',
      'khoi': 12,
    });
    final lopAnh9 = await db.insert(DBHelper.tenBangLop, {
      'ten': 'Anh 9C',
      'khoi': 9,
    });

    // 2. Create Students
    final students = [
      {
        'ten': 'Nguyễn Văn Anh',
        'sdt': '0901234567',
        'ten_phu_huynh': 'Nguyễn Văn Bình',
        'sdt_phu_huynh': '0912345678',
      },
      {
        'ten': 'Trần Thị Bảo',
        'sdt': '0902234567',
        'ten_phu_huynh': 'Trần Văn Châu',
        'sdt_phu_huynh': '0922345678',
      },
      {
        'ten': 'Lê Hoàng Cường',
        'sdt': '0903234567',
        'ten_phu_huynh': 'Lê Văn Dung',
        'sdt_phu_huynh': '0932345678',
      },
      {
        'ten': 'Phạm Minh Đức',
        'sdt': '0904234567',
        'ten_phu_huynh': 'Phạm Văn Em',
        'sdt_phu_huynh': '0942345678',
      },
      {
        'ten': 'Vũ Thu Hà',
        'sdt': '0905234567',
        'ten_phu_huynh': 'Vũ Văn Giang',
        'sdt_phu_huynh': '0952345678',
      },
      {
        'ten': 'Đỗ Quang Huy',
        'sdt': '0906234567',
        'ten_phu_huynh': 'Đỗ Văn Hùng',
        'sdt_phu_huynh': '0962345678',
      },
      {
        'ten': 'Hoàng Khánh Linh',
        'sdt': '0907234567',
        'ten_phu_huynh': 'Hoàng Văn Long',
        'sdt_phu_huynh': '0972345678',
      },
      {
        'ten': 'Ngô Xuân Nam',
        'sdt': '0908234567',
        'ten_phu_huynh': 'Ngô Văn Nghĩa',
        'sdt_phu_huynh': '0982345678',
      },
    ];

    final List<int> hsIds = [];
    for (var s in students) {
      final id = await db.insert(DBHelper.tenBangHS, {
        'ten': s['ten'],
        'sdt': s['sdt'],
        'sdt_hoc_sinh': s['sdt'],
        'ten_phu_huynh': s['ten_phu_huynh'],
        'sdt_phu_huynh': s['sdt_phu_huynh'],
        'ca_hoc_truong': 'Sáng',
        'mien_giam': 0,
        'so_buoi_du': 0,
        'zalo_link_status': 'LINKED',
      });
      hsIds.add(id);
    }

    // 3. Enroll Students in Classes
    // Class 10A1: Students 0, 1, 2
    for (int i = 0; i < 3; i++) {
      await db.insert(DBHelper.tenBangLopHS, {
        'id_lop': lopToan10,
        'id_hoc_sinh': hsIds[i],
        'ngay_tham_gia': '2026-08-01',
        'trang_thai': 'DANG_HOC',
      });
    }

    // Class 11B2: Students 3, 4, 5
    for (int i = 3; i < 6; i++) {
      await db.insert(DBHelper.tenBangLopHS, {
        'id_lop': lopVan11,
        'id_hoc_sinh': hsIds[i],
        'ngay_tham_gia': '2026-08-01',
        'trang_thai': 'DANG_HOC',
      });
    }

    // Class 12A3: Students 6, 7
    for (int i = 6; i < 8; i++) {
      await db.insert(DBHelper.tenBangLopHS, {
        'id_lop': lopLy12,
        'id_hoc_sinh': hsIds[i],
        'ngay_tham_gia': '2026-08-01',
        'trang_thai': 'DANG_HOC',
      });
    }

    // 4. Create Schedules
    await db.insert(DBHelper.tenBangLichHocChung, {
      'id_lop': lopToan10,
      'thu': 'Thứ 2',
      'gio_bat_dau': '18:00',
      'gio_ket_thuc': '19:30',
      'effective_from': '2026-08-01',
    });
    await db.insert(DBHelper.tenBangLichHocChung, {
      'id_lop': lopToan10,
      'thu': 'Thứ 4',
      'gio_bat_dau': '18:00',
      'gio_ket_thuc': '19:30',
      'effective_from': '2026-08-01',
    });

    // 5. Create Attendance Records for 2026-09
    final attendanceDates = [
      '2026-09-02 18:00:00',
      '2026-09-07 18:00:00',
      '2026-09-09 18:00:00',
      '2026-09-14 18:00:00',
    ];
    for (var dateStr in attendanceDates) {
      for (int i = 0; i < 3; i++) {
        final status = (i == 2 && dateStr.contains('09-07'))
            ? 'Nghỉ có phép'
            : 'Có mặt';
        await db.insert(DBHelper.tenBangDiemDanh, {
          'id_lop': lopToan10,
          'id_hoc_sinh': hsIds[i],
          'gio_diem_danh': dateStr,
          'trang_thai': status,
        });
      }
    }

    // 6. Create Tuition Records for 2026-09
    await db.insert(DBHelper.tenBangThanhToan, {
      'id_lop': lopToan10,
      'id_hoc_sinh': hsIds[0],
      'thang': '2026-09',
      'so_buoi_du': 4,
      'tong_so_buoi': 8,
      'don_gia': 50000,
      'tong_thanh_toan': 400000,
      'so_tien_da_dong': 400000,
      'so_tien_con_no': 0,
      'so_buoi_mien_giam_50': 0,
    });
    await db.insert(DBHelper.tenBangThanhToan, {
      'id_lop': lopToan10,
      'id_hoc_sinh': hsIds[1],
      'thang': '2026-09',
      'so_buoi_du': 4,
      'tong_so_buoi': 8,
      'don_gia': 50000,
      'tong_thanh_toan': 400000,
      'so_tien_da_dong': 200000,
      'so_tien_con_no': 200000,
      'so_buoi_mien_giam_50': 0,
    });
    await db.insert(DBHelper.tenBangThanhToan, {
      'id_lop': lopToan10,
      'id_hoc_sinh': hsIds[2],
      'thang': '2026-09',
      'so_buoi_du': 3,
      'tong_so_buoi': 8,
      'don_gia': 50000,
      'tong_thanh_toan': 400000,
      'so_tien_da_dong': 0,
      'so_tien_con_no': 400000,
      'so_buoi_mien_giam_50': 0,
    });

    // 7. Create Monthly Evaluation Comments
    for (int i = 0; i < 3; i++) {
      await db.insert(DBHelper.tenBangNhanXetThang, {
        'id_lop': lopToan10,
        'id_hoc_sinh': hsIds[i],
        'thang': '2026-09',
        'diem_chuyen_can': 9.5,
        'diem_thai_do': 9.0,
        'diem_bai_tap': 8.5,
        'diem_kiem_tra': 9.0,
        'diem_trung_binh': 9.0,
        'xep_hang': 'Xuất sắc',
        'nhan_xet_chung':
            'Học sinh đi học đầy đủ, hăng hái phát biểu xây dựng bài.',
      });
    }

    dev.log(
      '✅ Test database successfully seeded with 4 classes and 8 students!',
      name: 'TestDatabaseSeeder',
    );
  }
}
