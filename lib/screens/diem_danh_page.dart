import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
// Import các Models và Services cần thiết (Giả định chúng đã tồn tại trong project)
import '../controllers/diem_danh_controller.dart';
import '../controllers/service_providers.dart';
import '../models/diem_danh.dart';
import '../models/lop.dart'; // Cần Lop model
import '../models/lich_hoc.dart'; // Cần LichHoc model
import '../models/hs_lop_view_model.dart'; // Cần HSLopViewModel
import 'su_kien_buoi_hoc_page.dart';
import 'post_session_review_page.dart';
import '../l10n/app_localizations.dart';
import '../widgets/dang_ky_nghi_le_dialog.dart';
import '../widgets/preview_diem_danh_bu_dialog.dart';
import '../utils/db.dart';
import '../utils/attendance_calculator.dart';
import '../services/session_ledger_service.dart';
import '../services/zalo_contact_service.dart';
import '../widgets/attendance_correction_dialogs.dart';
import '../widgets/xuat_bao_cao_pdf_dialog.dart';
import '../models/report_models.dart';

class DiemDanhPage extends ConsumerStatefulWidget {
  final int? selectedLopId;
  final DateTime? selectedDate;
  final int? selectedScheduleId;

  const DiemDanhPage({
    super.key,
    this.selectedLopId,
    this.selectedDate,
    this.selectedScheduleId,
  });

  @override
  ConsumerState<DiemDanhPage> createState() => _DiemDanhPageState();
}

// SỬA: Chuyển sang ConsumerStatefulWidget
class _DiemDanhPageState extends ConsumerState<DiemDanhPage> {
  // --- Định nghĩa màu sắc cho Dark Mode nhất quán ---
  Color get darkBackground => Theme.of(context).scaffoldBackgroundColor;
  Color get cardColor => Theme.of(context).cardColor;
  Color get lightText =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
  Color get secondaryText =>
      Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white70;
  Color get accentColor => Theme.of(context).primaryColor;
  Color get presentColor =>
      Colors.greenAccent; // Giữ màu xanh lá sáng cho Có mặt
  Color get absentColor => Theme.of(context).colorScheme.error;
  Color get makeUpColor => Colors.lightBlueAccent;
  // --------------------------------------------------

