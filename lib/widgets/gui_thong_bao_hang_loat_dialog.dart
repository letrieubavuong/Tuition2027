// File: lib/widgets/gui_thong_bao_hang_loat_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/lop.dart';
import '../services/lop_service.dart';
import '../services/report_service.dart';
import '../services/caidat_service.dart';
import '../services/lop_hoc_sinh_service.dart';
import '../utils/vietqr_util.dart';
import '../utils/toast_helper.dart';

enum NotificationType {
  hocPhi, // 📌 Nhắc học phí
  baoNghiHoc, // 📢 Báo nghỉ học / nghỉ lễ
  baoDoiLich, // ⏰ Báo đổi lịch dạy
  custom, // ✍️ Thông báo tùy chỉnh
}

class GuiThongBaoHangLoatDialog extends StatefulWidget {
  final int? initialLopId;
  final String? initialThang;
  final bool initialOnlyUnpaid;
  final NotificationType? initialType;
  final List<NotificationType>? allowedTypes;
  final String? dialogTitle;

  const GuiThongBaoHangLoatDialog({
    super.key,
    this.initialLopId,
    this.initialThang,
    this.initialOnlyUnpaid = true,
    this.initialType,
    this.allowedTypes,
    this.dialogTitle,
  });

  @override
  State<GuiThongBaoHangLoatDialog> createState() =>
      _GuiThongBaoHangLoatDialogState();
}

class _GuiThongBaoHangLoatDialogState extends State<GuiThongBaoHangLoatDialog> {
  final LopService _lopService = LopService();
  final ReportService _reportService = ReportService();
  final CaiDatService _caiDatService = CaiDatService();

  NotificationType _selectedType = NotificationType.hocPhi;
  List<Lop> _danhSachLop = [];
  int? _selectedLopId;
  late String _selectedThang;
  bool _onlyUnpaid = true;
  bool _isLoading = true;

  // Controllers cho mẫu thông báo
  final _ngayNghiController = TextEditingController(
    text: 'Thứ Hai (15/09/2026)',
  );
  final _lyDoNghiController = TextEditingController(
    text: 'Nghỉ lễ theo quy định nhà trường',
  );
  final _danDoNghiController = TextEditingController(
    text: 'Học sinh ôn bài tập ở nhà và đi học lại đúng giờ vào tuần sau.',
  );

  final _buoiCuController = TextEditingController(
    text: 'Thứ Hai 17:30 - 19:00',
  );
  final _buoiMoiController = TextEditingController(
    text: 'Thứ Tư 18:00 - 19:30',
  );
  final _ghiChuDoiLichController = TextEditingController(
    text: 'Do trùng lịch thi ở trường.',
  );

  final _tieuDeCustomController = TextEditingController(
    text: 'THÔNG BÁO TỪ GIÁO VIÊN',
  );
  final _noiDungCustomController = TextEditingController(
    text:
        'Kính gửi quý phụ huynh, xin lưu ý theo dõi tình hình học tập và chuẩn bị bài của học sinh.',
  );

  // Bank Info cho học phí
  String _bankId = 'sacombank';
  String _accountNo = '0905073175';
  String _accountName = 'LE TRIEU BA VUONG';

  // Danh sách tất cả học sinh thỏa mãn điều kiện
  List<_StudentNotifyItem> _allStudents = [];
  Set<String> _selectedStudentIds = {};

  @override
  void initState() {
    super.initState();
    _selectedLopId = widget.initialLopId;
    _onlyUnpaid = widget.initialOnlyUnpaid;

    final types = widget.allowedTypes ?? NotificationType.values;
    _selectedType =
        widget.initialType ??
        (types.isNotEmpty ? types.first : NotificationType.hocPhi);

    final now = DateTime.now();
    _selectedThang = widget.initialThang ?? DateFormat('yyyy-MM').format(now);

    _taiDuLieuBanDau();
  }

