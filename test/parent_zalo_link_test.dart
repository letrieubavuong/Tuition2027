// File: test/parent_zalo_link_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tuition2025/models/hs.dart';
import 'package:tuition2025/services/hoc_sinh_service.dart';
import 'package:tuition2025/services/zalo_contact_service.dart';
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

  group('PARENT ZALO QUICK LINK TESTS', () {
    final zaloService = ZaloContactService.instance;
    final hsService = HocSinhService();

    test(
      'TEST 1: HS có parentPhone -> PHONE_AVAILABLE, tao Zalo deep-link phone flow',
      () async {
        final hs = HS(
          ten: 'Học sinh test 1',
          tenPhuHuynh: 'Chị Hoa',
          sdtPhuHuynh: '0987654321',
        );

        final savedHs = await hsService.taoHocSinh(hs);
        expect(savedHs.effectiveParentPhone, equals('0987654321'));
        expect(
          zaloService.getZaloLinkStatus(savedHs),
          equals(ZaloLinkStatus.phoneAvailable),
        );

        final deepLink = zaloService.getZaloDeepLink(savedHs);
        expect(deepLink, contains('0987654321'));
      },
    );

    test(
      'TEST 2: Không phone nhưng có zaloDisplayName -> MANUAL_NAME, fallback copy tên',
      () async {
        final hs = HS(
          ten: 'Học sinh test 2',
          tenPhuHuynh: 'Anh Tuấn',
          zaloDisplayName: 'Tuấn Zalo',
          zaloNote: 'Avatar áo xanh',
        );

        final savedHs = await hsService.taoHocSinh(hs);
        expect(savedHs.effectiveParentPhone, isNull);
        expect(
          zaloService.getZaloLinkStatus(savedHs),
          equals(ZaloLinkStatus.manualName),
        );

        final msg = zaloService.prepareParentMessage(
          savedHs,
          'Thông báo học tập',
        );
        expect(msg, contains('Học sinh test 2'));
      },
    );

    test(
      'TEST 3: Có saved profile link -> PROFILE_LINKED, dung profile link',
      () async {
        final hs = HS(
          ten: 'Học sinh test 3',
          zaloProfileLink: 'https://zalo.me/g/testgroup123',
        );

        final savedHs = await hsService.taoHocSinh(hs);
        expect(
          zaloService.getZaloLinkStatus(savedHs),
          equals(ZaloLinkStatus.profileLinked),
        );
        expect(
          savedHs.zaloProfileLink,
          equals('https://zalo.me/g/testgroup123'),
        );
      },
    );

    test('TEST 4: Không có bất kỳ contact nào -> UNLINKED', () async {
      final hs = HS(ten: 'Học sinh test 4');

      final savedHs = await hsService.taoHocSinh(hs);
      expect(
        zaloService.getZaloLinkStatus(savedHs),
        equals(ZaloLinkStatus.unlinked),
      );
    });

    test(
      'TEST 5: 2 HS có cùng tên PH -> Phân biệt theo student ID record, không dùng tên làm unique key',
      () async {
        final hs1 = await hsService.taoHocSinh(
          HS(
            ten: 'Minh Anh',
            tenPhuHuynh: 'Anh Tuấn',
            zaloDisplayName: 'Tuấn Zalo',
          ),
        );
        final hs2 = await hsService.taoHocSinh(
          HS(
            ten: 'Hoàng Anh',
            tenPhuHuynh: 'Anh Tuấn',
            zaloDisplayName: 'Tuấn Zalo (bố HA)',
          ),
        );

        expect(hs1.id, isNot(equals(hs2.id)));
        expect(hs1.tenPhuHuynh, equals(hs2.tenPhuHuynh));
        expect(hs1.zaloDisplayName, equals('Tuấn Zalo'));
        expect(hs2.zaloDisplayName, equals('Tuấn Zalo (bố HA)'));
      },
    );

    test(
      'TEST 6: Contact đã VERIFIED -> getZaloLinkStatus return VERIFIED',
      () async {
        final hs = HS(
          ten: 'Học sinh test 6',
          tenPhuHuynh: 'Chú Nam',
          sdtPhuHuynh: '0912345678',
          zaloLinkStatus: 'VERIFIED',
        );

        final savedHs = await hsService.taoHocSinh(hs);
        expect(
          zaloService.getZaloLinkStatus(savedHs),
          equals(ZaloLinkStatus.verified),
        );
      },
    );
  });
}
