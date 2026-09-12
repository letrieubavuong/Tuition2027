// File: lib/utils/db.dart (Chi con khoi tao va tao bang)

import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:path/path.dart';

class DBHelper {
  static final DBHelper instance = DBHelper._init();
  static Database? _database;
  static Future<Database>? _initFuture;

  // current database version - tăng khi cần migration mới
  static const int _dbVersion = 27;

  // Hằng số cho tên Bảng
  static const String tenBangHS = 'hoc_sinh';
  static const String tenBangCaiDat = 'cai_dat';
  static const String tenBangTruong = 'truong';
  static const String tenBangLop = 'lop';
  static const String tenBangLopHS = 'lop_hoc_sinh';
  static const String tenBangLichHoc = 'lich_hoc';
  static const String tenBangDiemDanh = 'diem_danh';
  static const String tenBangThanhToan = 'thanh_toan';
  static const String tenBangLichHocChung = 'lich_hoc_chung';
  static const String tenBangLichHocCaNhan = 'lich_hoc_ca_nhan';
  static const String tenBangNhiemVuHocSinh = 'nhiem_vu_hoc_sinh'; // Bảng mới
  static const String tenBangNhiemVu = 'nhiem_vu'; // Bảng mới
  static const String tenBangNhanXetThang = 'nhan_xet_thang'; // Bảng mới
  static const String tenBangDanhGiaBuoiHoc = 'danh_gia_buoi_hoc'; // Bảng mới
  static const String tenBangQuyTacDiem = 'quy_tac_diem'; // Bảng mới
  static const String tenBangSuKienHocTap = 'su_kien_hoc_tap'; // Bảng mới
  static const String tenBangDonNghiHoc = 'don_nghi_hoc';
  static const String tenBangKhoanThu = 'khoan_thu';
  static const String tenBangKhoanThuHocSinh = 'khoan_thu_hoc_sinh';
  DBHelper._init();

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) return _database!;
    _initFuture ??= _khoiTaoDB('quan_ly_hs.db');
    _database = await _initFuture!;
    return _database!;
  }

  Future<Database> _khoiTaoDB(String filePath) async {
    if (kIsWeb) {
      try {
        databaseFactory = databaseFactoryFfiWeb;
        return await databaseFactory.openDatabase(
          'quan_ly_hs_web.db',
          options: OpenDatabaseOptions(
            version: _dbVersion,
            onCreate: _taoDB,
            onUpgrade: _onUpgrade,
          ),
        );
      } catch (e) {
        developer.log('Web IndexedDB open error: $e, fallback to in-memory DB', name: 'DBHelper');
        databaseFactory = databaseFactoryFfiWeb;
        return await databaseFactory.openDatabase(
          inMemoryDatabasePath,
          options: OpenDatabaseOptions(
            version: _dbVersion,
            onCreate: _taoDB,
          ),
        );
      }
    }
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: _dbVersion,
      onConfigure: _onConfigure,
      onCreate: _taoDB,
      onUpgrade: _onUpgrade,
    );
  }

  // Bật foreign key support để các FOREIGN KEY có hiệu lực
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  // onUpgrade sẽ gọi _migrate để áp dụng các bước nâng cấp theo phiên bản
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    developer.log('DB Upgrade: $oldVersion -> $newVersion', name: 'DBHelper');
    await _migrate(db, oldVersion, newVersion);
  }

  // Áp dụng các migration tuần tự từ (oldVersion+1) -> newVersion
  Future<void> _migrate(Database db, int from, int to) async {
    for (var v = from + 1; v <= to; v++) {
      try {
        switch (v) {
          case 2:
            // Ví dụ: thêm cột email cho bảng hoc_sinh (nullable)
            developer.log('Applying migration v2: add email to $tenBangHS');
            await db.execute('ALTER TABLE $tenBangHS ADD COLUMN email TEXT');
            break;
          case 3:
            // Ví dụ: thêm cột created_at cho lich_hoc_chung (nullable)
            developer.log(
              'Applying migration v3: add created_at to $tenBangLichHocChung',
            );
            await db.execute(
              'ALTER TABLE $tenBangLichHocChung ADD COLUMN created_at TEXT',
            );
            break;
          case 4:
            developer.log(
              'Applying migration v4: Fix thanh_toan UNIQUE constraint and add assigned_count to lich_hoc',
            );
            // Thêm cột mới vào lich_hoc
            await db.execute(
              'ALTER TABLE $tenBangLichHoc ADD COLUMN assigned_count INTEGER',
            );
            // Tạo lại bảng thanh_toan với UNIQUE constraint đúng
            await db.execute('DROP TABLE IF EXISTS $tenBangThanhToan');
            await _createThanhToanTable(db);
            break;
          case 5:
            developer.log('Applying migration v5: add $tenBangNhiemVu table');
            await _createNhiemVuTable(db);
            break;
          case 6:
            developer.log(
              'Applying migration v6: add trang_thai to $tenBangNhiemVu table',
            );
            await db.execute(
              "ALTER TABLE $tenBangNhiemVu ADD COLUMN trang_thai TEXT NOT NULL DEFAULT 'Chưa hoàn thành'",
            );
            break;
          case 7:
            developer.log('Applying migration v7: Refactor nhiem_vu table');
            await _createNhiemVuHocSinhTable(db);
            await db.execute(
              'ALTER TABLE $tenBangNhiemVu DROP COLUMN trang_thai',
            );
            break;
          case 8:
            developer.log(
              'Applying migration v8: Add ON DELETE CASCADE to tables',
            );
            // Tạo lại các bảng với ON DELETE CASCADE
            await db.execute('DROP TABLE IF EXISTS $tenBangLopHS');
            await _createLopHocSinhTable(db);
            await db.execute('DROP TABLE IF EXISTS $tenBangThanhToan');
            await _createThanhToanTable(db);
            await db.execute('DROP TABLE IF EXISTS $tenBangLichHocCaNhan');
            await _createLichHocCaNhanTable(db);
            break;
          case 9:
            developer.log(
              'Applying migration v9: add $tenBangNhanXetThang table',
            );
            await _createNhanXetThangTable(db);
            break;
          case 10:
            developer.log(
              'Applying migration v10: add $tenBangDanhGiaBuoiHoc table',
            );
            await _createDanhGiaBuoiHocTable(db);
            break;
          case 11:
            developer.log(
              'Applying migration v11: add $tenBangSuKienHocTap table',
            );
            await _createSuKienHocTapTable(db);
            break;
          case 12:
            developer.log(
              'Applying migration v12: add mien_giam and so_buoi_du to $tenBangHS',
            );
            try {
              await db.execute(
                'ALTER TABLE $tenBangHS ADD COLUMN mien_giam INTEGER NOT NULL DEFAULT 0',
              );
            } catch (e) {
              developer.log(
                'Warning: Column mien_giam might already exist: $e',
              );
            }
            try {
              await db.execute(
                'ALTER TABLE $tenBangHS ADD COLUMN so_buoi_du INTEGER NOT NULL DEFAULT 0',
              );
            } catch (e) {
              developer.log(
                'Warning: Column so_buoi_du might already exist: $e',
              );
            }
            break;
          case 13:
            developer.log(
              'Applying migration v13: add so_buoi_duoc_bu_tru and so_buoi_du_con_lai to $tenBangThanhToan',
            );
            try {
              await db.execute(
                'ALTER TABLE $tenBangThanhToan ADD COLUMN so_buoi_duoc_bu_tru INTEGER NOT NULL DEFAULT 0',
              );
            } catch (e) {
              developer.log(
                'Warning: Column so_buoi_duoc_bu_tru might already exist: $e',
              );
            }
            try {
              await db.execute(
                'ALTER TABLE $tenBangThanhToan ADD COLUMN so_buoi_du_con_lai INTEGER NOT NULL DEFAULT 0',
              );
            } catch (e) {
              developer.log(
                'Warning: Column so_buoi_du_con_lai might already exist: $e',
              );
            }
            break;
          case 14:
            developer.log(
              'Applying migration v14: create $tenBangQuyTacDiem table',
            );
            await _createQuyTacDiemTable(db);
            break;
          case 15:
            developer.log(
              'Applying migration v15: add hang_muc to $tenBangQuyTacDiem',
            );
            try {
              await db.execute(
                'ALTER TABLE $tenBangQuyTacDiem ADD COLUMN hang_muc TEXT NOT NULL DEFAULT \'THAI_DO\'',
              );
            } catch (e) {
              developer.log('Warning: Column hang_muc might already exist: $e');
            }
            break;
          case 16:
            developer.log('Applying migration v16: init bank info in cai_dat');
            await db.insert(tenBangCaiDat, {
              'khoa': 'bank_id',
              'gia_tri': 'sacombank',
            }, conflictAlgorithm: ConflictAlgorithm.ignore);
            await db.insert(tenBangCaiDat, {
              'khoa': 'account_no',
              'gia_tri': '0905073175',
            }, conflictAlgorithm: ConflictAlgorithm.ignore);
            await db.insert(tenBangCaiDat, {
              'khoa': 'account_name',
              'gia_tri': 'LE TRIEU BA VUONG',
            }, conflictAlgorithm: ConflictAlgorithm.ignore);
            break;
          case 17:
            developer.log(
              'Applying migration v17: create payment_transactions table',
            );
            await _createPaymentTransactionsTable(db);
            break;
          case 18:
            developer.log('Applying migration v18: Add database indexes');
            // Index cho bảng diem_danh
            await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_diem_danh_hs_lop ON $tenBangDiemDanh (id_hoc_sinh, id_lop)',
            );
            await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_diem_danh_gio ON $tenBangDiemDanh (gio_diem_danh)',
            );

            // Index cho bảng thanh_toan
            await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_thanh_toan_hs_lop ON $tenBangThanhToan (id_hoc_sinh, id_lop)',
            );
            await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_thanh_toan_thang ON $tenBangThanhToan (thang)',
            );

            // Index cho bảng lop_hoc_sinh
            await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_lhs_hs ON $tenBangLopHS (id_hoc_sinh)',
            );
            await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_lhs_lop ON $tenBangLopHS (id_lop)',
            );

            // Index cho bảng danh_gia_buoi_hoc
            await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_dgbh_diemdanh ON $tenBangDanhGiaBuoiHoc (id_diem_danh)',
            );
            break;
          case 19:
            developer.log(
              'Applying migration v19: update google_sheets_web_app_url',
            );
            await db.update(tenBangCaiDat, {
              'gia_tri':
                  'https://script.google.com/macros/s/AKfycbweybBmk23NHVogV007Fbu20LNqVUKQ01qSfUUnjXjMABfyAiuY8P-Pj5-HGBY_iJEn/exec',
            }, where: "khoa = 'google_sheets_web_app_url'");
            break;
          case 20:
            developer.log(
              'Applying migration v20: insert new suggested scoring rules',
            );
            await db.insert(tenBangQuyTacDiem, {
              'loai_quy_tac': 'CONG_DIEM',
              'hang_muc': 'THAI_DO',
              'mo_ta': 'Đi học đúng giờ',
              'diem_thay_doi': 0.3,
              'thu_tu_hien_thi': 4,
            }, conflictAlgorithm: ConflictAlgorithm.ignore);
            await db.insert(tenBangQuyTacDiem, {
              'loai_quy_tac': 'CONG_DIEM',
              'hang_muc': 'THAI_DO',
              'mo_ta': 'Hỗ trợ bạn bè',
              'diem_thay_doi': 0.5,
              'thu_tu_hien_thi': 5,
            }, conflictAlgorithm: ConflictAlgorithm.ignore);
            await db.insert(tenBangQuyTacDiem, {
              'loai_quy_tac': 'CONG_DIEM',
              'hang_muc': 'THAI_DO',
              'mo_ta': 'Tiến bộ vượt bậc',
              'diem_thay_doi': 1.0,
              'thu_tu_hien_thi': 6,
            }, conflictAlgorithm: ConflictAlgorithm.ignore);
            await db.insert(tenBangQuyTacDiem, {
              'loai_quy_tac': 'CONG_DIEM',
              'hang_muc': 'HIEU_BAI',
              'mo_ta': 'Giải bài sáng tạo',
              'diem_thay_doi': 1.0,
              'thu_tu_hien_thi': 7,
            }, conflictAlgorithm: ConflictAlgorithm.ignore);
            await db.insert(tenBangQuyTacDiem, {
              'loai_quy_tac': 'CONG_DIEM',
              'hang_muc': 'HIEU_BAI',
              'mo_ta': 'Đạt điểm 9-10 kiểm tra',
              'diem_thay_doi': 1.0,
              'thu_tu_hien_thi': 8,
            }, conflictAlgorithm: ConflictAlgorithm.ignore);
            await db.insert(tenBangQuyTacDiem, {
              'loai_quy_tac': 'CONG_DIEM',
              'hang_muc': 'BAI_TAP',
              'mo_ta': 'Làm thêm bài tập nâng cao',
              'diem_thay_doi': 0.5,
              'thu_tu_hien_thi': 9,
            }, conflictAlgorithm: ConflictAlgorithm.ignore);
            await db.insert(tenBangQuyTacDiem, {
              'loai_quy_tac': 'CONG_DIEM',
              'hang_muc': 'BAI_TAP',
              'mo_ta': 'Bài tập sạch đẹp',
              'diem_thay_doi': 0.5,
              'thu_tu_hien_thi': 10,
            }, conflictAlgorithm: ConflictAlgorithm.ignore);

            await db.insert(tenBangQuyTacDiem, {
              'loai_quy_tac': 'TRU_DIEM',
              'hang_muc': 'THAI_DO',
              'mo_ta': 'Sử dụng điện thoại/việc riêng',
              'diem_thay_doi': -1.0,
              'thu_tu_hien_thi': 5,
            }, conflictAlgorithm: ConflictAlgorithm.ignore);
            await db.insert(tenBangQuyTacDiem, {
              'loai_quy_tac': 'TRU_DIEM',
              'hang_muc': 'THAI_DO',
              'mo_ta': 'Thiếu đồ dùng học tập',
              'diem_thay_doi': -0.3,
              'thu_tu_hien_thi': 6,
            }, conflictAlgorithm: ConflictAlgorithm.ignore);
            await db.insert(tenBangQuyTacDiem, {
              'loai_quy_tac': 'TRU_DIEM',
              'hang_muc': 'THAI_DO',
              'mo_ta': 'Nói leo/thái độ sai lệch',
              'diem_thay_doi': -1.0,
              'thu_tu_hien_thi': 7,
            }, conflictAlgorithm: ConflictAlgorithm.ignore);
            await db.insert(tenBangQuyTacDiem, {
              'loai_quy_tac': 'TRU_DIEM',
              'hang_muc': 'HIEU_BAI',
              'mo_ta': 'Không ghi chép bài',
              'diem_thay_doi': -0.5,
              'thu_tu_hien_thi': 8,
            }, conflictAlgorithm: ConflictAlgorithm.ignore);
            await db.insert(tenBangQuyTacDiem, {
              'loai_quy_tac': 'TRU_DIEM',
              'hang_muc': 'HIEU_BAI',
              'mo_ta': 'Điểm kiểm tra kém',
              'diem_thay_doi': -0.5,
              'thu_tu_hien_thi': 9,
            }, conflictAlgorithm: ConflictAlgorithm.ignore);
            await db.insert(tenBangQuyTacDiem, {
              'loai_quy_tac': 'TRU_DIEM',
              'hang_muc': 'BAI_TAP',
              'mo_ta': 'Làm bài đối phó',
              'diem_thay_doi': -1.0,
              'thu_tu_hien_thi': 10,
            }, conflictAlgorithm: ConflictAlgorithm.ignore);
            await db.insert(tenBangQuyTacDiem, {
              'loai_quy_tac': 'TRU_DIEM',
              'hang_muc': 'BAI_TAP',
              'mo_ta': 'Nộp bài tập muộn',
              'diem_thay_doi': -0.5,
              'thu_tu_hien_thi': 11,
            }, conflictAlgorithm: ConflictAlgorithm.ignore);
            break;
          case 21:
            developer.log(
              'Applying migration v21: prevent duplicate bank transactions',
            );
            await _createPaymentTransactionsTable(db);
            await db.execute(
              'CREATE UNIQUE INDEX IF NOT EXISTS '
              'idx_payment_transactions_transaction_id '
              'ON payment_transactions (transaction_id) '
              'WHERE transaction_id IS NOT NULL',
            );
            break;
          case 22:
            developer.log('Applying migration v22: student leave management');
            await _addColumnIfMissing(db, tenBangLopHS, 'ngay_tam_ngung', 'TEXT');
            await _addColumnIfMissing(db, tenBangLopHS, 'ngay_du_kien_hoc_lai', 'TEXT');
            await _addColumnIfMissing(db, tenBangLopHS, 'ngay_hoc_lai_thuc_te', 'TEXT');
            await _addColumnIfMissing(db, tenBangLopHS, 'ly_do_tam_ngung', 'TEXT');
            await db.update(
              tenBangLopHS,
              {'trang_thai': 'DANG_HOC'},
              where: "trang_thai = 'Dang hoc' OR trang_thai IS NULL OR trang_thai = ''",
            );
            await _createDonNghiHocTable(db);
            break;
          case 23:
            developer.log('Applying migration v23: student class end date');
            await _addColumnIfMissing(
              db,
              tenBangLopHS,
              'ngay_nghi_hoc',
              'TEXT',
            );
            await _addColumnIfMissing(
              db,
              tenBangLopHS,
              'ly_do_nghi_hoc',
              'TEXT',
            );
            break;
          case 24:
            developer.log('Applying migration v24: student return date');
            await _addColumnIfMissing(
              db,
              tenBangLopHS,
              'ngay_hoc_lai_sau_nghi',
              'TEXT',
            );
            break;
          case 25:
            developer.log('Applying migration v25: additional charges');
            await _createKhoanThuTables(db);
            break;
          case 26:
            developer.log('Applying migration v26: add school session & subject conflicts to $tenBangHS');
            await _addColumnIfMissing(db, tenBangHS, 'ca_hoc_truong', "TEXT NOT NULL DEFAULT 'Sáng'");
            await _addColumnIfMissing(db, tenBangHS, 'lich_can_mon_khac', 'TEXT');
            break;
          case 27:
            developer.log('Applying migration v27: Ensure payment_transactions table & schema safety integrity');
            await _createPaymentTransactionsTable(db);
            await _addColumnIfMissing(db, tenBangHS, 'ca_hoc_truong', "TEXT NOT NULL DEFAULT 'Sáng'");
            await _addColumnIfMissing(db, tenBangHS, 'lich_can_mon_khac', 'TEXT');
            await _addColumnIfMissing(db, tenBangHS, 'mien_giam', 'INTEGER NOT NULL DEFAULT 0');
            await _addColumnIfMissing(db, tenBangHS, 'so_buoi_du', 'INTEGER NOT NULL DEFAULT 0');
            await _addColumnIfMissing(db, tenBangLopHS, 'ngay_tam_ngung', 'TEXT');
            await _addColumnIfMissing(db, tenBangLopHS, 'ngay_du_kien_hoc_lai', 'TEXT');
            await _addColumnIfMissing(db, tenBangLopHS, 'ngay_hoc_lai_thuc_te', 'TEXT');
            await _addColumnIfMissing(db, tenBangLopHS, 'ly_do_tam_ngung', 'TEXT');
            await _addColumnIfMissing(db, tenBangLopHS, 'ngay_nghi_hoc', 'TEXT');
            await _addColumnIfMissing(db, tenBangLopHS, 'ly_do_nghi_hoc', 'TEXT');
            await _addColumnIfMissing(db, tenBangLopHS, 'ngay_hoc_lai_sau_nghi', 'TEXT');
            await _createDonNghiHocTable(db);
            await _createKhoanThuTables(db);
            break;
          // Thêm case tiếp theo cho các version sau
          default:
            developer.log('No migration defined for version $v');
        }
      } catch (e) {
        // Không được đánh dấu nâng cấp thành công khi cấu trúc dữ liệu chưa đầy đủ.
        developer.log('Migration v$v failed: $e', name: 'DBHelper', error: e);
        rethrow;
      }
    }
  }

  // Đóng database khi không dùng nữa
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  Future _taoDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const intType = 'INTEGER NOT NULL';
    const nullableText = 'TEXT';
    // 1. Tao Bang Truong
    await db.execute('''
        CREATE TABLE $tenBangTruong ( id $idType, ten $textType UNIQUE )
    ''');

    // 2. Tao Bang Cai Dat
    await db.execute('''
        CREATE TABLE $tenBangCaiDat ( khoa TEXT PRIMARY KEY, gia_tri TEXT NOT NULL )
    ''');

    // 3. Tao Bang Lop
    await db.execute('''
        CREATE TABLE $tenBangLop ( id $idType, ten $textType UNIQUE, khoi $intType )
    ''');

    // 4. Tao Bang Hoc Sinh (HS)
    await db.execute('''
      CREATE TABLE $tenBangHS ( 
        id $idType, ten $textType, sdt $nullableText,              
        truong_dang_hoc $nullableText, dia_chi $nullableText, 
        ghi_chu $nullableText,
        email $nullableText,
        mien_giam INTEGER NOT NULL DEFAULT 0,
        so_buoi_du INTEGER NOT NULL DEFAULT 0,
        ca_hoc_truong TEXT NOT NULL DEFAULT 'Sáng',
        lich_can_mon_khac TEXT
      )
    ''');

    // 5. Tao Bang Lop Hoc Sinh
    await _createLopHocSinhTable(db);

    // 6. Tao Bang Lich Hoc
    await db.execute('''
      CREATE TABLE $tenBangLichHoc (
        id $idType,
        id_lop INTEGER,
        thuTrongTuan INTEGER NOT NULL,
        gioBatDau TEXT NOT NULL,
        gioKetThuc TEXT NOT NULL,
        assigned_count INTEGER,
        FOREIGN KEY(id_lop) REFERENCES $tenBangLop(id) ON DELETE CASCADE
      )
    ''');

    // 7. Tao Bang Diem Danh
    await db.execute('''
        CREATE TABLE $tenBangDiemDanh ( 
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            id_hoc_sinh INTEGER NOT NULL,
            id_lop INTEGER NOT NULL,
            gio_diem_danh TEXT NOT NULL, 
            trang_thai TEXT NOT NULL, 
            ghi_chu TEXT,
            FOREIGN KEY(id_hoc_sinh) REFERENCES $tenBangHS(id) ON DELETE CASCADE,
            FOREIGN KEY(id_lop) REFERENCES $tenBangLop(id) ON DELETE CASCADE,
            UNIQUE(id_hoc_sinh, gio_diem_danh)
        )
    ''');

    // 8. Tao Bang Thanh Toan
    await _createThanhToanTable(db);
    await db.execute('''
      CREATE TABLE $tenBangLichHocChung (
          id $idType,
          id_lop $intType NOT NULL,
          ngay_trong_tuan $textType NOT NULL, -- Ví dụ: 'Thứ Hai'
          gio_bat_dau $textType NOT NULL,      -- Ví dụ: '18:00'
          gio_ket_thuc $textType NOT NULL,     -- Ví dụ: '20:00',
          created_at $nullableText,
          FOREIGN KEY(id_lop) REFERENCES $tenBangLop(id)
      )
  ''');

    await _createLichHocCaNhanTable(db);
    // Khởi tạo Dữ liệu Mặc định (giữ nguyên)
    await db.insert(tenBangCaiDat, {
      'khoa': 'hoc_phi_buoi',
      'gia_tri': '50000',
    });
    await db.insert(tenBangCaiDat, {
      'khoa': 'nguoi_quan_ly',
      'gia_tri': 'LÊ TRIỆU BÁ VƯƠNG',
    });
    await db.insert(tenBangCaiDat, {
      'khoa': 'email',
      'gia_tri': 'bavuong@moet.edu.vn',
    });
    await db.insert(tenBangCaiDat, {
      'khoa': 'avatar_path',
      'gia_tri': '', // Giá trị ban đầu là chuỗi rỗng
    });
    await db.insert(tenBangCaiDat, {
      'khoa': 'hoc_phi_thang',
      'gia_tri': '600000',
    });
    await db.insert(tenBangTruong, {'ten': 'THPT Ngô Quyền'});

    // TẠO BẢNG NHIỆM VỤ
    await _createNhiemVuTable(db);
    // TẠO BẢNG TRẠNG THÁI NHIỆM VỤ CỦA HỌC SINH
    await _createNhiemVuHocSinhTable(db);
    // TẠO BẢNG NHẬN XÉT THÁNG
    await _createNhanXetThangTable(db);
    // TẠO BẢNG ĐÁNH GIÁ BUỔI HỌC
    await _createDanhGiaBuoiHocTable(db);
    // TẠO BẢNG SỰ KIỆN HỌC TẬP
    await _createSuKienHocTapTable(db);
    // TẠO BẢNG QUY TẮC ĐIỂM
    await _createQuyTacDiemTable(db);
    await _createDonNghiHocTable(db);
    await _createKhoanThuTables(db);
    await _createPaymentTransactionsTable(db);
    await db.insert(tenBangCaiDat, {'khoa': 'bank_id', 'gia_tri': 'sacombank'});
    await db.insert(tenBangCaiDat, {
      'khoa': 'account_no',
      'gia_tri': '0905073175',
    });
    await db.insert(tenBangCaiDat, {
      'khoa': 'account_name',
      'gia_tri': 'LE TRIEU BA VUONG',
    });
    await db.insert(tenBangCaiDat, {
      'khoa': 'google_sheets_web_app_url',
      'gia_tri':
          'https://script.google.com/macros/s/AKfycbweybBmk23NHVogV007Fbu20LNqVUKQ01qSfUUnjXjMABfyAiuY8P-Pj5-HGBY_iJEn/exec',
    });
    await db.insert(tenBangTruong, {'ten': 'THPT Hoàng Hoa Thám'});

    // Thêm Index để tối ưu hóa hiệu năng truy vấn cho các cài đặt mới
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_diem_danh_hs_lop ON $tenBangDiemDanh (id_hoc_sinh, id_lop)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_diem_danh_gio ON $tenBangDiemDanh (gio_diem_danh)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_thanh_toan_hs_lop ON $tenBangThanhToan (id_hoc_sinh, id_lop)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_thanh_toan_thang ON $tenBangThanhToan (thang)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_lhs_hs ON $tenBangLopHS (id_hoc_sinh)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_lhs_lop ON $tenBangLopHS (id_lop)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_dgbh_diemdanh ON $tenBangDanhGiaBuoiHoc (id_diem_danh)',
    );
  }

  // New method to create payment_transactions table
  Future<void> _createPaymentTransactionsTable(Database db) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const nullableText = 'TEXT';
    const intType = 'INTEGER NOT NULL';
    await db.execute('''
      CREATE TABLE IF NOT EXISTS payment_transactions (
        id $idType,
        hoc_sinh_id $intType,
        lop_id $intType,
        month $textType,
        amount $intType,
        status $textType,
        transaction_id $nullableText,
        created_at $textType,
        updated_at $nullableText
      )
    ''');
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS '
      'idx_payment_transactions_transaction_id '
      'ON payment_transactions (transaction_id) '
      'WHERE transaction_id IS NOT NULL',
    );
  }

  // Tách hàm tạo bảng thanh_toan để tái sử dụng trong migration
  Future<void> _createThanhToanTable(Database db) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const intType = 'INTEGER NOT NULL';
    const nullableText = 'TEXT';
    await db.execute('''
      CREATE TABLE $tenBangThanhToan ( 
          id $idType, 
          id_hoc_sinh $intType, 
          id_lop $intType, 
          thang $textType, 
          tong_so_buoi $intType,
          so_buoi_mien_giam_50 $intType DEFAULT 0, 
          so_buoi_mien_giam_100 $intType DEFAULT 0,
          tong_thanh_toan $intType, 
          so_tien_da_dong $intType DEFAULT 0,
          ngay_thanh_toan $nullableText, 
          ghi_chu_thanh_toan $nullableText, 
            so_buoi_duoc_bu_tru $intType DEFAULT 0,
            so_buoi_du_con_lai $intType DEFAULT 0,
          UNIQUE(id_hoc_sinh, id_lop, thang),
          FOREIGN KEY(id_hoc_sinh) REFERENCES $tenBangHS(id) ON DELETE CASCADE
      )
    ''');
  }

  // Hàm tạo bảng nhiệm vụ
  Future<void> _createNhiemVuTable(Database db) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const intType = 'INTEGER NOT NULL';

    await db.execute('''
      CREATE TABLE $tenBangNhiemVu (
        id $idType,
        id_lop $intType,
        ten_nhiem_vu $textType,
        ngay_giao $textType,
        ngay_nop $textType,
        FOREIGN KEY(id_lop) REFERENCES $tenBangLop(id) ON DELETE CASCADE
      )
    ''');
  }

  // Hàm tạo bảng trạng thái nhiệm vụ của học sinh
  Future<void> _createNhiemVuHocSinhTable(Database db) async {
    const intType = 'INTEGER NOT NULL';
    const textType = 'TEXT NOT NULL';

    await db.execute('''
      CREATE TABLE $tenBangNhiemVuHocSinh (
        id_nhiem_vu $intType,
        id_hoc_sinh $intType,
        trang_thai $textType,
        PRIMARY KEY(id_nhiem_vu, id_hoc_sinh),
        FOREIGN KEY(id_nhiem_vu) REFERENCES $tenBangNhiemVu(id) ON DELETE CASCADE,
        FOREIGN KEY(id_hoc_sinh) REFERENCES $tenBangHS(id) ON DELETE CASCADE
      )
    ''');
  }

  // Hàm tạo bảng lop_hoc_sinh
  Future<void> _createLopHocSinhTable(Database db) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const intType = 'INTEGER NOT NULL';
    await db.execute('''
        CREATE TABLE $tenBangLopHS ( 
            id $idType, id_hoc_sinh $intType, id_lop $intType, ngay_tham_gia $textType,
            trang_thai $textType DEFAULT 'DANG_HOC',
            ngay_tam_ngung TEXT,
            ngay_du_kien_hoc_lai TEXT,
            ngay_hoc_lai_thuc_te TEXT,
            ly_do_tam_ngung TEXT,
            ngay_nghi_hoc TEXT,
            ly_do_nghi_hoc TEXT,
            ngay_hoc_lai_sau_nghi TEXT,
            UNIQUE(id_hoc_sinh, id_lop),
            FOREIGN KEY(id_hoc_sinh) REFERENCES $tenBangHS(id) ON DELETE CASCADE
        )
    ''');
  }

  Future<void> _createDonNghiHocTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tenBangDonNghiHoc (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        id_hoc_sinh INTEGER NOT NULL,
        id_lop INTEGER NOT NULL,
        tu_ngay TEXT NOT NULL,
        den_ngay TEXT NOT NULL,
        ly_do TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY(id_hoc_sinh) REFERENCES $tenBangHS(id) ON DELETE CASCADE,
        FOREIGN KEY(id_lop) REFERENCES $tenBangLop(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_don_nghi_hoc_hs_lop_ngay '
      'ON $tenBangDonNghiHoc (id_hoc_sinh, id_lop, tu_ngay, den_ngay)',
    );
  }

  Future<void> _addColumnIfMissing(
    Database db,
    String table,
    String column,
    String definition,
  ) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    if (columns.any((row) => row['name'] == column)) return;
    await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
  }

  Future<void> _createKhoanThuTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tenBangKhoanThu (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        id_lop INTEGER NOT NULL,
        thang TEXT NOT NULL,
        ten_khoan_thu TEXT NOT NULL,
        so_tien INTEGER NOT NULL,
        han_thu TEXT,
        ghi_chu TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY(id_lop) REFERENCES $tenBangLop(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tenBangKhoanThuHocSinh (
        id_khoan_thu INTEGER NOT NULL,
        id_hoc_sinh INTEGER NOT NULL,
        so_tien_da_dong INTEGER NOT NULL DEFAULT 0,
        ngay_thanh_toan TEXT,
        ghi_chu TEXT,
        PRIMARY KEY(id_khoan_thu, id_hoc_sinh),
        FOREIGN KEY(id_khoan_thu) REFERENCES $tenBangKhoanThu(id) ON DELETE CASCADE,
        FOREIGN KEY(id_hoc_sinh) REFERENCES $tenBangHS(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_khoan_thu_lop_thang '
      'ON $tenBangKhoanThu (id_lop, thang)',
    );
  }

  // Hàm tạo bảng lich_hoc_ca_nhan
  Future<void> _createLichHocCaNhanTable(Database db) async {
    const intType = 'INTEGER NOT NULL';
    await db.execute('''
      CREATE TABLE $tenBangLichHocCaNhan (
          id_hoc_sinh $intType,
          id_lich_hoc_chung $intType,
          PRIMARY KEY(id_hoc_sinh, id_lich_hoc_chung),
          FOREIGN KEY(id_hoc_sinh) REFERENCES $tenBangHS(id) ON DELETE CASCADE
      )
  ''');
  }

  // Hàm tạo bảng nhận xét tháng
  Future<void> _createNhanXetThangTable(Database db) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const intType = 'INTEGER NOT NULL';
    const realType = 'REAL NOT NULL';
    const textType = 'TEXT NOT NULL';
    const nullableText = 'TEXT';
    await db.execute('''
      CREATE TABLE $tenBangNhanXetThang (
        id $idType,
        id_hoc_sinh $intType,
        id_lop $intType,
        thang $textType,
        diem_chuyen_can $realType DEFAULT 10.0,
        diem_thai_do $realType DEFAULT 10.0,
        diem_bai_tap $realType DEFAULT 10.0,
        diem_kiem_tra $realType DEFAULT 10.0,
        nhan_xet_chung $nullableText,
        xep_hang $nullableText,
        UNIQUE(id_hoc_sinh, id_lop, thang)
      )
    ''');
  }

  // Hàm tạo bảng đánh giá buổi học
  Future<void> _createDanhGiaBuoiHocTable(Database db) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const intType = 'INTEGER NOT NULL';
    const realType = 'REAL'; // Có thể null
    const nullableText = 'TEXT';

    await db.execute('''
      CREATE TABLE $tenBangDanhGiaBuoiHoc (
        id $idType,
        id_diem_danh $intType UNIQUE,
        diem_thai_do $realType,
        diem_hieu_bai $realType,
        diem_bai_tap $realType,
        nhan_xet $nullableText,
        FOREIGN KEY(id_diem_danh) REFERENCES $tenBangDiemDanh(id) ON DELETE CASCADE
      )
    ''');
  }

  // Hàm tạo bảng sự kiện học tập
  Future<void> _createSuKienHocTapTable(Database db) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const intType = 'INTEGER NOT NULL';
    const realType = 'REAL NOT NULL';
    const textType = 'TEXT NOT NULL';

    await db.execute('''
      CREATE TABLE $tenBangSuKienHocTap (
        id $idType,
        id_diem_danh $intType,
        loai_su_kien $textType, -- 'TICH_CUC', 'TIEU_CUC', 'KHAC'
        mo_ta $textType, -- 'Lên bảng', 'Nói chuyện riêng'
        diem_thay_doi $realType, -- +0.5, -0.2
        FOREIGN KEY(id_diem_danh) REFERENCES $tenBangDiemDanh(id) ON DELETE CASCADE
      )
    ''');
  }

  // Hàm tạo bảng quy_tac_diem
  Future<void> _createQuyTacDiemTable(Database db) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const realType = 'REAL NOT NULL';
    const intType = 'INTEGER';

    await db.execute('''
      CREATE TABLE $tenBangQuyTacDiem (
        id $idType,
        loai_quy_tac $textType, -- 'CONG_DIEM', 'TRU_DIEM'
        hang_muc $textType DEFAULT 'THAI_DO', -- 'THAI_DO', 'HIEU_BAI', 'BAI_TAP'
        mo_ta $textType UNIQUE,
        diem_thay_doi $realType,
        thu_tu_hien_thi $intType DEFAULT 0
      )
    ''');

    // Thêm các quy tắc mặc định (nếu chưa có)
    await db.insert(tenBangQuyTacDiem, {
      'loai_quy_tac': 'CONG_DIEM',
      'hang_muc': 'HIEU_BAI',
      'mo_ta': 'Lên bảng',
      'diem_thay_doi': 0.5,
      'thu_tu_hien_thi': 1,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert(tenBangQuyTacDiem, {
      'loai_quy_tac': 'CONG_DIEM',
      'hang_muc': 'HIEU_BAI',
      'mo_ta': 'Phát biểu',
      'diem_thay_doi': 0.2,
      'thu_tu_hien_thi': 2,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert(tenBangQuyTacDiem, {
      'loai_quy_tac': 'CONG_DIEM',
      'hang_muc': 'BAI_TAP',
      'mo_ta': 'Bài tập tốt',
      'diem_thay_doi': 0.5,
      'thu_tu_hien_thi': 3,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert(tenBangQuyTacDiem, {
      'loai_quy_tac': 'CONG_DIEM',
      'hang_muc': 'THAI_DO',
      'mo_ta': 'Đi học đúng giờ',
      'diem_thay_doi': 0.3,
      'thu_tu_hien_thi': 4,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert(tenBangQuyTacDiem, {
      'loai_quy_tac': 'CONG_DIEM',
      'hang_muc': 'THAI_DO',
      'mo_ta': 'Hỗ trợ bạn bè',
      'diem_thay_doi': 0.5,
      'thu_tu_hien_thi': 5,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert(tenBangQuyTacDiem, {
      'loai_quy_tac': 'CONG_DIEM',
      'hang_muc': 'THAI_DO',
      'mo_ta': 'Tiến bộ vượt bậc',
      'diem_thay_doi': 1.0,
      'thu_tu_hien_thi': 6,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert(tenBangQuyTacDiem, {
      'loai_quy_tac': 'CONG_DIEM',
      'hang_muc': 'HIEU_BAI',
      'mo_ta': 'Giải bài sáng tạo',
      'diem_thay_doi': 1.0,
      'thu_tu_hien_thi': 7,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert(tenBangQuyTacDiem, {
      'loai_quy_tac': 'CONG_DIEM',
      'hang_muc': 'HIEU_BAI',
      'mo_ta': 'Đạt điểm 9-10 kiểm tra',
      'diem_thay_doi': 1.0,
      'thu_tu_hien_thi': 8,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert(tenBangQuyTacDiem, {
      'loai_quy_tac': 'CONG_DIEM',
      'hang_muc': 'BAI_TAP',
      'mo_ta': 'Làm thêm bài tập nâng cao',
      'diem_thay_doi': 0.5,
      'thu_tu_hien_thi': 9,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert(tenBangQuyTacDiem, {
      'loai_quy_tac': 'CONG_DIEM',
      'hang_muc': 'BAI_TAP',
      'mo_ta': 'Bài tập sạch đẹp',
      'diem_thay_doi': 0.5,
      'thu_tu_hien_thi': 10,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    await db.insert(tenBangQuyTacDiem, {
      'loai_quy_tac': 'TRU_DIEM',
      'hang_muc': 'THAI_DO',
      'mo_ta': 'Nói chuyện',
      'diem_thay_doi': -0.5,
      'thu_tu_hien_thi': 1,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert(tenBangQuyTacDiem, {
      'loai_quy_tac': 'TRU_DIEM',
      'hang_muc': 'THAI_DO',
      'mo_ta': 'Mất trật tự',
      'diem_thay_doi': -1.0,
      'thu_tu_hien_thi': 2,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert(tenBangQuyTacDiem, {
      'loai_quy_tac': 'TRU_DIEM',
      'hang_muc': 'BAI_TAP',
      'mo_ta': 'Không làm bài',
      'diem_thay_doi': -1.0,
      'thu_tu_hien_thi': 3,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert(tenBangQuyTacDiem, {
      'loai_quy_tac': 'TRU_DIEM',
      'hang_muc': 'THAI_DO',
      'mo_ta': 'Đi muộn',
      'diem_thay_doi': -0.5,
      'thu_tu_hien_thi': 4,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert(tenBangQuyTacDiem, {
      'loai_quy_tac': 'TRU_DIEM',
      'hang_muc': 'THAI_DO',
      'mo_ta': 'Sử dụng điện thoại/việc riêng',
      'diem_thay_doi': -1.0,
      'thu_tu_hien_thi': 5,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert(tenBangQuyTacDiem, {
      'loai_quy_tac': 'TRU_DIEM',
      'hang_muc': 'THAI_DO',
      'mo_ta': 'Thiếu đồ dùng học tập',
      'diem_thay_doi': -0.3,
      'thu_tu_hien_thi': 6,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert(tenBangQuyTacDiem, {
      'loai_quy_tac': 'TRU_DIEM',
      'hang_muc': 'THAI_DO',
      'mo_ta': 'Nói leo/thái độ sai lệch',
      'diem_thay_doi': -1.0,
      'thu_tu_hien_thi': 7,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert(tenBangQuyTacDiem, {
      'loai_quy_tac': 'TRU_DIEM',
      'hang_muc': 'HIEU_BAI',
      'mo_ta': 'Không ghi chép bài',
      'diem_thay_doi': -0.5,
      'thu_tu_hien_thi': 8,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert(tenBangQuyTacDiem, {
      'loai_quy_tac': 'TRU_DIEM',
      'hang_muc': 'HIEU_BAI',
      'mo_ta': 'Điểm kiểm tra kém',
      'diem_thay_doi': -0.5,
      'thu_tu_hien_thi': 9,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert(tenBangQuyTacDiem, {
      'loai_quy_tac': 'TRU_DIEM',
      'hang_muc': 'BAI_TAP',
      'mo_ta': 'Làm bài đối phó',
      'diem_thay_doi': -1.0,
      'thu_tu_hien_thi': 10,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert(tenBangQuyTacDiem, {
      'loai_quy_tac': 'TRU_DIEM',
      'hang_muc': 'BAI_TAP',
      'mo_ta': 'Nộp bài tập muộn',
      'diem_thay_doi': -0.5,
      'thu_tu_hien_thi': 11,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }
}