  void _showInfoDialog(String title, String message, {Color? titleColor}) {
    final effectiveTitleColor = titleColor ?? accentColor;
    final isVi = AppLocalizations.of(context)?.locale.languageCode == 'vi';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        title: Text(
          title,
          style: TextStyle(
            color: effectiveTitleColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(message, style: TextStyle(color: lightText)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              isVi ? 'Đóng' : 'Close',
              style: TextStyle(color: secondaryText),
            ),
          ),
        ],
      ),
    );
  }

  // 3. Xử lý chọn ngày
  Future<void> _chonNgay() async {
    // SỬA: Lấy ngày hiện tại từ state của provider
    final currentState = ref
        .read(
          diemDanhControllerProvider(widget.selectedLopId, widget.selectedDate),
        )
        .value;
    if (currentState == null) return; // Không làm gì nếu state chưa sẵn sàng

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: currentState.selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(
            primary: accentColor,
            onSurface: lightText,
            surface: cardColor,
          ),
          dialogTheme: DialogThemeData(backgroundColor: darkBackground),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      final notifier = ref.read(
        diemDanhControllerProvider(
          widget.selectedLopId,
          widget.selectedDate,
        ).notifier,
      );
      notifier.changeSelection(null, picked);
    }
  }

  // HÀM MỚI: Điểm danh bù cho các ngày đã quên
  Future<void> _diemDanhBu() async {
    // SỬA: Logic này phức tạp và liên quan đến nhiều ngày,
    // nên giữ lại trong UI hoặc chuyển vào một service riêng.
    // Hiện tại, giữ nguyên để đảm bảo chức năng.
    // TODO: Consider moving this logic to a service.
    final selectedLop = ref
        .read(
          diemDanhControllerProvider(widget.selectedLopId, widget.selectedDate),
        )
        .value
        ?.selectedLop;
    if (selectedLop == null) return;

    final isVi = AppLocalizations.of(context)?.locale.languageCode == 'vi';

    // 1. Hỏi xác nhận
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        title: Text(
          isVi ? 'Xác nhận Điểm danh bù' : 'Confirm Makeup Attendance',
          style: TextStyle(color: lightText),
        ),
        content: Text(
          isVi
              ? 'Hệ thống sẽ tự động điền "Có mặt" cho tất cả các buổi học đã qua trong tháng này mà học sinh chưa có dữ liệu điểm danh. Các buổi đã điểm danh (vắng hoặc có mặt) sẽ không bị thay đổi.\n\nBạn có muốn tiếp tục không?'
              : 'The system will automatically mark "Present" for all past sessions this month that lack attendance data. Existing attendance records (absent or present) will not be modified.\n\nDo you want to continue?',
          style: TextStyle(color: secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              isVi ? 'Hủy' : 'Cancel',
              style: TextStyle(color: secondaryText),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: accentColor),
            child: Text(
              isVi ? 'Đồng ý' : 'Agree',
              style: TextStyle(color: lightText),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;
    // Hiển thị loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        backgroundColor: cardColor,
        content: Row(
          children: [
            CircularProgressIndicator(color: accentColor),
            const SizedBox(width: 10),
            Text(
              isVi ? 'Đang xử lý...' : 'Processing...',
              style: TextStyle(color: lightText),
            ),
          ],
        ),
      ),
    );

    try {
      // 2. Lấy thông tin tháng và lớp dựa trên ngày đang chọn trên giao diện
      final currentState = ref
          .read(
            diemDanhControllerProvider(
              widget.selectedLopId,
              widget.selectedDate,
            ),
          )
          .value;
      final targetDate = currentState?.selectedDate ?? DateTime.now();

      final firstDayOfMonth = DateTime(targetDate.year, targetDate.month, 1);
      final now = DateTime.now();

      DateTime endDay;
      if (targetDate.year == now.year && targetDate.month == now.month) {
        // Nếu là tháng hiện tại, chỉ điểm danh đến hôm qua (không điểm danh đè hôm nay)
        endDay = DateTime(now.year, now.month, now.day);
      } else {
        // Nếu là tháng trong quá khứ, chạy hết toàn bộ tháng đó
        endDay = DateTime(targetDate.year, targetDate.month + 1, 1);
      }

      final allLichHoc = await ref
          .read(lichHocServiceProvider)
          .layLichHocTheoLop(selectedLop.id!);
      // Không cần lấy allHocSinh nữa vì sẽ lấy theo từng ca

      if (allLichHoc.isEmpty) {
        if (mounted) Navigator.of(context).pop(); // Đóng loading
        if (mounted) {
          _showInfoDialog(
            isVi ? 'Thông báo' : 'Notification',
            isVi
                ? 'Lớp này chưa được thiết lập lịch học.'
                : 'This class has no schedule set up.',
            titleColor: Colors.orangeAccent,
          );
        }
        return;
      }

      // 3. Lấy thông tin đơn nghỉ học của lớp để lọc ngày nghỉ lễ toàn lớp
      final db = await DBHelper.instance.database;
      final donNghiRows = await db.query(
        DBHelper.tenBangDonNghiHoc,
        where: 'id_lop = ?',
        whereArgs: [selectedLop.id!],
      );

      final Set<String> classHolidayDates = {};
      for (var row in donNghiRows) {
        final loaiNghi = row['loai_nghi'] as String? ?? 'CANHAN';
        if (loaiNghi == 'TOANLOP') {
          final tuStr = row['tu_ngay'] as String?;
          final denStr = row['den_ngay'] as String?;
          if (tuStr != null && denStr != null) {
            final tuDt = DateTime.tryParse(tuStr);
            final denDt = DateTime.tryParse(denStr);
            if (tuDt != null && denDt != null) {
              DateTime cur = tuDt;
              while (!cur.isAfter(denDt)) {
                classHolidayDates.add(DateFormat('yyyy-MM-dd').format(cur));
                cur = cur.add(const Duration(days: 1));
              }
            }
          }
        }
      }

      // 4. Lấy tất cả điểm danh hiện có trong tháng của lớp
      final firstDayStr = DateFormat('yyyy-MM-dd').format(firstDayOfMonth);
      final lastDayStr = DateFormat('yyyy-MM-dd').format(endDay);
      final existingAttRows = await db.query(
        DBHelper.tenBangDiemDanh,
        where: 'id_lop = ? AND gio_diem_danh >= ? AND gio_diem_danh < ?',
        whereArgs: [
          selectedLop.id!,
          '$firstDayStr 00:00:00',
          '$lastDayStr 00:00:00',
        ],
      );

      final Set<String> existingAttKeys = {};
      for (var row in existingAttRows) {
        final hsId = row['id_hoc_sinh'];
        final gio = row['gio_diem_danh'] as String?;
        if (hsId != null && gio != null) {
          final parts = gio.trim().split(' ');
          final dateStr = parts[0];
          final timeStr = parts.length > 1 ? parts[1].substring(0, 5) : '00:00';
          existingAttKeys.add('${hsId}_${selectedLop.id}_${dateStr}_$timeStr');
        }
      }

      int totalScheduled = 0;
      int holidayCount = 0;
      int existingCount = 0;
      int outsideParticipationCount = 0;
      int insertCount = 0;
      final previewItems = <SessionPreviewItem>[];
      final pendingInserts = <Map<String, dynamic>>[];

      for (
        var day = firstDayOfMonth;
        day.isBefore(endDay);
        day = day.add(const Duration(days: 1))
      ) {
        final dateStr = DateFormat('yyyy-MM-dd').format(day);
        final int thuTrongTuanDB = (day.weekday == 7) ? 1 : day.weekday + 1;
        final dowText = SessionLedgerService.getDayOfWeekText(day);

        final caHocTrongNgay = allLichHoc
            .where((lh) => lh.thuTrongTuan == thuTrongTuanDB)
            .toList();
        if (caHocTrongNgay.isEmpty) continue;

        final isHoliday = classHolidayDates.contains(dateStr);
        totalScheduled += caHocTrongNgay.length;

        if (isHoliday) {
          holidayCount += caHocTrongNgay.length;
          for (var caHoc in caHocTrongNgay) {
            previewItems.add(
              SessionPreviewItem(
                dateStr: DateFormat('dd/MM/yyyy').format(day),
                dayOfWeek: dowText,
                timeSlot: '${caHoc.gioBatDau} - ${caHoc.gioKetThuc}',
                action: 'SKIP',
                reason: 'Nghỉ lễ toàn lớp (Lớp không tổ chức ca học)',
                hsCount: 0,
              ),
            );
          }
          continue;
        }

        for (var caHoc in caHocTrongNgay) {
          final hsCuaCa = await ref
              .read(lopHocSinhServiceProvider)
              .docDSHSTheoCaHoc(caHoc.id!);
          final targetTime = caHoc.gioBatDau.length >= 5
              ? caHoc.gioBatDau.substring(0, 5)
              : caHoc.gioBatDau;

          final activeHs = <HSLopViewModel>[];
          for (var hs in hsCuaCa) {
            final inWindow = AttendanceCalculator.isDateInParticipationWindow(
              date: day,
              ngayThamGia: AttendanceCalculator.parseDateSafely(hs.ngayThamGia),
              ngayTamNgung: AttendanceCalculator.parseDateSafely(
                hs.ngayTamNgung,
              ),
              ngayHocLai: AttendanceCalculator.parseDateSafely(
                hs.ngayHocLaiThucTe ?? hs.ngayDuKienHocLai,
              ),
              ngayNghiHoc: AttendanceCalculator.parseDateSafely(hs.ngayNghiHoc),
              ngayHocLaiSauNghi: AttendanceCalculator.parseDateSafely(
                hs.ngayHocLaiSauNghi,
              ),
            );
            if (inWindow) {
              activeHs.add(hs);
            } else {
              outsideParticipationCount++;
            }
          }

          if (activeHs.isEmpty) {
            if (hsCuaCa.isNotEmpty) {
              previewItems.add(
                SessionPreviewItem(
                  dateStr: DateFormat('dd/MM/yyyy').format(day),
                  dayOfWeek: dowText,
                  timeSlot: '${caHoc.gioBatDau} - ${caHoc.gioKetThuc}',
                  action: 'SKIP',
                  reason: 'HS chưa/không tham gia thời gian này',
                  hsCount: hsCuaCa.length,
                ),
              );
            }
            continue;
          }

          final hsToInsert = <HSLopViewModel>[];
          int keepCount = 0;

          for (var hs in activeHs) {
            final key = '${hs.id}_${selectedLop.id}_${dateStr}_$targetTime';
            if (existingAttKeys.contains(key)) {
              keepCount++;
            } else {
              hsToInsert.add(hs);
            }
          }

          existingCount += keepCount;
          insertCount += hsToInsert.length;

          if (hsToInsert.isNotEmpty) {
            pendingInserts.add({
              'hsList': hsToInsert,
              'caHoc': caHoc,
              'day': day,
            });
            previewItems.add(
              SessionPreviewItem(
                dateStr: DateFormat('dd/MM/yyyy').format(day),
                dayOfWeek: dowText,
                timeSlot: '${caHoc.gioBatDau} - ${caHoc.gioKetThuc}',
                action: 'INSERT',
                reason:
                    'Thiếu dữ liệu điểm danh -> Sẽ bổ sung Có mặt (${hsToInsert.length} học sinh)',
                hsCount: hsToInsert.length,
              ),
            );
          } else if (keepCount > 0) {
            previewItems.add(
              SessionPreviewItem(
                dateStr: DateFormat('dd/MM/yyyy').format(day),
                dayOfWeek: dowText,
                timeSlot: '${caHoc.gioBatDau} - ${caHoc.gioKetThuc}',
                action: 'KEEP',
                reason: 'Đã có đầy đủ bản ghi điểm danh ca này',
                hsCount: keepCount,
              ),
            );
          }
        }
      }

      if (mounted) Navigator.of(context).pop(); // Đóng loading quét dữ liệu

      if (mounted) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => PreviewDiemDanhBuDialog(
            tenLop: selectedLop.ten,
            thangStr: DateFormat('MM/yyyy').format(targetDate),
            totalScheduled: totalScheduled,
            holidayCount: holidayCount,
            existingCount: existingCount,
            outsideParticipationCount: outsideParticipationCount,
            insertCount: insertCount,
            sessions: previewItems,
          ),
        );

        if (confirm == true && pendingInserts.isNotEmpty && mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => const Center(child: CircularProgressIndicator()),
          );

          for (var item in pendingInserts) {
            await ref.read(diemDanhServiceProvider).diemDanhCoMatHangLoat(
              item['hsList'] as List<HSLopViewModel>,
              [item['caHoc'] as LichHoc],
              item['day'] as DateTime,
            );
          }

          if (mounted) Navigator.of(context).pop(); // Đóng loading chèn dữ liệu
          if (mounted) {
            _showInfoDialog(
              isVi ? 'Thành công' : 'Success',
              isVi
                  ? 'Đã hoàn tất bổ sung điểm danh Có mặt cho $insertCount bản ghi còn thiếu!'
                  : 'Makeup attendance completed for $insertCount empty records!',
            );
          }
        }
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop(); // Đóng loading
      if (mounted) {
        final isVi = AppLocalizations.of(context)?.locale.languageCode == 'vi';
        _showInfoDialog(
          isVi ? 'Lỗi' : 'Error',
          isVi ? 'Đã có lỗi xảy ra: $e' : 'An error occurred: $e',
          titleColor: absentColor,
        );
      }
    } finally {
      // SỬA: Tải lại dữ liệu sau khi điểm danh bù, bất kể thành công hay thất bại
      ref.invalidate(
        diemDanhControllerProvider(widget.selectedLopId, widget.selectedDate),
      );
    }
  }

  // HÀM MỚI: Mở trang nhật ký buổi học
  Future<void> _moTrangSuKien(DiemDanh record, String tenHS) async {
    int? idDiemDanh = record.id;

    // Nếu chưa có ID (chưa lưu vào DB), thực hiện lưu nhanh trước khi chuyển trang
    if (idDiemDanh == null) {
      idDiemDanh = await ref.read(diemDanhServiceProvider).themDiemDanh(record);
      // Cập nhật lại ID vào record trong state để không bị lưu trùng
      record.id = idDiemDanh;
    }

    if (mounted && idDiemDanh > 0) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) =>
              SuKienBuoiHocPage(idDiemDanh: idDiemDanh!, tenHocSinh: tenHS),
        ),
      );
    }
  }

  // SỬA: Widget hiển thị hàng điểm danh cho một học sinh
  Widget _buildDiemDanhRow(
    HSLopViewModel hs,
    LichHoc caHoc,
    DiemDanhState data,
  ) {
    // Lấy danh sách các key cho học sinh này
    final key = '${hs.id}-${caHoc.id}';
    final currentRecord = data.trangThaiDiemDanh[key]!;
    final isPresent = currentRecord.trangThai == 'Có mặt';
    final isVi = AppLocalizations.of(context)?.locale.languageCode == 'vi';

    return Card(
      // SỬA: Thêm InkWell để có thể nhấn vào card
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
        side: BorderSide(
          color: isPresent
              ? accentColor.withValues(alpha: 0.5)
              : Colors.transparent,
          width: 1,
        ),
      ),
      color: darkBackground,
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isPresent
                      ? presentColor.withValues(alpha: 0.3)
                      : (currentRecord.trangThai == 'Học bù'
                            ? makeUpColor.withValues(alpha: 0.3)
                            : absentColor.withValues(alpha: 0.3)),
                  child: Icon(
                    isPresent
                        ? Icons.check
                        : (currentRecord.trangThai == 'Học bù'
                              ? Icons.school_outlined
                              : Icons.close),
                    color: isPresent
                        ? presentColor
                        : (currentRecord.trangThai == 'Học bù'
                              ? makeUpColor
                              : absentColor),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // SỬA: Bọc tên và cảnh báo trong một Row
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              hs.ten,
                              style: TextStyle(
                                color: lightText,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // SỬA: Hiển thị icon cảnh báo nếu có
                          if (data.studentsWithWarnings.contains(hs.id))
                            const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.orangeAccent,
                                size: 18,
                              ),
                            ),
                        ],
                      ),
                      if (hs.sdt != null && hs.sdt!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2.0),
                          child: Text(
                            hs.sdt!,
                            style: TextStyle(
                              color: secondaryText,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // NÚT MỚI: Nhật ký buổi học (Chỉ hiện khi Có mặt)
                if (isPresent)
                  IconButton(
                    icon: const Icon(
                      Icons.history_edu,
                      color: Colors.blueAccent,
                    ),
                    tooltip: isVi ? 'Nhật ký buổi học' : 'Session log',
                    onPressed: () => _moTrangSuKien(currentRecord, hs.ten),
                  ),
                ZaloContactService.instance.buildZaloQuickButton(context, hs),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white70),
                  tooltip: 'Tùy chọn học sinh',
                  onSelected: (val) async {
                    final provider = diemDanhControllerProvider(
                      widget.selectedLopId,
                      widget.selectedDate,
                    );
                    if (val == 'edit_status') {
                      if (currentRecord.id != null) {
                        await AttendanceCorrectionDialogs.showEditStatusDialog(
                          context: context,
                          attendanceId: currentRecord.id!,
                          studentName: hs.ten,
                          currentStatus: currentRecord.trangThai,
                          onRefreshed: () => ref.invalidate(provider),
                        );
                      }
                    } else if (val == 'edit_comment') {
                      _moTrangSuKien(currentRecord, hs.ten);
                    } else if (val == 'remove_student') {
                      if (currentRecord.id != null) {
                        await AttendanceCorrectionDialogs.showRemoveStudentDialog(
                          context: context,
                          attendanceId: currentRecord.id!,
                          studentName: hs.ten,
                          sessionDateStr: DateFormat(
                            'yyyy-MM-dd',
                          ).format(data.selectedDate),
                          onRefreshed: () => ref.invalidate(provider),
                        );
                      }
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'edit_status',
                      child: Row(
                        children: [
                          Icon(
                            Icons.edit_outlined,
                            size: 20,
                            color: Colors.white,
                          ),
                          SizedBox(width: 8),
                          Text('Sửa trạng thái'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit_comment',
                      child: Row(
                        children: [
                          Icon(
                            Icons.rate_review_outlined,
                            size: 20,
                            color: Colors.white,
                          ),
                          SizedBox(width: 8),
                          Text('Sửa nhận xét / Nhật ký'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'remove_student',
                      child: Row(
                        children: [
                          Icon(
                            Icons.person_remove_outlined,
                            size: 20,
                            color: Colors.redAccent,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Xóa khỏi buổi',
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                // Nút Checkbox lớn, dễ bấm
                Transform.scale(
                  scale: 1.3,
                  child: Checkbox(
                    value: isPresent,
                    onChanged: (bool? value) {
                      final newStatus = (value == true)
                          ? 'Có mặt'
                          : 'Nghỉ không phép';
                      ref
                          .read(
                            diemDanhControllerProvider(
                              widget.selectedLopId,
                              widget.selectedDate,
                            ).notifier,
                          )
                          .updateAttendanceStatus(key, newStatus);
                    },
                    activeColor: presentColor,
                    checkColor: darkBackground,
                    side: BorderSide(
                      color: secondaryText.withValues(alpha: 0.7),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
            // Vùng tùy chọn khi vắng
            if (!isPresent)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: _buildAbsenceOptions(currentRecord, caHoc, hs.ten),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // SỬA: Lắng nghe provider
    final provider = diemDanhControllerProvider(
      widget.selectedLopId,
      widget.selectedDate,
    );
    final diemDanhAsync = ref.watch(provider);
    final isVi = AppLocalizations.of(context)?.locale.languageCode == 'vi';

    return Scaffold(
      backgroundColor: darkBackground,
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          isVi ? 'ĐIỂM DANH THEO CA HỌC' : 'ATTENDANCE BY SESSION',
          style: TextStyle(color: lightText, fontSize: 18),
        ),
        backgroundColor: cardColor,
        foregroundColor: lightText,
        actions: [
          // Nút Đăng ký nghỉ lễ / nghỉ hè hàng loạt
          IconButton(
            icon: const Icon(Icons.beach_access_rounded),
            tooltip: isVi
                ? 'Đăng ký nghỉ lễ / nghỉ hè hàng loạt'
                : 'Batch holiday / vacation leave',
            color: Colors.orangeAccent,
            onPressed: () async {
              final provider = diemDanhControllerProvider(
                widget.selectedLopId,
                widget.selectedDate,
              );
              final currentState = ref.read(provider).value;
              if (currentState != null && currentState.selectedLop != null) {
                final dsHS = await ref
                    .read(lopHocSinhServiceProvider)
                    .docDSHSThuocLop(currentState.selectedLop!.id!);
                if (!mounted) return;
                final res = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => DangKyNghiLeDialog(
                    lop: currentState.selectedLop!,
                    danhSachHocSinh: dsHS,
                  ),
                );
                if (res == true) {
                  ref.invalidate(provider);
                }
              }
            },
          ),
          // HÀM MỚI: Nút điểm danh bù
          IconButton(
            icon: const Icon(Icons.event_repeat_outlined),
            tooltip: isVi
                ? 'Điểm danh bù các ngày đã quên'
                : 'Makeup attendance for missed days',
            onPressed: _diemDanhBu,
            color: accentColor,
          ),
          // QUẢN LÝ BUỔI HỌC (Sửa thông tin cả buổi / Hủy buổi / Khôi phục)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            tooltip: 'Quản lý buổi học',
            onSelected: (val) async {
              final provider = diemDanhControllerProvider(
                widget.selectedLopId,
                widget.selectedDate,
              );
              final currentState = ref.read(provider).value;
              if (currentState?.selectedLop == null) return;

              final classId = currentState!.selectedLop!.id!;
              final dateStr = DateFormat(
                'yyyy-MM-dd',
              ).format(currentState.selectedDate);

              if (val == 'edit_session') {
                await AttendanceCorrectionDialogs.showEditSessionDialog(
                  context: context,
                  classId: classId,
                  currentDateStr: dateStr,
                  onRefreshed: () => ref.invalidate(provider),
                );
              } else if (val == 'cancel_session') {
                await AttendanceCorrectionDialogs.showCancelSessionDialog(
                  context: context,
                  classId: classId,
                  sessionDateStr: dateStr,
                  className: currentState.selectedLop!.ten,
                  onRefreshed: () => ref.invalidate(provider),
                );
              } else if (val == 'restore_session') {
                await AttendanceCorrectionDialogs.showRestoreSessionDialog(
                  context: context,
                  classId: classId,
                  sessionDateStr: dateStr,
                  onRefreshed: () => ref.invalidate(provider),
                );
              } else if (val == 'export_pdf') {
                showDialog(
                  context: context,
                  builder: (ctx) => XuatBaoCaoPdfDialog(
                    initialLop: currentState.selectedLop,
                    initialSections: const {
                      ReportSection.classSummary,
                      ReportSection.attendance,
                    },
                  ),
                );
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'edit_session',
                child: Row(
                  children: [
                    Icon(Icons.edit_calendar, size: 20, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Sửa thông tin buổi học'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'cancel_session',
                child: Row(
                  children: [
                    Icon(Icons.block, size: 20, color: Colors.redAccent),
                    SizedBox(width: 8),
                    Text(
                      'Hủy buổi điểm danh',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'restore_session',
                child: Row(
                  children: [
                    Icon(
                      Icons.restore_page,
                      size: 20,
                      color: Colors.greenAccent,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Khôi phục buổi học',
                      style: TextStyle(color: Colors.greenAccent),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export_pdf',
                child: Row(
                  children: [
                    Icon(
                      Icons.picture_as_pdf,
                      size: 20,
                      color: Colors.blueAccent,
                    ),
                    SizedBox(width: 8),
                    Text('Xuất báo cáo PDF'),
                  ],
                ),
              ),
            ],
          ),
        ],
        elevation: 0,
      ),
      body: Column(
        children: [
          // SỬA: Hiển thị header chỉ khi có dữ liệu
          if (diemDanhAsync is AsyncData<DiemDanhState>)
            _buildHeader(diemDanhAsync.value),

          Expanded(
            // SỬA: Dùng when để xử lý các trạng thái
            child: diemDanhAsync.when(
              loading: () =>
                  Center(child: CircularProgressIndicator(color: accentColor)),
              error: (err, stack) => Center(
                child: Text(
                  isVi ? 'Lỗi: $err' : 'Error: $err',
                  style: TextStyle(color: absentColor),
                ),
              ),
              data: (data) {
                if (data.caHocTrongNgay.isEmpty) {
                  return Center(
                    child: Text(
                      isVi
                          ? 'Lớp không có ca học nào trong ngày này.'
                          : 'There are no sessions for this class on this day.',
                      style: TextStyle(color: secondaryText),
                    ),
                  );
                }
                return _buildCaHocList(data);
              },
            ),
          ),
        ],
      ),
    );
  }

  // SỬA: Widget hiển thị tùy chọn khi vắng mặt
  Widget _buildHeader(DiemDanhState data) {
    final notifier = ref.read(
      diemDanhControllerProvider(
        widget.selectedLopId,
        widget.selectedDate,
      ).notifier,
    );
    final isVi = AppLocalizations.of(context)?.locale.languageCode == 'vi';

    return Container(
      color: cardColor,
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Row(
            children: [
              // Dropdown Chọn Lớp
              Expanded(
                child: DropdownButtonFormField<Lop>(
                  decoration: InputDecoration(
                    labelText: isVi ? 'Chọn Lớp' : 'Select Class',
                    labelStyle: TextStyle(color: secondaryText),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: secondaryText.withValues(alpha: 0.5),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: accentColor),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    fillColor: darkBackground,
                    filled: true,
                  ),
                  initialValue: data.selectedLop,
                  dropdownColor: cardColor,
                  style: TextStyle(color: lightText),
                  items: data.lopList
                      .map(
                        (lop) => DropdownMenuItem<Lop>(
                          value: lop,
                          child: Text(
                            lop.ten,
                            style: TextStyle(color: lightText),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (Lop? newValue) {
                    notifier.changeSelection(newValue, null);
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Nút Chọn Ngày
              GestureDetector(
                onTap: _chonNgay,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: darkBackground,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: secondaryText.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: accentColor, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('dd/MM/yyyy').format(data.selectedDate),
                        style: TextStyle(
                          color: lightText,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Nút Lưu
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              // SỬA: Gọi hàm saveAllChanges từ notifier
              onPressed: data.trangThaiDiemDanh.isEmpty
                  ? null
                  : () async {
                      // SỬA: Thêm try-catch và thông báo thành công/thất bại
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: cardColor,
                          content: Row(
                            children: [
                              CircularProgressIndicator(color: accentColor),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  isVi ? 'Đang lưu...' : 'Saving...',
                                  style: TextStyle(color: lightText),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                      try {
                        await notifier.saveAllChanges();
                        if (!mounted) return;
                        Navigator.of(context).pop(); // Đóng loading
                        _showInfoDialog(
                          isVi ? 'Thành công' : 'Success',
                          isVi
                              ? 'Đã lưu điểm danh thành công!'
                              : 'Attendance saved successfully!',
                        );
                      } catch (e) {
                        if (!mounted) return;
                        Navigator.of(context).pop(); // Đóng loading
                        _showInfoDialog(
                          isVi ? 'Lỗi' : 'Error',
                          (isVi ? 'Lỗi khi lưu: ' : 'Error saving: ') +
                              e.toString(),
                          titleColor: absentColor,
                        );
                      }
                    },
              icon: const Icon(Icons.save, size: 18),
              label: Text(isVi ? 'Lưu Tất Cả Thay Đổi' : 'Save All Changes'),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: darkBackground,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // HÀM MỚI: Tính số lượng đếm trạng thái cho từng ca học
  Map<String, int> _computeCaCounters(
    List<HSLopViewModel> hsCuaCa,
    LichHoc caHoc,
    DiemDanhState data,
  ) {
    int coMat = 0;
    int cp = 0;
    int kp = 0;
    int hocBu = 0;
    int chuaDd = 0;

    for (var hs in hsCuaCa) {
      final key = '${hs.id}-${caHoc.id}';
      final record = data.trangThaiDiemDanh[key];
      final status = SessionLedgerService.normalizeStatus(record?.trangThai);

      switch (status) {
        case 'CO_MAT':
        case 'TRE':
          coMat++;
          break;
        case 'VANG_CO_PHEP':
          cp++;
          break;
        case 'VANG_KHONG_PHEP':
          kp++;
          break;
        case 'HOC_BU':
          hocBu++;
          break;
        case 'NO_RECORD':
        default:
          chuaDd++;
          break;
      }
    }

    return {
      'coMat': coMat,
      'cp': cp,
      'kp': kp,
      'hocBu': hocBu,
      'chuaDd': chuaDd,
    };
  }

  // SỬA: Widget hiển thị danh sách các ca học dưới dạng ExpansionTile
  Widget _buildCaHocList(DiemDanhState data) {
    final notifier = ref.read(
      diemDanhControllerProvider(
        widget.selectedLopId,
        widget.selectedDate,
      ).notifier,
    );
    final isVi = AppLocalizations.of(context)?.locale.languageCode == 'vi';

    return ListView.builder(
      itemCount: data.caHocTrongNgay.length,
      itemBuilder: (context, index) {
        final caHoc = data.caHocTrongNgay[index];
        final hsCuaCa = data.danhSachHSCuaTungCa[caHoc.id!] ?? [];
        final isSelectedCa =
            widget.selectedScheduleId != null &&
            caHoc.id == widget.selectedScheduleId;
        final counters = _computeCaCounters(hsCuaCa, caHoc, data);

        return Card(
          color: cardColor,
          elevation: isSelectedCa ? 4 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: isSelectedCa ? accentColor : Colors.transparent,
              width: isSelectedCa ? 2 : 0,
            ),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ExpansionTile(
            key: PageStorageKey('caHoc_${caHoc.id}'),
            initiallyExpanded: widget.selectedScheduleId != null
                ? isSelectedCa
                : true,
            title: Row(
              children: [
                Text(
                  'Ca ${caHoc.gioBatDau.substring(0, 5)} - ${caHoc.gioKetThuc.substring(0, 5)}',
                  style: TextStyle(
                    color: lightText,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isSelectedCa) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accentColor, width: 1),
                    ),
                    child: Text(
                      isVi ? 'CA CHỌN' : 'FOCUSED',
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Text(
              'Có mặt: ${counters['coMat']} | CP: ${counters['cp']} | KP: ${counters['kp']} | Học bù: ${counters['hocBu']} | Chưa DD: ${counters['chuaDd']}',
              style: TextStyle(color: secondaryText, fontSize: 12),
            ),
            leading: IconButton(
              icon: Icon(Icons.check_circle_outline, color: presentColor),
              tooltip: isVi
                  ? 'Điểm danh "Có mặt" tất cả ca này'
                  : 'Mark all present for this session',
              onPressed: () => notifier.markAllPresent(caHoc),
            ),
            children: hsCuaCa.isEmpty
                ? [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        isVi
                            ? 'Không có học sinh nào được gán cho ca này.'
                            : 'No students assigned to this session.',
                        style: TextStyle(color: secondaryText),
                      ),
                    ),
                  ]
                : [
                    _buildQuickActionsBar(caHoc, hsCuaCa, data, notifier),
                    const Divider(height: 1, color: Colors.white10),
                    ...hsCuaCa.map((hs) => _buildDiemDanhRow(hs, caHoc, data)),
                  ],
          ),
        );
      },
    );
  }

  // HÀM MỚI: Thanh thao tác nhanh cho từng ca học
  Widget _buildQuickActionsBar(
    LichHoc caHoc,
    List<HSLopViewModel> hsCuaCa,
    DiemDanhState data,
    DiemDanhController notifier,
  ) {
    final isVi = AppLocalizations.of(context)?.locale.languageCode == 'vi';
    final canUndo =
        caHoc.id != null &&
        data.lastBulkBackupPerCa.containsKey(caHoc.id!) &&
        data.lastBulkBackupPerCa[caHoc.id!]!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // 0. KẾT THÚC CA & ĐÁNH GIÁ
            ElevatedButton.icon(
              onPressed: () => _moTrangKetThucCa(caHoc, hsCuaCa, data),
              icon: const Icon(Icons.fact_check_rounded, size: 16),
              label: Text(
                isVi ? 'KẾT THÚC CA & ĐÁNH GIÁ' : 'End Session & Review',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
              ),
            ),
            const SizedBox(width: 6),
            // 1. Có mặt tất cả
            OutlinedButton.icon(
              onPressed: () => notifier.markAllStatus(caHoc, 'Có mặt'),
              icon: const Icon(
                Icons.check_circle,
                size: 16,
                color: Colors.greenAccent,
              ),
              label: Text(
                isVi ? '✓ Có mặt tất cả' : '✓ All Present',
                style: const TextStyle(fontSize: 12, color: Colors.greenAccent),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.greenAccent),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
            const SizedBox(width: 6),
            // 2. Chưa điểm danh tất cả (NO_RECORD)
            OutlinedButton.icon(
              onPressed: () => notifier.markAllStatus(caHoc, 'Chưa điểm danh'),
              icon: const Icon(
                Icons.radio_button_unchecked,
                size: 16,
                color: Colors.grey,
              ),
              label: Text(
                isVi ? '○ Chưa DD tất cả' : '○ All Unrecorded',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.grey),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
            const SizedBox(width: 6),
            // 3. Nghỉ có phép tất cả
            OutlinedButton.icon(
              onPressed: () => notifier.markAllStatus(caHoc, 'Nghỉ có phép'),
              icon: const Icon(
                Icons.event_busy,
                size: 16,
                color: Colors.orangeAccent,
              ),
              label: Text(
                isVi ? 'CP Nghỉ có phép tất cả' : 'CP All Excused',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.orangeAccent,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.orangeAccent),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
            const SizedBox(width: 6),
            // 4. Nghỉ không phép tất cả (Có confirm nếu > 10 hoặc có dữ liệu)
            OutlinedButton.icon(
              onPressed: () =>
                  _confirmMarkAllUnexcused(caHoc, hsCuaCa, data, notifier),
              icon: Icon(Icons.cancel, size: 16, color: absentColor),
              label: Text(
                isVi ? 'KP Nghỉ không phép tất cả' : 'KP All Unexcused',
                style: TextStyle(fontSize: 12, color: absentColor),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: absentColor),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
            const SizedBox(width: 6),
            // 5. Hoàn tác thao tác hàng loạt
            ElevatedButton.icon(
              onPressed: canUndo ? () => notifier.undoBulkAction(caHoc) : null,
              icon: const Icon(Icons.undo, size: 16),
              label: Text(
                isVi ? '↶ Hoàn tác' : '↶ Undo',
                style: const TextStyle(fontSize: 12),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: darkBackground,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // HÀM MỚI: Mở trang Kết Thúc Ca & Đánh Giá
  Future<void> _moTrangKetThucCa(
    LichHoc caHoc,
    List<HSLopViewModel> hsCuaCa,
    DiemDanhState data,
  ) async {
    final Map<String, String> currentAttMap = {};
    for (var hs in hsCuaCa) {
      final key = '${hs.id}-${caHoc.id}';
      final rec = data.trangThaiDiemDanh[key];
      if (rec != null) {
        currentAttMap[key] = rec.trangThai;
      }
    }

    final selectedLop = data.selectedLop;
    final targetDate = data.selectedDate;

    if (selectedLop != null) {
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (ctx) => PostSessionReviewPage(
            lop: selectedLop,
            caHoc: caHoc,
            date: targetDate,
            danhSachHS: hsCuaCa,
            currentAttendanceStatus: currentAttMap,
          ),
        ),
      );

      if (result == true && mounted) {
        ref.invalidate(
          diemDanhControllerProvider(widget.selectedLopId, widget.selectedDate),
        );
      }
    }
  }

  // HÀM MỚI: Confirm trước khi đánh tất cả nghỉ không phép
  Future<void> _confirmMarkAllUnexcused(
    LichHoc caHoc,
    List<HSLopViewModel> hsCuaCa,
    DiemDanhState data,
    DiemDanhController notifier,
  ) async {
    final hasExistingData = hsCuaCa.any((hs) {
      final key = '${hs.id}-${caHoc.id}';
      final st = data.trangThaiDiemDanh[key]?.trangThai;
      return st != null && st != 'Chưa điểm danh';
    });

    if (hsCuaCa.length > 10 || hasExistingData) {
      final isVi = AppLocalizations.of(context)?.locale.languageCode == 'vi';
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: cardColor,
          title: Text(
            isVi ? 'Xác nhận Đánh vắng hàng loạt' : 'Confirm Batch Absence',
            style: TextStyle(color: absentColor, fontWeight: FontWeight.bold),
          ),
          content: Text(
            isVi
                ? 'Bạn có chắc chắn muốn đánh dấu "Nghỉ không phép" cho tất cả ${hsCuaCa.length} học sinh ca này không?'
                : 'Are you sure you want to mark "Unexcused Absent" for all ${hsCuaCa.length} students in this session?',
            style: TextStyle(color: lightText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                isVi ? 'Hủy' : 'Cancel',
                style: TextStyle(color: secondaryText),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: absentColor),
              child: Text(
                isVi ? 'Đồng ý' : 'Confirm',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    notifier.markAllStatus(caHoc, 'Nghỉ không phép');
  }

  Widget _buildAbsenceOptions(
    DiemDanh record,
    LichHoc caHoc,
    String tenHocSinh,
  ) {
    final isExcused = record.trangThai == 'Nghỉ có phép';
    final isMakeUp = record.trangThai == 'Học bù';
    final isUnexcused =
        record.trangThai == 'Nghỉ không phép' || (!isExcused && !isMakeUp);
    final isVi = AppLocalizations.of(context)?.locale.languageCode == 'vi';

    if (record.trangThai == 'Có mặt') {
      return const SizedBox.shrink();
    } else {
      final selectedColor = isMakeUp
          ? makeUpColor
          : (isExcused ? Colors.orangeAccent : absentColor);

      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: ToggleButtons(
              isSelected: [isUnexcused, isExcused, isMakeUp],
              onPressed: (int index) {
                final newStatus = index == 0
                    ? 'Nghỉ không phép'
                    : (index == 1 ? 'Nghỉ có phép' : 'Học bù');
                final key = '${record.idHocSinh}-${caHoc.id}';
                ref
                    .read(
                      diemDanhControllerProvider(
                        widget.selectedLopId,
                        widget.selectedDate,
                      ).notifier,
                    )
                    .updateAttendanceStatus(key, newStatus);
              },
              borderRadius: BorderRadius.circular(8.0),
              selectedBorderColor: selectedColor,
              selectedColor: lightText,
              color: secondaryText,
              fillColor: selectedColor.withValues(alpha: 0.3),
              constraints: BoxConstraints(
                minHeight: 35.0,
                minWidth: (MediaQuery.of(context).size.width - 160) / 3,
              ),
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Text(
                    isVi ? 'K.Phép' : 'Unexcused',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Text(
                    isVi ? 'Có Phép' : 'Excused',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Text(
                    isVi ? 'Học Bù' : 'Make-up',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(Icons.edit_note_outlined, color: secondaryText),
            onPressed: () => _showGhiChuDialog(record, caHoc),
          ),
        ],
      );
    }
  }

  // HÀM MỚI: Hiển thị dialog nhập ghi chú
  Future<void> _showGhiChuDialog(DiemDanh record, LichHoc caHoc) async {
    final controller = TextEditingController(text: record.ghiChu);
    final isVi = AppLocalizations.of(context)?.locale.languageCode == 'vi';

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        title: Text(
          isVi ? 'Ghi chú' : 'Notes',
          style: TextStyle(color: lightText),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: lightText),
          decoration: InputDecoration(
            hintText: isVi
                ? 'Nhập lý do nghỉ...'
                : 'Enter reason for absence...',
            hintStyle: TextStyle(color: secondaryText),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: darkBackground,
          ),
          onChanged: (value) {
            final correctKey = '${record.idHocSinh}-${caHoc.id}';
            ref
                .read(
                  diemDanhControllerProvider(
                    widget.selectedLopId,
                    widget.selectedDate,
                  ).notifier,
                )
                .updateAttendanceNote(correctKey, value);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              isVi ? 'Đóng' : 'Close',
              style: TextStyle(color: accentColor),
            ),
          ),
        ],
      ),
    );
  }
}
