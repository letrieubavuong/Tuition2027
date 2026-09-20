import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tuition2025/utils/db.dart';
import 'package:tuition2025/services/lich_hoc_chung_service.dart';
import 'package:tuition2025/models/lich_hoc_chung.dart';
import 'package:tuition2025/models/hs.dart';
import 'package:tuition2025/models/hs_lop_view_model.dart';
import 'package:tuition2025/widgets/gan_lich_hoc_dialog.dart';
import 'package:tuition2025/screens/gan_lich_hoc_page.dart';
import 'package:tuition2025/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;
  late LichHocChungService service;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 29,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE hoc_sinh (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              ten TEXT NOT NULL,
              sdt TEXT,
              truong_dang_hoc TEXT,
              dia_chi TEXT,
              ghi_chu TEXT,
              email TEXT,
              mien_giam INTEGER NOT NULL DEFAULT 0,
              so_buoi_du INTEGER NOT NULL DEFAULT 0,
              ca_hoc_truong TEXT NOT NULL DEFAULT 'Sáng',
              lich_can_mon_khac TEXT,
              facebook TEXT
            )
          ''');

          await db.execute('''
            CREATE TABLE lop (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              ten TEXT NOT NULL UNIQUE,
              khoi INTEGER NOT NULL
            )
          ''');

          await db.execute('''
            CREATE TABLE lich_hoc_chung (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              id_lop INTEGER NOT NULL,
              ngay_trong_tuan TEXT NOT NULL,
              gio_bat_dau TEXT NOT NULL,
              gio_ket_thuc TEXT NOT NULL,
              created_at TEXT,
              FOREIGN KEY(id_lop) REFERENCES lop(id)
            )
          ''');

          await db.execute('''
            CREATE TABLE lich_hoc_ca_nhan (
              id_hoc_sinh INTEGER NOT NULL,
              id_lich_hoc_chung INTEGER NOT NULL,
              PRIMARY KEY(id_hoc_sinh, id_lich_hoc_chung),
              FOREIGN KEY(id_hoc_sinh) REFERENCES hoc_sinh(id) ON DELETE CASCADE
            )
          ''');

          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_lhcn_lhc ON lich_hoc_ca_nhan (id_lich_hoc_chung)',
          );
        },
      ),
    );

    DBHelper.setTestDatabase(db);

    await db.insert('lop', {'id': 1, 'ten': 'Lớp 10A1', 'khoi': 10});
    await db.insert('lich_hoc_chung', {
      'id': 100,
      'id_lop': 1,
      'ngay_trong_tuan': 'Thứ Hai',
      'gio_bat_dau': '18:00',
      'gio_ket_thuc': '20:00',
    });

    service = LichHocChungService();
  });

  tearDown(() async {
    await db.close();
    DBHelper.setTestDatabase(null);
  });

  group('LichHocChungService Assignment Core Tests', () {
    test(
      'layDanhSachHocSinhDaGan và luuPhanCongLichHocHangLoat atomic operations',
      () async {
        for (int i = 1; i <= 5; i++) {
          await db.insert('hoc_sinh', {'id': i, 'ten': 'Học sinh $i'});
        }

        final initialAssigned = await service.layDanhSachHocSinhDaGan(100);
        expect(initialAssigned.isEmpty, isTrue);

        final success1 = await service.luuPhanCongLichHocHangLoat(
          idLichHocChung: 100,
          desiredHocSinhIds: {1, 2, 3},
        );
        expect(success1, isTrue);

        final assignedAfter1 = await service.layDanhSachHocSinhDaGan(100);
        expect(assignedAfter1, equals({1, 2, 3}));

        final success2 = await service.luuPhanCongLichHocHangLoat(
          idLichHocChung: 100,
          desiredHocSinhIds: {2, 3, 4, 5},
        );
        expect(success2, isTrue);

        final assignedAfter2 = await service.layDanhSachHocSinhDaGan(100);
        expect(assignedAfter2, equals({2, 3, 4, 5}));

        final success3 = await service.luuPhanCongLichHocHangLoat(
          idLichHocChung: 100,
          desiredHocSinhIds: {},
        );
        expect(success3, isTrue);

        final assignedAfter3 = await service.layDanhSachHocSinhDaGan(100);
        expect(assignedAfter3.isEmpty, isTrue);
      },
    );

    test(
      'demSoBuoiHocCaNhanTrongThang dem dung khi co 2 ca hoc cung nhat trong tuan',
      () async {
        await db.insert('lich_hoc_chung', {
          'id': 101,
          'id_lop': 1,
          'ngay_trong_tuan': 'Thứ Hai',
          'gio_bat_dau': '14:00',
          'gio_ket_thuc': '16:00',
        });
        await db.insert('lich_hoc_chung', {
          'id': 102,
          'id_lop': 1,
          'ngay_trong_tuan': 'Thứ Hai',
          'gio_bat_dau': '16:00',
          'gio_ket_thuc': '18:00',
        });

        await db.insert('hoc_sinh', {'id': 1, 'ten': 'Nguyễn Văn A'});
        await db.insert('lich_hoc_ca_nhan', {
          'id_hoc_sinh': 1,
          'id_lich_hoc_chung': 101,
        });
        await db.insert('lich_hoc_ca_nhan', {
          'id_hoc_sinh': 1,
          'id_lich_hoc_chung': 102,
        });

        final soBuoi = await service.demSoBuoiHocCaNhanTrongThang(
          1,
          '2026-09',
          idLop: 1,
        );
        expect(soBuoi, equals(8));
      },
    );
  });

  group('GanLichHocDialog & GanLichHocPage Widget Tests', () {
    final lichHocTest = LichHocChung(
      id: 100,
      idLop: 1,
      ngayTrongTuan: 'Thứ Hai',
      gioBatDau: '18:00',
      gioKetThuc: '20:00',
    );

    final List<HSLopViewModel> danhSachHSTest = [
      HSLopViewModel(
        hocSinh: HS(id: 1, ten: 'Học Sinh A', sdt: '0901234567'),
        ngayThamGia: '2026-01-01',
        trangThai: 'DANG_HOC',
      ),
      HSLopViewModel(
        hocSinh: HS(id: 2, ten: 'Học Sinh B', sdt: '0907654321'),
        ngayThamGia: '2026-01-01',
        trangThai: 'DANG_HOC',
      ),
      HSLopViewModel(
        hocSinh: HS(id: 3, ten: 'Học Sinh C', sdt: '0909999999'),
        ngayThamGia: '2026-01-01',
        trangThai: 'DANG_HOC',
      ),
    ];

    testWidgets('GanLichHocDialog renders correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [AppLocalizations.delegate],
          home: Scaffold(
            body: GanLichHocDialog(
              lichHocChung: lichHocTest,
              danhSachHocSinh: danhSachHSTest,
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(GanLichHocDialog), findsOneWidget);
    });

    testWidgets('GanLichHocPage renders correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [AppLocalizations.delegate],
          home: GanLichHocPage(
            lichHocChung: lichHocTest,
            danhSachHocSinh: danhSachHSTest,
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(GanLichHocPage), findsOneWidget);
    });
  });
}
