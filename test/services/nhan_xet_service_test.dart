import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tuition2025/models/nhan_xet_thang.dart';
import 'package:tuition2025/services/nhan_xet_service.dart';
import 'package:tuition2025/utils/db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('NhanXetService Tests', () {
    final nhanXetService = NhanXetService();

    test(
      'layHoacTaoNhanXet returns draft with id=null when no row exists',
      () async {
        final nx = await nhanXetService.layHoacTaoNhanXet(999, 888, '2026-09');
        expect(nx.id, isNull);
        expect(nx.idHocSinh, equals(999));
        expect(nx.idLop, equals(888));
        expect(nx.thang, equals('2026-09'));
        expect(nx.isManualOverride, isFalse);
      },
    );

    test(
      'capNhatNhanXet clamps scores 0..10 and sets isManualOverride to true',
      () async {
        final draft = await nhanXetService.layHoacTaoNhanXet(
          101,
          202,
          '2026-09',
        );
        draft.diemThaiDo = 12.5; // Out of bounds upper
        draft.diemBaiTap = -3.0; // Out of bounds lower
        draft.diemKiemTra = 9.0;
        draft.nhanXetChung = 'Học sinh rất cố gắng.';

        final id = await nhanXetService.capNhatNhanXet(draft);
        expect(id, greaterThan(0));

        final saved = await nhanXetService.layHoacTaoNhanXet(
          101,
          202,
          '2026-09',
        );
        expect(saved.id, equals(id));
        expect(saved.isManualOverride, isTrue);
        expect(saved.diemThaiDo, equals(10.0));
        expect(saved.diemBaiTap, equals(0.0));
        expect(saved.diemKiemTra, equals(9.0));
      },
    );

    test('tinhXepHang returns correct ranks for 0..10 score scale', () {
      expect(
        nhanXetService.tinhXepHang(10.0, 10.0, 10.0, 10.0),
        equals('Thách Đấu'),
      );
      expect(nhanXetService.tinhXepHang(8.0, 8.0, 8.0, 8.0), equals('Cao Thủ'));
      expect(
        nhanXetService.tinhXepHang(6.0, 6.0, 6.0, 6.0),
        equals('Tinh Anh'),
      );
      expect(
        nhanXetService.tinhXepHang(4.5, 4.5, 4.5, 4.5),
        equals('Kim Cương'),
      );
      expect(
        nhanXetService.tinhXepHang(3.0, 3.0, 3.0, 3.0),
        equals('Bạch Kim'),
      );
      expect(nhanXetService.tinhXepHang(1.5, 1.5, 1.5, 1.5), equals('Vàng'));
      expect(nhanXetService.tinhXepHang(0.0, 0.0, 0.0, 0.0), equals('Vàng'));
    });
  });
}
