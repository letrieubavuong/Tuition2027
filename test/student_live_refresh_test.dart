// File: test/student_live_refresh_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tuition2025/models/hs.dart';
import 'package:tuition2025/models/lop.dart';
import 'package:tuition2025/models/lop_hoc_sinh.dart';
import 'package:tuition2025/services/hoc_sinh_service.dart';
import 'package:tuition2025/services/lop_service.dart';
import 'package:tuition2025/services/lop_hoc_sinh_service.dart';
import 'package:tuition2025/services/student_event_service.dart';
import 'package:tuition2025/utils/db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    final dbHelper = DBHelper.instance;
    final db = await dbHelper.database;
    await db.execute('PRAGMA foreign_keys = OFF');
    await db.delete(DBHelper.tenBangLopHS);
    await db.delete(DBHelper.tenBangLop);
    await db.delete(DBHelper.tenBangHS);
    await db.execute('PRAGMA foreign_keys = ON');
  });

  group('STUDENT LIVE REFRESH TESTS', () {
    test(
      'TEST 1: Sửa tên HS A -> B: DS học sinh cập nhật tên mới ngay lập tức qua StudentEventService',
      () async {
        final hsService = HocSinhService();
        final hsA = await hsService.taoHocSinh(
          HS(ten: 'Nguyễn Văn A', sdt: '0901234567'),
        );

        final list = <HS>[hsA];
        final subscription = StudentEventService().onStudentUpdated.listen((
          updatedHs,
        ) {
          final index = list.indexWhere((x) => x.id == updatedHs.id);
          if (index != -1) {
            list[index] = updatedHs;
          }
        });

        final updatedHsA = hsA.copyWith(ten: 'Nguyễn Văn B');
        await hsService.capNhatHocSinh(updatedHsA);

        await Future.delayed(const Duration(milliseconds: 50));
        expect(list.first.ten, equals('Nguyễn Văn B'));

        await subscription.cancel();
      },
    );

    test(
      'TEST 2: Sửa SĐT: HS detail nhận được SĐT mới ngay lập tức qua event broadcast',
      () async {
        final hsService = HocSinhService();
        final hs = await hsService.taoHocSinh(
          HS(ten: 'Trần Thị C', sdt: '0123456789'),
        );

        HS currentDetailHs = hs;
        final subscription = StudentEventService().onStudentUpdated.listen((
          updatedHs,
        ) {
          if (updatedHs.id == currentDetailHs.id) {
            currentDetailHs = updatedHs;
          }
        });

        final updatedHs = hs.copyWith(sdt: '0987654321');
        await hsService.capNhatHocSinh(updatedHs);

        await Future.delayed(const Duration(milliseconds: 50));
        expect(currentDetailHs.sdt, equals('0987654321'));

        await subscription.cancel();
      },
    );

    test(
      'TEST 3: Sửa tên từ màn hình detail: Broadcast event cập nhật state danh sách mà không cần restart app',
      () async {
        final hsService = HocSinhService();
        final hs = await hsService.taoHocSinh(
          HS(ten: 'Lê Văn D', sdt: '0911223344'),
        );

        final danhSachGlobal = <HS>[hs];
        final subscription = StudentEventService().onStudentUpdated.listen((
          updatedHs,
        ) {
          final index = danhSachGlobal.indexWhere((x) => x.id == updatedHs.id);
          if (index != -1) {
            danhSachGlobal[index] = updatedHs;
          }
        });

        // Giả lập sửa tên từ detail
        final editedInDetail = hs.copyWith(ten: 'Lê Văn D Mới');
        await hsService.capNhatHocSinh(editedInDetail);

        await Future.delayed(const Duration(milliseconds: 50));
        expect(danhSachGlobal.first.ten, equals('Lê Văn D Mới'));

        await subscription.cancel();
      },
    );

    test(
      'TEST 4: Sửa HS khi đang ở LopDetail: Query JOIN lại cơ sở dữ liệu trả về thông tin tên/SĐT mới ngay',
      () async {
        final hsService = HocSinhService();
        final lopService = LopService();
        final lhsService = LopHocSinhService();

        final hs = await hsService.taoHocSinh(
          HS(ten: 'Phạm Văn E', sdt: '0333444555'),
        );
        final lop = await lopService.taoLop(Lop(ten: 'Lớp 10A1', khoi: 10));
        await lhsService.themHocSinhVaoLop(
          LopHocSinh(
            idLop: lop.id!,
            idHocSinh: hs.id!,
            ngayThamGia: '2025-01-01',
          ),
        );

        var dsHSCuaLop = await lhsService.docDSHSThuocLop(lop.id!);
        expect(dsHSCuaLop.first.ten, equals('Phạm Văn E'));

        // Cập nhật thông tin học sinh
        final updatedHs = hs.copyWith(
          ten: 'Phạm Văn E (Đã Sửa)',
          sdt: '0999888777',
        );
        await hsService.capNhatHocSinh(updatedHs);

        // docDSHSThuocLop JOIN trực tiếp từ SQLite table hoc_sinh
        dsHSCuaLop = await lhsService.docDSHSThuocLop(lop.id!);
        expect(dsHSCuaLop.first.ten, equals('Phạm Văn E (Đã Sửa)'));
        expect(dsHSCuaLop.first.sdt, equals('0999888777'));
      },
    );

    test(
      'TEST 5: Search "Nguyễn", Đổi Nguyễn -> Trần: HS biến khỏi filtered result ngay',
      () {
        final hs1 = HS(id: 1, ten: 'Nguyễn Văn A', sdt: '0123');
        final hs2 = HS(id: 2, ten: 'Nguyễn Văn B', sdt: '0456');
        final danhSachHS = <HS>[hs1, hs2];

        String searchControllerText = 'Nguyễn';
        List<HS> filteredDanhSachHS = danhSachHS.where((x) {
          return x.ten.toLowerCase().contains(
            searchControllerText.toLowerCase(),
          );
        }).toList();

        expect(filteredDanhSachHS.length, equals(2));

        // Đổi Nguyễn Văn A -> Trần Văn A
        final updatedHs1 = hs1.copyWith(ten: 'Trần Văn A');
        final index = danhSachHS.indexWhere((x) => x.id == updatedHs1.id);
        if (index != -1) {
          danhSachHS[index] = updatedHs1;
        }

        // Re-filter search query
        filteredDanhSachHS = danhSachHS.where((x) {
          return x.ten.toLowerCase().contains(
            searchControllerText.toLowerCase(),
          );
        }).toList();

        expect(filteredDanhSachHS.length, equals(1));
        expect(filteredDanhSachHS.first.ten, equals('Nguyễn Văn B'));
      },
    );

    test(
      'TEST 6: Update fail ở SQLite (ID không tồn tại): Không bắn event giả và trả về 0',
      () async {
        final hsService = HocSinhService();
        final hsKhongTonTai = HS(id: 99999, ten: 'Học Sinh Giả', sdt: '0000');

        bool eventFired = false;
        final subscription = StudentEventService().onStudentUpdated.listen((_) {
          eventFired = true;
        });

        final result = await hsService.capNhatHocSinh(hsKhongTonTai);

        await Future.delayed(const Duration(milliseconds: 50));
        expect(result, equals(0));
        expect(eventFired, isFalse);

        await subscription.cancel();
      },
    );
  });
}
