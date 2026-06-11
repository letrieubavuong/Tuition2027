import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

class HuongDanSuDungPage extends StatelessWidget {
  const HuongDanSuDungPage({super.key});

  // --- Theme màu ---
  static const Color darkBackground = Color(0xFF1A1A2E);
  static const Color cardColor = Color(0xFF16213E);
  static const Color lightText = Colors.white;
  static const Color secondaryText = Colors.white70;
  static const Color accentColor = Color(0xFF00BFA5);

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isVi = loc?.locale.languageCode == 'vi';

    final title = isVi ? 'HƯỚNG DẪN SỬ DỤNG' : 'USER GUIDE';

    final stepsVi = [
      const GuideStep(
        step: 'Bước 1',
        title: 'Cài đặt ban Đầu',
        icon: Icons.settings,
        content: [
          'Mở menu (biểu tượng 3 gạch ở góc trên bên trái).',
          'Chọn "Cài Đặt".',
          'Thiết lập "Học phí theo buổi" và "Mức thu theo tháng" (mức trần học phí).',
          'Thêm danh sách các trường học để tiện cho việc nhập hồ sơ học sinh.',
        ],
      ),
      const GuideStep(
        step: 'Bước 2',
        title: 'Quản lý học sinh',
        icon: Icons.person_add,
        content: [
          'Vào mục "Quản lý Học sinh" từ menu hoặc thanh điều hướng dưới cùng.',
          'Nhấn nút "+" để thêm học sinh mới.',
          'Điền đầy đủ thông tin: Tên, SĐT, Trường, Địa chỉ, và đặc biệt là "Miễn Giảm (%)" nếu có.',
          'Để sửa hoặc xóa học sinh, nhấn vào menu 3 chấm trên thẻ của học sinh đó.',
        ],
      ),
      const GuideStep(
        step: 'Bước 3',
        title: 'Quản Lý Lớp Học',
        icon: Icons.class_,
        content: [
          'Vào mục "Quản lý Lớp học".',
          'Nhấn nút "+" để tạo lớp mới.',
          'Chọn Khối và nhập Tên lớp.',
        ],
      ),
      const GuideStep(
        step: 'Bước 4',
        title: 'Thiết Lập Chi Tiết Lớp',
        icon: Icons.list_alt,
        content: [
          'Tại trang "Quản lý Lớp học", nhấn vào một lớp để vào trang chi tiết.',
          'Tab "Học Sinh": Nhấn biểu tượng "Thêm người" để thêm các học sinh đã tạo vào lớp.',
          'Tab "Lịch Học":',
          '  - Nhấn biểu tượng "Lịch" để tạo các lịch học cố định trong tuần (ví dụ: Thứ 2, 18:00 - 20:00).',
          '  - Sau khi có lịch, nhấn biểu tượng "Gán lịch" (hình người có dấu cộng) trên mỗi lịch học để chọn những học sinh nào sẽ theo học lịch đó. Đây là bước quan trọng để điểm danh và tính học phí.',
          'Tab "Chi Tiết":',
          '  - Nhấn nút "Điểm danh" để vào trang điểm danh theo ca.',
          '  - Thêm "Nhiệm vụ" (bài tập về nhà) cho cả lớp.',
        ],
      ),
      const GuideStep(
        step: 'Bước 5',
        title: 'Điểm Danh Hằng Ngày',
        icon: Icons.checklist,
        content: [
          'Từ "Trang Chủ", nhấn vào một ca học trong "LỊCH HỌC HÔM NAY".',
          'Hoặc vào chi tiết lớp và nhấn nút "Điểm danh".',
          'Tại trang điểm danh, chọn đúng Lớp và Ngày.',
          'Mở rộng từng ca học và tick vào ô "Có mặt" cho học sinh.',
          'Nếu học sinh vắng, bỏ tick và chọn "Có Phép" hoặc "Không Phép". Có thể thêm ghi chú.',
          'Nhấn nút "Lưu Tất Cả Thay Đổi" sau khi hoàn tất.',
        ],
      ),
      const GuideStep(
        step: 'Bước 6',
        title: 'Quản Lý Học Phí',
        icon: Icons.payment,
        content: [
          'Vào mục "Quản lý Học phí".',
          'Chọn tháng/năm cần xem.',
          'Ứng dụng sẽ tự động tính toán học phí dựa trên số buổi điểm danh "Có mặt" và "Nghỉ không phép".',
          'Mở rộng một lớp để xem danh sách học sinh còn nợ.',
          'Nhấn vào một học sinh để mở form thu tiền.',
          'Nhập số tiền thu thêm và nhấn "CẬP NHẬT".',
        ],
      ),
      const GuideStep(
        step: 'Bước 7',
        title: 'Báo Cáo & Thống Kê',
        icon: Icons.analytics,
        content: [
          'Từ menu, chọn "Thống Kê" để xem biểu đồ về số lượng học sinh và tình hình thu chi qua các tháng.',
          'Từ menu, chọn "Xuất Báo Cáo PDF" để xuất báo cáo học phí chi tiết của một lớp trong một tháng cụ thể.',
        ],
      ),
    ];

