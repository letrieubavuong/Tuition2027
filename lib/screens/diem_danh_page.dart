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
import '../l10n/app_localizations.dart';
import '../widgets/dang_ky_nghi_le_dialog.dart';

class DiemDanhPage extends ConsumerStatefulWidget {
  final int? selectedLopId;
  final DateTime? selectedDate;

  const DiemDanhPage({super.key, this.selectedLopId, this.selectedDate});

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

      // 3. Duyệt qua các ngày từ đầu tháng đến ngày kết thúc
      for (
        var day = firstDayOfMonth;
        day.isBefore(endDay);
        day = day.add(const Duration(days: 1))
      ) {
        final int thuTrongTuanDB = (day.weekday == 7) ? 1 : day.weekday + 1;

        // Tìm các ca học trong ngày này
        final caHocTrongNgay = allLichHoc
            .where((lh) => lh.thuTrongTuan == thuTrongTuanDB)
            .toList();

        if (caHocTrongNgay.isNotEmpty) {
          // SỬA: Không kiểm tra diemDanhDaCo.isEmpty nữa.
          // Cứ gọi hàm điểm danh bù, service sẽ dùng "INSERT OR IGNORE"
          // để bỏ qua những học sinh đã có dữ liệu trong ngày hôm đó.
          for (var caHoc in caHocTrongNgay) {
            // Lấy danh sách học sinh chính xác cho ca học này
            final hsCuaCa = await ref
                .read(lopHocSinhServiceProvider)
                .docDSHSTheoCaHoc(caHoc.id!);
            if (hsCuaCa.isNotEmpty) {
              // Điểm danh hàng loạt chỉ cho ca này và danh sách HS tương ứng
              await ref.read(diemDanhServiceProvider).diemDanhCoMatHangLoat(
                hsCuaCa,
                [caHoc], // Chỉ truyền ca học hiện tại
                day,
              );
            }
          }
        }
      }
      if (mounted) Navigator.of(context).pop(); // Đóng loading
      if (mounted) {
        _showInfoDialog(
          isVi ? 'Thành công' : 'Success',
          isVi
              ? 'Đã hoàn tất điểm danh bù cho các buổi học còn trống!'
              : 'Makeup attendance completed for empty sessions!',
        );
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

        return Card(
          color: cardColor,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ExpansionTile(
            title: Text(
              'Ca ${caHoc.gioBatDau.substring(0, 5)} - ${caHoc.gioKetThuc.substring(0, 5)}',
              style: TextStyle(color: lightText, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${hsCuaCa.length} ${isVi ? 'học sinh' : 'students'}',
              style: TextStyle(color: secondaryText),
            ),
            leading: IconButton(
              icon: Icon(Icons.check_circle_outline, color: presentColor),
              tooltip: isVi ? 'Điểm danh "Có mặt" tất cả' : 'Mark all present',
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
                : hsCuaCa
                      .map((hs) => _buildDiemDanhRow(hs, caHoc, data))
                      .toList(),
          ),
        );
      },
    );
  }

  Widget _buildAbsenceOptions(
    DiemDanh record,
    LichHoc caHoc,
    String tenHocSinh,
  ) {
    final isExcused = record.trangThai == 'Nghỉ có phép';
    final isMakeUp = record.trangThai == 'Học bù';
    final isUnexcused = record.trangThai == 'Nghỉ không phép' || (!isExcused && !isMakeUp);
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
            onPressed: () => _showGhiChuDialog(record),
          ),
        ],
      );
    }
  }

  // HÀM MỚI: Hiển thị dialog nhập ghi chú
  Future<void> _showGhiChuDialog(DiemDanh record) async {
    final controller = TextEditingController(text: record.ghiChu);
    final isVi = AppLocalizations.of(context)?.locale.languageCode == 'vi';
    // SỬA: Thay thế firstWhere bằng vòng lặp để tránh lỗi kiểu dữ liệu với orElse.
    LichHoc? caHoc;
    final caHocList = ref
        .read(
          diemDanhControllerProvider(widget.selectedLopId, widget.selectedDate),
        )
        .value
        ?.caHocTrongNgay;
    if (caHocList != null) {
      for (final ch in caHocList) {
        if (record.gioDiemDanh.contains(ch.gioBatDau)) {
          caHoc = ch;
          break;
        }
      }
    }
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
            // SỬA: Nếu không tìm thấy ca học, không làm gì cả.
            if (caHoc == null) return;
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