  @override
  void dispose() {
    _ngayNghiController.dispose();
    _lyDoNghiController.dispose();
    _danDoNghiController.dispose();
    _buoiCuController.dispose();
    _buoiMoiController.dispose();
    _ghiChuDoiLichController.dispose();
    _tieuDeCustomController.dispose();
    _noiDungCustomController.dispose();
    super.dispose();
  }

  final LopHocSinhService _lhsService = LopHocSinhService();

  Future<void> _taiDuLieuBanDau() async {
    setState(() => _isLoading = true);
    try {
      final dsLop = await _lopService.docTatCaLop();
      final bankId = await _caiDatService.layCaiDat('bank_id') ?? 'sacombank';
      final accountNo =
          await _caiDatService.layCaiDat('account_no') ?? '0905073175';
      final accountName =
          await _caiDatService.layCaiDat('account_name') ?? 'LE TRIEU BA VUONG';

      _danhSachLop = dsLop;
      _bankId = bankId;
      _accountNo = accountNo;
      _accountName = accountName;

      await _taiDanhSachHocSinh();
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, 'Lỗi tải dữ liệu: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _taiDanhSachHocSinh() async {
    List<Lop> targetLops = [];
    if (_selectedLopId != null) {
      targetLops = _danhSachLop.where((l) => l.id == _selectedLopId).toList();
    } else {
      targetLops = List.from(_danhSachLop);
    }

    List<_StudentNotifyItem> result = [];

    for (var lop in targetLops) {
      if (lop.id == null) continue;
      try {
        final report = await _reportService.layBaoCaoHocPhiThang(
          lop.id!,
          _selectedThang,
          persist: false,
        );

        final Set<int> unpaidHsIds = {};

        for (var hsNo in report.dsHocSinhConNo) {
          unpaidHsIds.add(hsNo.idHocSinh);
          result.add(
            _StudentNotifyItem(
              id: hsNo.idHocSinh,
              idLop: lop.id!,
              tenHocSinh: hsNo.tenHocSinh,
              tenLop: lop.ten,
              sdt: hsNo.sdt ?? '',
              soBuoiDu: hsNo.soBuoiDu,
              tongSoBuoi: hsNo.tongSoBuoi,
              soTienCanNop: hsNo.soTienCanNop,
              soTienDaDong: hsNo.soTienDaDong,
              soTienConNo: hsNo.soTienConNo,
              isDaHoanThanh: false,
            ),
          );
        }

        if (!_onlyUnpaid) {
          final allHsInLop = await _lhsService.docDSHSThuocLop(lop.id!);
          for (var hs in allHsInLop) {
            if (hs.id != null && !unpaidHsIds.contains(hs.id!)) {
              result.add(
                _StudentNotifyItem(
                  id: hs.id!,
                  idLop: lop.id!,
                  tenHocSinh: hs.ten,
                  tenLop: lop.ten,
                  sdt: hs.sdt ?? '',
                  soBuoiDu: hs.soBuoiDu,
                  tongSoBuoi: report.tongSoBuoi,
                  soTienCanNop: 0,
                  soTienDaDong: 0,
                  soTienConNo: 0,
                  isDaHoanThanh: true,
                ),
              );
            }
          }
        }
      } catch (e) {
        debugPrint('Lỗi tải báo cáo lớp ${lop.ten}: $e');
      }
    }

    setState(() {
      _allStudents = result;
      _selectedStudentIds = result.map((item) => item.uniqueKey).toSet();
    });
  }

  String _buildMessageForStudent(_StudentNotifyItem item) {
    switch (_selectedType) {
      case NotificationType.hocPhi:
        return VietQRUtil.taoNoiDungThongBaoHocPhi(
          tenHocSinh: item.tenHocSinh,
          tenLop: item.tenLop,
          thang: _selectedThang,
          soBuoiDu: item.soBuoiDu,
          tongSoBuoi: item.tongSoBuoi,
          soTienCanNop: item.soTienCanNop,
          soTienDaDong: item.soTienDaDong,
          soTienConNo: item.soTienConNo,
          bankId: _bankId,
          accountNo: _accountNo,
          accountName: _accountName,
          isVi: true,
        );

      case NotificationType.baoNghiHoc:
        final StringBuffer sb = StringBuffer();
        sb.writeln(
          'Kính gửi phụ huynh học sinh ${item.tenHocSinh} (Lớp ${item.tenLop}),',
        );
        sb.writeln('📢 GIÁO VIÊN THÔNG BÁO NGHỈ HỌC:');
        sb.writeln('- Thời gian nghỉ: ${_ngayNghiController.text.trim()}');
        sb.writeln('- Lý do: ${_lyDoNghiController.text.trim()}');
        if (_danDoNghiController.text.trim().isNotEmpty) {
          sb.writeln('- Dặn dò: ${_danDoNghiController.text.trim()}');
        }
        sb.writeln('\nTrân trọng cảm ơn quý phụ huynh!');
        return sb.toString();

      case NotificationType.baoDoiLich:
        final StringBuffer sb = StringBuffer();
        sb.writeln(
          'Kính gửi phụ huynh học sinh ${item.tenHocSinh} (Lớp ${item.tenLop}),',
        );
        sb.writeln('⏰ GIÁO VIÊN THÔNG BÁO ĐỔI LỊCH DẠY:');
        sb.writeln('- Lịch cũ: ${_buoiCuController.text.trim()}');
        sb.writeln(
          '- Lịch học mới (thay thế): ${_buoiMoiController.text.trim()}',
        );
        if (_ghiChuDoiLichController.text.trim().isNotEmpty) {
          sb.writeln('- Ghi chú: ${_ghiChuDoiLichController.text.trim()}');
        }
        sb.writeln(
          '\nKính mong quý phụ huynh nhắc nhở học sinh đi học đúng giờ mới. Xin cảm ơn!',
        );
        return sb.toString();

      case NotificationType.custom:
        final StringBuffer sb = StringBuffer();
        sb.writeln(
          'Kính gửi phụ huynh học sinh ${item.tenHocSinh} (Lớp ${item.tenLop}),',
        );
        sb.writeln('📌 ${_tieuDeCustomController.text.trim().toUpperCase()}:');
        sb.writeln(_noiDungCustomController.text.trim());
        sb.writeln('\nTrân trọng!');
        return sb.toString();
    }
  }

  void _moZalo(String sdt, String message) async {
    if (message.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: message));
    }
    if (sdt.isEmpty) {
      if (mounted) {
        ToastHelper.showWarning(context, 'Học sinh không có SĐT phụ huynh!');
      }
      return;
    }
    var cleanSdt = sdt.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanSdt.startsWith('0')) {
      cleanSdt = '84${cleanSdt.substring(1)}';
    }
    if (cleanSdt.isEmpty) {
      if (mounted) {
        ToastHelper.showWarning(
          context,
          'Số điện thoại phụ huynh không hợp lệ!',
        );
      }
      return;
    }

    final String zaloUrlStr = 'https://zalo.me/$cleanSdt';
    final Uri zaloUri = Uri.parse(zaloUrlStr);

    bool launched = false;
    try {
      if (await canLaunchUrl(zaloUri)) {
        launched = await launchUrl(
          zaloUri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        launched = await launchUrl(
          zaloUri,
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (_) {
      try {
        launched = await launchUrl(zaloUri, mode: LaunchMode.platformDefault);
      } catch (_) {}
    }

    if (mounted) {
      if (launched) {
        ToastHelper.showSuccess(
          context,
          'Đã copy tin nhắn & đang mở Zalo ($cleanSdt)...',
        );
      } else {
        ToastHelper.showWarning(
          context,
          'Đã copy nội dung tin nhắn! Vui lòng dán (paste) trực tiếp vào Zalo.',
        );
      }
    }
  }

  void _guiZaloHangLoat() {
    final selectedItems = _allStudents
        .where((item) => _selectedStudentIds.contains(item.uniqueKey))
        .toList();

    if (selectedItems.isEmpty) {
      ToastHelper.showWarning(context, 'Vui lòng chọn ít nhất 1 phụ huynh!');
      return;
    }

    int currentIndex = 0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final currentItem = selectedItems[currentIndex];
          final currentMsg = _buildMessageForStudent(currentItem);

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                const Icon(Icons.chat_bubble_rounded, color: Color(0xFF0068FF)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Gửi Zalo (${currentIndex + 1}/${selectedItems.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0068FF).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Học sinh: ${currentItem.tenHocSinh} (Lớp ${currentItem.tenLop})',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'SĐT: ${currentItem.sdt.isNotEmpty ? currentItem.sdt : "Chưa có"}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.blueAccent,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Bấm nút dưới đây để copy tin nhắn và mở ứng dụng Zalo:',
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  constraints: const BoxConstraints(maxHeight: 100),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      currentMsg,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              if (currentIndex > 0)
                TextButton(
                  onPressed: () {
                    setDialogState(() {
                      currentIndex--;
                    });
                  },
                  child: const Text('Quay lại'),
                ),
              ElevatedButton.icon(
                onPressed: () {
                  _moZalo(currentItem.sdt, currentMsg);
                  if (currentIndex < selectedItems.length - 1) {
                    setDialogState(() {
                      currentIndex++;
                    });
                  } else {
                    Navigator.pop(ctx);
                    ToastHelper.showSuccess(context, 'Đã hoàn tất gửi Zalo!');
                  }
                },
                icon: const Icon(Icons.send_rounded, size: 16),
                label: Text(
                  currentIndex < selectedItems.length - 1
                      ? 'Mở Zalo (${currentItem.tenHocSinh}) & Tiếp'
                      : 'Mở Zalo (${currentItem.tenHocSinh}) & Xong',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0068FF),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _moSMS(String sdt, String message) async {
    final cleanSdt = sdt.replaceAll(RegExp(r'[^\d]'), '');
    final Uri smsUri = Uri(
      scheme: 'sms',
      path: cleanSdt,
      queryParameters: <String, String>{'body': message},
    );
    try {
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
      } else {
        await Clipboard.setData(ClipboardData(text: message));
        if (mounted) {
          ToastHelper.showWarning(
            context,
            'Không mở được SMS. Đã copy nội dung tin nhắn!',
          );
        }
      }
    } catch (e) {
      await Clipboard.setData(ClipboardData(text: message));
      if (mounted) {
        ToastHelper.showSuccess(context, 'Đã copy nội dung tin nhắn!');
      }
    }
  }

  void _chiaSeHangLoat() {
    final selectedItems = _allStudents
        .where((item) => _selectedStudentIds.contains(item.uniqueKey))
        .toList();

    if (selectedItems.isEmpty) {
      ToastHelper.showWarning(context, 'Vui lòng chọn ít nhất 1 phụ huynh!');
      return;
    }

    final StringBuffer sb = StringBuffer();
    sb.writeln('=== TỔNG HỢP THÔNG BÁO TỪ GIÁO VIÊN ===\n');
    for (var i = 0; i < selectedItems.length; i++) {
      final item = selectedItems[i];
      sb.writeln(
        '--- [${i + 1}/${selectedItems.length}] ${item.tenHocSinh} - Lớp ${item.tenLop} ---',
      );
      sb.writeln(_buildMessageForStudent(item));
      sb.writeln('\n');
    }

    Share.share(sb.toString(), subject: 'Thông báo lớp học');
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _selectedStudentIds.length;
    final totalCount = _allStudents.length;
    final allowedTypes = widget.allowedTypes ?? NotificationType.values;
    final String defaultTitle =
        allowedTypes.length == 1 &&
            allowedTypes.first == NotificationType.hocPhi
        ? 'Gửi Nhắc Học Phí Hàng Loạt'
        : 'Gửi Thông Báo Lớp Học';
    final String titleText = widget.dialogTitle ?? defaultTitle;
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
      backgroundColor: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.96,
        height: MediaQuery.of(context).size.height * 0.88,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header Dialog
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.send_rounded,
                    color: primaryColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    titleText,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Tab chọn loại thông báo (chỉ hiện nếu có nhiều hơn 1 loại được phép)
            if (allowedTypes.length > 1) ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (allowedTypes.contains(NotificationType.hocPhi)) ...[
                      _buildTypeChip(
                        NotificationType.hocPhi,
                        'Nhắc học phí',
                        Icons.payments_outlined,
                        Colors.amber.shade700,
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (allowedTypes.contains(NotificationType.baoNghiHoc)) ...[
                      _buildTypeChip(
                        NotificationType.baoNghiHoc,
                        'Báo nghỉ học',
                        Icons.event_busy_outlined,
                        Colors.redAccent,
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (allowedTypes.contains(NotificationType.baoDoiLich)) ...[
                      _buildTypeChip(
                        NotificationType.baoDoiLich,
                        'Báo đổi lịch',
                        Icons.edit_calendar_outlined,
                        Colors.blue,
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (allowedTypes.contains(NotificationType.custom))
                      _buildTypeChip(
                        NotificationType.custom,
                        'Tùy chỉnh',
                        Icons.edit_note_outlined,
                        Colors.teal,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Form cấu hình theo loại thông báo
            _buildNotificationForm(),
            const SizedBox(height: 12),

            // Bộ lọc Lớp & Trạng thái đóng tiền
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    value: _selectedLopId,
                    decoration: InputDecoration(
                      labelText: 'Lọc theo lớp',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      filled: true,
                      fillColor: theme.brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.grey.withValues(alpha: 0.08),
                      prefixIcon: const Icon(
                        Icons.filter_list_rounded,
                        size: 20,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.dividerColor.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text(
                          'Tất cả các lớp',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                      ..._danhSachLop.map(
                        (l) => DropdownMenuItem<int?>(
                          value: l.id,
                          child: Text(
                            l.ten,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedLopId = val;
                      });
                      _taiDanhSachHocSinh();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  avatar: Icon(
                    _onlyUnpaid
                        ? Icons.money_off_rounded
                        : Icons.people_outline_rounded,
                    size: 16,
                    color: _onlyUnpaid ? Colors.orange.shade700 : primaryColor,
                  ),
                  label: Text(
                    _onlyUnpaid ? 'Chỉ chưa đóng' : 'Tất cả HS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: _onlyUnpaid
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  selected: _onlyUnpaid,
                  onSelected: (val) {
                    setState(() {
                      _onlyUnpaid = val;
                    });
                    _taiDanhSachHocSinh();
                  },
                  selectedColor: primaryColor.withValues(alpha: 0.18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Chức năng Chọn tất cả / Bỏ chọn tất cả
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 14,
                          color: primaryColor,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Đã chọn $selectedCount/$totalCount phụ huynh',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedStudentIds = _allStudents
                          .map((e) => e.uniqueKey)
                          .toSet();
                    });
                  },
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  child: const Text(
                    'Chọn tất cả',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedStudentIds.clear();
                    });
                  },
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  child: const Text('Bỏ chọn', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // Danh sách học sinh & thao tác gửi
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _allStudents.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_search_outlined,
                            size: 48,
                            color: theme.hintColor.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Không tìm thấy học sinh phù hợp với bộ lọc.',
                            style: TextStyle(color: theme.hintColor),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _allStudents.length,
                      itemBuilder: (ctx, index) {
                        final item = _allStudents[index];
                        final isSelected = _selectedStudentIds.contains(
                          item.uniqueKey,
                        );
                        final message = _buildMessageForStudent(item);

                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 5),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? theme.cardColor
                                : theme.cardColor.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? primaryColor.withValues(alpha: 0.4)
                                  : theme.dividerColor.withValues(alpha: 0.15),
                              width: isSelected ? 1.5 : 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: primaryColor.withValues(
                                        alpha: 0.06,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    SizedBox(
                                      width: 28,
                                      height: 28,
                                      child: Checkbox(
                                        value: isSelected,
                                        activeColor: primaryColor,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        onChanged: (val) {
                                          setState(() {
                                            if (val == true) {
                                              _selectedStudentIds.add(
                                                item.uniqueKey,
                                              );
                                            } else {
                                              _selectedStudentIds.remove(
                                                item.uniqueKey,
                                              );
                                            }
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: item.isDaHoanThanh
                                              ? [
                                                  Colors.teal,
                                                  Colors.green.shade600,
                                                ]
                                              : [
                                                  Colors.indigo,
                                                  Colors.blue.shade600,
                                                ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        item.tenHocSinh.isNotEmpty
                                            ? item.tenHocSinh[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.tenHocSinh,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 1.5,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: primaryColor
                                                      .withValues(alpha: 0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  'Lớp ${item.tenLop}',
                                                  style: TextStyle(
                                                    color: primaryColor,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  item.sdt.isNotEmpty
                                                      ? item.sdt
                                                      : '(Chưa có SĐT)',
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: item.sdt.isNotEmpty
                                                        ? theme.hintColor
                                                        : Colors.amber.shade700,
                                                    fontSize: 11,
                                                    fontStyle: item.sdt.isEmpty
                                                        ? FontStyle.italic
                                                        : FontStyle.normal,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    if (item.isDaHoanThanh)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withValues(
                                            alpha: 0.15,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color: Colors.green.withValues(
                                              alpha: 0.3,
                                            ),
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.check_circle_rounded,
                                              size: 12,
                                              color: Colors.green,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Đã đóng',
                                              style: TextStyle(
                                                color: Colors.green,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    else
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withValues(
                                            alpha: 0.12,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color: Colors.red.withValues(
                                              alpha: 0.3,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          'Nợ ${NumberFormat('#,##0').format(item.soTienConNo)}đ',
                                          style: const TextStyle(
                                            color: Colors.redAccent,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                if (isSelected) ...[
                                  const SizedBox(height: 8),
                                  Divider(
                                    height: 1,
                                    color: theme.dividerColor.withValues(
                                      alpha: 0.15,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      // Nút Zalo
                                      ElevatedButton.icon(
                                        onPressed: () =>
                                            _moZalo(item.sdt, message),
                                        icon: const Icon(
                                          Icons.chat_bubble_rounded,
                                          size: 14,
                                        ),
                                        label: const Text(
                                          'Zalo',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF0068FF,
                                          ),
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          visualDensity: VisualDensity.compact,
                                          shape: const StadiumBorder(),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 4,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),

                                      // Nút SMS
                                      ElevatedButton.icon(
                                        onPressed: () =>
                                            _moSMS(item.sdt, message),
                                        icon: const Icon(
                                          Icons.sms_rounded,
                                          size: 14,
                                        ),
                                        label: const Text(
                                          'SMS',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.teal.shade600,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          visualDensity: VisualDensity.compact,
                                          shape: const StadiumBorder(),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 4,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),

                                      // Nút Copy
                                      OutlinedButton.icon(
                                        onPressed: () async {
                                          await Clipboard.setData(
                                            ClipboardData(text: message),
                                          );
                                          if (context.mounted) {
                                            ToastHelper.showSuccess(
                                              context,
                                              'Đã copy tin nhắn của ${item.tenHocSinh}!',
                                            );
                                          }
                                        },
                                        icon: const Icon(
                                          Icons.copy_rounded,
                                          size: 14,
                                        ),
                                        label: const Text(
                                          'Copy',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                          shape: const StadiumBorder(),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),

            // Bottom Actions
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _guiZaloHangLoat,
                      icon: const Icon(Icons.chat_bubble_rounded, size: 18),
                      label: Text(
                        'Gửi Zalo ($selectedCount PH)',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0068FF),
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _chiaSeHangLoat,
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: const Text(
                        'Chia sẻ tất cả',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip(
    NotificationType type,
    String label,
    IconData icon,
    Color activeColor,
  ) {
    final bool isSelected = _selectedType == type;
    final theme = Theme.of(context);

    return InkWell(
      onTap: () {
        setState(() {
          _selectedType = type;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.18)
              : theme.brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.grey.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? activeColor
                : theme.dividerColor.withValues(alpha: 0.2),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? activeColor : theme.hintColor,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? activeColor
                    : theme.textTheme.bodyMedium?.color,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationForm() {
    final theme = Theme.of(context);
    final inputDecoration = InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      filled: true,
      fillColor: theme.brightness == Brightness.dark
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.grey.withValues(alpha: 0.08),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: theme.dividerColor.withValues(alpha: 0.15),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.primaryColor, width: 1.5),
      ),
    );

    switch (_selectedType) {
      case NotificationType.hocPhi:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.amber.shade700.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.auto_awesome,
                  color: Colors.amber.shade700,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tin nhắn nhắc nợ học phí tự động chèn Tên HS, Lớp, Số tiền nợ, Số buổi dư và cú pháp CK VietQR ngân hàng.',
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.3),
                ),
              ),
            ],
          ),
        );

      case NotificationType.baoNghiHoc:
        return Column(
          children: [
            TextField(
              controller: _ngayNghiController,
              style: const TextStyle(fontSize: 13),
              decoration: inputDecoration.copyWith(
                labelText: 'Thời gian nghỉ',
                prefixIcon: const Icon(Icons.event_available_rounded, size: 18),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _lyDoNghiController,
              style: const TextStyle(fontSize: 13),
              decoration: inputDecoration.copyWith(
                labelText: 'Lý do nghỉ',
                prefixIcon: const Icon(Icons.info_outline_rounded, size: 18),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _danDoNghiController,
              style: const TextStyle(fontSize: 13),
              maxLines: 2,
              decoration: inputDecoration.copyWith(
                labelText: 'Dặn dò bài tập / Lịch học lại',
                prefixIcon: const Icon(Icons.assignment_outlined, size: 18),
              ),
            ),
          ],
        );

      case NotificationType.baoDoiLich:
        return Column(
          children: [
            TextField(
              controller: _buoiCuController,
              style: const TextStyle(fontSize: 13),
              decoration: inputDecoration.copyWith(
                labelText: 'Buổi học cũ',
                prefixIcon: const Icon(
                  Icons.history_toggle_off_rounded,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _buoiMoiController,
              style: const TextStyle(fontSize: 13),
              decoration: inputDecoration.copyWith(
                labelText: 'Lịch mới (thay thế)',
                prefixIcon: const Icon(Icons.update_rounded, size: 18),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _ghiChuDoiLichController,
              style: const TextStyle(fontSize: 13),
              decoration: inputDecoration.copyWith(
                labelText: 'Ghi chú thêm',
                prefixIcon: const Icon(Icons.edit_note_rounded, size: 18),
              ),
            ),
          ],
        );

      case NotificationType.custom:
        return Column(
          children: [
            TextField(
              controller: _tieuDeCustomController,
              style: const TextStyle(fontSize: 13),
              decoration: inputDecoration.copyWith(
                labelText: 'Tiêu đề thông báo',
                prefixIcon: const Icon(Icons.title_rounded, size: 18),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noiDungCustomController,
              style: const TextStyle(fontSize: 13),
              maxLines: 3,
              decoration: inputDecoration.copyWith(
                labelText: 'Nội dung thông báo',
                prefixIcon: const Icon(Icons.notes_rounded, size: 18),
              ),
            ),
          ],
        );
    }
  }
}

class _StudentNotifyItem {
  final int id;
  final int idLop;
  final String tenHocSinh;
  final String tenLop;
  final String sdt;
  final int soBuoiDu;
  final int tongSoBuoi;
  final int soTienCanNop;
  final int soTienDaDong;
  final int soTienConNo;
  final bool isDaHoanThanh;

  _StudentNotifyItem({
    required this.id,
    required this.idLop,
    required this.tenHocSinh,
    required this.tenLop,
    required this.sdt,
    required this.soBuoiDu,
    required this.tongSoBuoi,
    required this.soTienCanNop,
    required this.soTienDaDong,
    required this.soTienConNo,
    required this.isDaHoanThanh,
  });

  String get uniqueKey => '${id}_$idLop';
}