    final stepsEn = [
      const GuideStep(
        step: 'Step 1',
        title: 'Initial Setup',
        icon: Icons.settings,
        content: [
          'Open menu (3-line icon in the top left corner).',
          'Select "Settings".',
          'Configure "Fee per session" and "Fee per month" (fee limit).',
          'Add list of schools for easier student profile entry.',
        ],
      ),
      const GuideStep(
        step: 'Step 2',
        title: 'Student Management',
        icon: Icons.person_add,
        content: [
          'Go to "Student" from the menu or bottom navigation bar.',
          'Tap the "+" button to add a new student.',
          'Enter details: Name, Phone, School, Address, and "Discount (%)" if applicable.',
          'To edit or delete a student, tap the 3-dot menu on that student\'s card.',
        ],
      ),
      const GuideStep(
        step: 'Step 3',
        title: 'Class Management',
        icon: Icons.class_,
        content: [
          'Go to "Class".',
          'Tap the "+" button to create a new class.',
          'Select Grade and enter Class Name.',
        ],
      ),
      const GuideStep(
        step: 'Step 4',
        title: 'Class Details Setup',
        icon: Icons.list_alt,
        content: [
          'In "Class", tap on a class to view its details.',
          'Tab "Students": Tap "Add person" icon to add created students to the class.',
          'Tab "Schedule":',
          '  - Tap "Calendar" icon to create recurring weekly schedules (e.g. Mon, 18:00 - 20:00).',
          '  - Tap "Assign schedule" (person with plus sign) icon on each schedule to select which students will attend. This is crucial for attendance and tuition calculation.',
          'Tab "Details":',
          '  - Tap "Attendance" to go to the session attendance page.',
          '  - Add "Tasks" (homework) for the entire class.',
        ],
      ),
      const GuideStep(
        step: 'Step 5',
        title: 'Daily Attendance',
        icon: Icons.checklist,
        content: [
          'From "Home Page", tap on a class session under "TODAY\'S SCHEDULE".',
          'Or go to class details and tap "Attendance".',
          'On the attendance page, select the correct Class and Date.',
          'Expand each session and check "Present" box for attending students.',
          'If a student is absent, uncheck the box and choose "Excused" or "Unexcused". Notes can be added.',
          'Tap "Save All Changes" when done.',
        ],
      ),
      const GuideStep(
        step: 'Step 6',
        title: 'Fee Management',
        icon: Icons.payment,
        content: [
          'Go to "Fees".',
          'Select the month/year to view.',
          'The app automatically calculates fees based on the number of "Present" and "Unexcused" sessions.',
          'Expand a class to view the list of students with outstanding debt.',
          'Tap on a student to open the payment form.',
          'Enter the additional collected amount and tap "UPDATE".',
        ],
      ),
      const GuideStep(
        step: 'Step 7',
        title: 'Reports & Statistics',
        icon: Icons.analytics,
        content: [
          'From the menu, select "Statistics" to view charts of student count and monthly revenue/debt.',
          'From the menu, select "Export PDF Report" to export detailed tuition reports for a specific class and month.',
        ],
      ),
    ];

    return Scaffold(
      backgroundColor: darkBackground,
      appBar: AppBar(
        title: Text(title),
        centerTitle: true,
        backgroundColor: cardColor,
        foregroundColor: lightText,
      ),
      body: ListView(
        padding: const EdgeInsets.all(4.0),
        children: isVi ? stepsVi : stepsEn,
      ),
    );
  }
}

// Widget phụ trợ để hiển thị một bước hướng dẫn
class GuideStep extends StatelessWidget {
  final String step;
  final String title;
  final IconData icon;
  final List<String> content;

  const GuideStep({
    super.key,
    required this.step,
    required this.title,
    required this.icon,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    const Color accentColor = Color(0xFF00BFA5);
    const Color cardColor = Color(0xFF16213E);
    const Color lightText = Colors.white;
    const Color secondaryText = Colors.white70;

    final isVi = AppLocalizations.of(context)?.locale.languageCode == 'vi';
    final subText = isVi ? 'Hướng dẫn ${title.toLowerCase()}' : 'Guide for ${title.toLowerCase()}';

    return Card(
      color: cardColor,
      margin: const EdgeInsets.only(bottom: 4.0),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: accentColor.withOpacity(0.2),
          foregroundColor: accentColor,
          child: Text(
            step.replaceAll('Bước ', '').replaceAll('Step ', ''),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: lightText,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        subtitle: Text(
          subText,
          style: const TextStyle(color: secondaryText, fontSize: 12),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: content.map((line) {
          final isSubItem = line.trim().startsWith('-');
          return Padding(
            padding: EdgeInsets.only(left: isSubItem ? 16.0 : 0, top: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isSubItem) ...[
                  const Icon(Icons.arrow_right, color: secondaryText, size: 18),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    isSubItem ? line.trim() : line,
                    style: TextStyle(
                      color: secondaryText,
                      height: 1.5,
                      fontStyle: isSubItem
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
