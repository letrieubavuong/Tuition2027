// File: lib/utils/db_v2.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBV2 {
  static final DBV2 instance = DBV2._init();
  static Database? _database;

  DBV2._init();

  static const String dbName = 'tuition_v2.db';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB(dbName);
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
      onConfigure: _onConfigure,
    );
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
    await db.execute('PRAGMA journal_mode = WAL');
  }

  Future<void> _createDB(Database db, int version) async {
    const idPK = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textNotN = 'TEXT NOT NULL';
    const textNull = 'TEXT';
    const intNotN = 'INTEGER NOT NULL';
    const intNull = 'INTEGER';
    const intDef0 = 'INTEGER NOT NULL DEFAULT 0';

    // 1. hoc_sinh (Humans)
    await db.execute('''
      CREATE TABLE hoc_sinh (
        id $idPK,
        ho_ten $textNotN,
        ten_phu_huynh $textNull,
        sdt_phu_huynh $textNull,
        sdt_hoc_sinh $textNull,
        ngay_sinh $textNull,
        gioi_tinh $textNull,
        truong_dang_hoc $textNull,
        khoi $intNull,
        dia_chi $textNull,
        email $textNull,
        facebook $textNull,
        ghi_chu $textNull,
        zalo_user_id $textNull,
        zalo_display_name $textNull,
        zalo_link_status $textNull DEFAULT 'UNLINKED',
        da_luu_tru $intDef0,
        created_at $textNotN,
        updated_at $textNotN,
        CHECK (zalo_link_status IN ('UNLINKED', 'LINKED', 'PENDING'))
      )
    ''');

    // 2. lop (Classes)
    await db.execute('''
      CREATE TABLE lop (
        id $idPK,
        ten_lop $textNotN,
        khoi $intNull,
        mon_hoc $textNull,
        hoc_phi_moi_buoi $intNull,
        so_buoi_chuan_thang INTEGER NOT NULL DEFAULT 12,
        hoc_phi_thang_toi_da $intNull,
        si_so_toi_da $intNull,
        ghi_chu $textNull,
        da_luu_tru $intDef0,
        created_at $textNotN,
        updated_at $textNotN,
        CHECK (so_buoi_chuan_thang > 0)
      )
    ''');

    // 3. tham_gia_lop (Source of Truth for membership)
    // No CASCADE DELETE on hoc_sinh/lop to preserve history if UI "deletes" them
    await db.execute('''
      CREATE TABLE tham_gia_lop (
        id $idPK,
        id_hoc_sinh $intNotN,
        id_lop $intNotN,
        tu_ngay $textNotN,
        den_ngay $textNull,
        ly_do_ket_thuc $textNull,
        mien_giam_phan_tram $intDef0,
        ghi_chu $textNull,
        created_at $textNotN,
        updated_at $textNotN,
        FOREIGN KEY (id_hoc_sinh) REFERENCES hoc_sinh (id),
        FOREIGN KEY (id_lop) REFERENCES lop (id),
        UNIQUE(id_hoc_sinh, id_lop, tu_ngay)
      )
    ''');
    
    // Partial unique to ensure only one open membership per student-class
    await db.execute('''
      CREATE UNIQUE INDEX idx_membership_open 
      ON tham_gia_lop (id_hoc_sinh, id_lop) 
      WHERE den_ngay IS NULL
    ''');

    // 4. lich_hoc (Recurring schedules)
    await db.execute('''
      CREATE TABLE lich_hoc (
        id $idPK,
        id_lop $intNotN,
        thu_trong_tuan $intNotN, -- 1=Mon, 7=Sun (DateTime.weekday compatible)
        gio_bat_dau $textNotN,   -- HH:mm
        gio_ket_thuc $textNotN,  -- HH:mm
        hieu_luc_tu $textNotN,   -- YYYY-MM-DD
        hieu_luc_den $textNull,  -- YYYY-MM-DD
        ghi_chu $textNull,
        created_at $textNotN,
        updated_at $textNotN,
        FOREIGN KEY (id_lop) REFERENCES lop (id) ON DELETE CASCADE,
        CHECK (thu_trong_tuan BETWEEN 1 AND 7)
      )
    ''');

    // 5. phan_ca_hoc_sinh (Student assignment to specific recurring schedules)
    await db.execute('''
      CREATE TABLE phan_ca_hoc_sinh (
        id $idPK,
        id_hoc_sinh $intNotN,
        id_lop $intNotN,
        id_lich_hoc $intNotN,
        tu_ngay $textNotN,
        den_ngay $textNull,
        nguon $textNull,
        ghi_chu $textNull,
        created_at $textNotN,
        updated_at $textNotN,
        FOREIGN KEY (id_hoc_sinh) REFERENCES hoc_sinh (id),
        FOREIGN KEY (id_lop) REFERENCES lop (id),
        FOREIGN KEY (id_lich_hoc) REFERENCES lich_hoc (id) ON DELETE CASCADE
      )
    ''');

    // 6. buoi_hoc (Historical or Planned Sessions)
    await db.execute('''
      CREATE TABLE buoi_hoc (
        id $idPK,
        id_lop $intNotN,
        id_lich_hoc $intNull,
        ngay $textNotN,          -- YYYY-MM-DD
        gio_bat_dau $textNotN,   -- HH:mm
        gio_ket_thuc $textNotN,  -- HH:mm
        loai $textNotN,          -- CHINH, HOC_BU, PHAT_SINH
        trang_thai $textNotN,    -- DU_KIEN, DA_HOC, HUY, NGHI_LE
        ghi_chu $textNull,
        created_at $textNotN,
        updated_at $textNotN,
        FOREIGN KEY (id_lop) REFERENCES lop (id),
        FOREIGN KEY (id_lich_hoc) REFERENCES lich_hoc (id) ON DELETE SET NULL,
        UNIQUE(id_lop, ngay, gio_bat_dau),
        CHECK (loai IN ('CHINH', 'HOC_BU', 'PHAT_SINH')),
        CHECK (trang_thai IN ('DU_KIEN', 'DA_HOC', 'HUY', 'NGHI_LE'))
      )
    ''');

    // 7. dieu_chinh_buoi_hoc (Exceptions like shift changes or one-off makeups)
    await db.execute('''
      CREATE TABLE dieu_chinh_buoi_hoc (
        id $idPK,
        id_hoc_sinh $intNotN,
        id_buoi_hoc_goc $intNull,
        id_buoi_hoc_tham_gia $intNotN,
        id_lop_goc $intNotN,
        loai $textNotN,          -- DOI_CA, HOC_BU, PHAT_SINH
        ly_do $textNull,
        created_at $textNotN,
        FOREIGN KEY (id_hoc_sinh) REFERENCES hoc_sinh (id),
        FOREIGN KEY (id_buoi_hoc_goc) REFERENCES buoi_hoc (id),
        FOREIGN KEY (id_buoi_hoc_tham_gia) REFERENCES buoi_hoc (id),
        FOREIGN KEY (id_lop_goc) REFERENCES lop (id),
        CHECK (loai IN ('DOI_CA', 'HOC_BU', 'PHAT_SINH'))
      )
    ''');

    // 8. diem_danh (Attendance)
    await db.execute('''
      CREATE TABLE diem_danh (
        id $idPK,
        id_buoi_hoc $intNotN,
        id_hoc_sinh $intNotN,
        id_lop_goc $intNotN,
        trang_thai $textNotN,    -- CO_MAT, TRE, NGHI_CO_PHEP, NGHI_KHONG_PHEP, HOC_BU
        loai_tham_gia $textNotN, -- CHINH, DOI_CA, HOC_BU
        id_buoi_vang_goc $intNull,
        ghi_chu $textNull,
        created_at $textNotN,
        updated_at $textNotN,
        FOREIGN KEY (id_buoi_hoc) REFERENCES buoi_hoc (id),
        FOREIGN KEY (id_hoc_sinh) REFERENCES hoc_sinh (id),
        FOREIGN KEY (id_lop_goc) REFERENCES lop (id),
        FOREIGN KEY (id_buoi_vang_goc) REFERENCES buoi_hoc (id),
        UNIQUE(id_buoi_hoc, id_hoc_sinh),
        CHECK (trang_thai IN ('CO_MAT', 'TRE', 'NGHI_CO_PHEP', 'NGHI_KHONG_PHEP', 'HOC_BU')),
        CHECK (loai_tham_gia IN ('CHINH', 'DOI_CA', 'HOC_BU'))
      )
    ''');

    // 9. lich_can (Blocked schedules for students)
    await db.execute('''
      CREATE TABLE lich_can (
        id $idPK,
        id_hoc_sinh $intNotN,
        loai $textNotN,          -- HOC_CHINH_KHOA, HOC_MON_KHAC, BAN_CA_NHAN, etc.
        muc_do $textNotN,        -- CUNG, MEM
        thu_trong_tuan $intNull,
        ngay_cu_the $textNull,
        gio_bat_dau $textNotN,
        gio_ket_thuc $textNotN,
        hieu_luc_tu $textNotN,
        hieu_luc_den $textNull,
        ghi_chu $textNull,
        FOREIGN KEY (id_hoc_sinh) REFERENCES hoc_sinh (id) ON DELETE CASCADE,
        CHECK (muc_do IN ('CUNG', 'MEM'))
      )
    ''');

    // 10. buoi_du_ledger (Source of truth for extra session credits)
    await db.execute('''
      CREATE TABLE buoi_du_ledger (
        id $idPK,
        id_hoc_sinh $intNotN,
        id_lop $intNotN,
        id_buoi_hoc $intNull,
        ngay_hieu_luc $textNotN,
        delta $intNotN,
        ly_do $textNotN,         -- VUOT_SO_BUOI_CHUAN, BU_TRU_NGHI_CO_PHEP, DIEU_CHINH_THU_CONG, MIGRATION
        ghi_chu $textNull,
        created_at $textNotN,
        FOREIGN KEY (id_hoc_sinh) REFERENCES hoc_sinh (id),
        FOREIGN KEY (id_lop) REFERENCES lop (id),
        FOREIGN KEY (id_buoi_hoc) REFERENCES buoi_hoc (id),
        UNIQUE(id_hoc_sinh, id_lop, id_buoi_hoc, ly_do)
      )
    ''');

    // 11. thanh_toan (Actual payments received)
    await db.execute('''
      CREATE TABLE thanh_toan (
        id $idPK,
        id_hoc_sinh $intNotN,
        id_lop $intNotN,
        thang $textNotN,         -- YYYY-MM
        so_tien $intNotN,
        ngay_thanh_toan $textNotN,
        phuong_thuc $textNotN,   -- TIEN_MAT, CHUYEN_KHOAN, KHAC
        ma_giao_dich $textNull,
        ghi_chu $textNull,
        created_at $textNotN,
        FOREIGN KEY (id_hoc_sinh) REFERENCES hoc_sinh (id),
        FOREIGN KEY (id_lop) REFERENCES lop (id),
        CHECK (phuong_thuc IN ('TIEN_MAT', 'CHUYEN_KHOAN', 'KHAC'))
      )
    ''');
    
    await db.execute('''
      CREATE UNIQUE INDEX idx_payment_tx 
      ON thanh_toan (ma_giao_dich) 
      WHERE ma_giao_dich IS NOT NULL AND TRIM(ma_giao_dich) <> ''
    ''');

    // 12. migration_issue
    await db.execute('''
      CREATE TABLE migration_issue (
        id $idPK,
        entity_type $textNull,
        legacy_table $textNull,
        legacy_id $textNull,
        issue_code $textNotN,
        severity $textNotN, -- ERROR, WARNING, INFO
        message $textNull,
        raw_reference $textNull,
        resolved $intDef0,
        created_at $textNotN
      )
    ''');

    // Indices for performance
    await db.execute('CREATE INDEX idx_hs_hoten ON hoc_sinh (ho_ten)');
    await db.execute('CREATE INDEX idx_tg_active ON tham_gia_lop (id_lop, tu_ngay, den_ngay)');
    await db.execute('CREATE INDEX idx_lh_lop_thu ON lich_hoc (id_lop, thu_trong_tuan)');
    await db.execute('CREATE INDEX idx_pc_hs_lh ON phan_ca_hoc_sinh (id_hoc_sinh, id_lich_hoc)');
    await db.execute('CREATE INDEX idx_bh_lop_ngay ON buoi_hoc (id_lop, ngay)');
    await db.execute('CREATE INDEX idx_dd_bh_hs ON diem_danh (id_buoi_hoc, id_hoc_sinh)');
    await db.execute('CREATE INDEX idx_bdl_hs_lop ON buoi_du_ledger (id_hoc_sinh, id_lop)');
    await db.execute('CREATE INDEX idx_tt_hs_lop_thang ON thanh_toan (id_hoc_sinh, id_lop, thang)');
    await db.execute('CREATE INDEX idx_issue_code ON migration_issue (issue_code, severity)');
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
