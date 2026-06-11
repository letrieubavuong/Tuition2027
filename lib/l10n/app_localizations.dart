// File: lib/l10n/app_localizations.dart

import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      // General
      'save': 'Save',
      'cancel': 'Cancel',
      'delete': 'Delete',
      'edit': 'Edit',
      'add': 'Add',
      'close': 'Close',
      'confirm': 'Confirm',
      'error': 'Error',
      'success': 'Success',
      'loading': 'Loading...',
      'noData': 'No data available.',
      'version': 'Version',

      // Main Drawer & Bottom Nav
      'home': 'Home',
      'classManagement': 'Class',
      'studentManagement': 'Student',
      'feeManagement': 'Fees',
      'mainFunctions': 'MAIN FUNCTIONS',
      'utilities': 'UTILITIES',
      'exportPdfReport': 'Export PDF Report',
      'statistics': 'Statistics',
      'settings': 'Settings',
      'userGuide': 'User Guide',

      // Settings Page
      'appSettings': 'APPLICATION SETTINGS',
      'darkMode': 'Dark Mode',
      'language': 'Language',
      'managerInfo': 'Manager Information',
      'managerName': 'Manager Name',
      'email': 'Email',
      'feeSettings': 'Fee Settings (VND)',
      'feePerSession': 'Fee per session',
      'feePerMonth': 'Fee per month (Not used)',
      'saveSettings': 'SAVE SETTINGS',
      'schoolList': 'List of Schools',
      'addSchool': 'Add New School',
      'editSchool': 'Edit School',
      'schoolName': 'School Name',
      'backupAndRestore': 'Backup & Restore',
      'backupData': 'Backup Data',
      'restoreData': 'Restore Data',
      'backupSuccess': 'Backup successful to: {path}',
      'backupError': 'Error during backup: {error}',
      'restoreConfirmTitle': 'Confirm Restore',
      'restoreConfirmContent':
          'This action will overwrite all current data with data from the backup file. Are you sure you want to continue?',
      'restoreSuccessTitle': 'Restore Successful',
      'restoreSuccessContent':
          'Data has been restored. Please restart the application to apply changes.',
      'restart': 'RESTART',
      'restoreError': 'Error during restore: {error}',
      'deleteSchoolSuccess': 'School deleted successfully!',
      'saveSettingsSuccess': 'Settings saved successfully!',

      // Fee Management Page
      'feeManagementTitle': 'FEE MANAGEMENT',
      'year': 'YEAR',
      'showOnlyClassesWithDebt': 'Show only classes with debt',
      'allClassesPaid': 'All classes have completed their fees.',
      'totalCollected': 'TOTAL COLLECTED',
      'totalDebt': 'TOTAL DEBT',
      'allStudentsInClassPaid':
          'All students in class {className} have completed their fees for {month}.',
      'amountDue': 'Amount Due',
      'amountPaid': 'Amount Paid',
      'due': 'DUE',
      'paymentUpdated': 'Payment updated!',
      'paymentUpdateError': 'Error updating payment: {error}',
      'collectPaymentFor': 'Collect payment for {studentName}',
      'month': 'Month',
      'feeRule': 'Fee Rule',
      'status': 'Status',
      'statusPaid': 'Paid in full',
      'statusNotPaid': 'Not paid in full',
      'amountToCollect': 'Amount to collect',
      'noteOptional': 'Note (Optional)',
      'invalidAmount': 'Please enter a valid amount',
      'collectedAmount': 'Collected {amount} from {studentName}',

      // Student List Page
      'studentListTitle': 'STUDENT LIST',
      'searchStudentHint': 'Search by student name...',
      'noStudentsYet': 'No students yet.',
      'noStudentsFound': 'No students found.',
      'deleteStudentConfirmTitle': 'Confirm Deletion',
      'deleteStudentConfirmContent':
          'Are you sure you want to remove student "{studentName}" from the system? This action cannot be undone.',
      'deleteStudentSuccess': 'Student deleted successfully!',
      'addStudentSuccess': 'New student added!',
      'updateStudentSuccess': 'Student information updated!',
      // Splash Screen
      'splashSubtitle': 'Tuition & Student Management System',
      'splashTagline': 'Efficient - Professional - Reliable',
      'getStarted': 'Get Started',
      // Home Page
      'homePageHeader': 'HOME PAGE',
      'studentDistributionTitle': 'STUDENT DISTRIBUTION BY GRADE',
      'noStudentDataChart': 'No student data available to generate chart.',
      'todayScheduleTitle': 'TODAY\'S SCHEDULE',
      'noScheduleToday': 'No classes scheduled for today.',
      'grade': 'Grade {grade}',
      'homeMetricStudent': 'Students',
      'homeMetricClass': 'Classes',
      'homeMetricRevenue': 'Revenue',
      'homeMetricDebt': 'Debt',
      'homeSubtitleToday': 'Today',
      'homeSubtitleCollectionRate': 'Collection rate',
      'homeSubtitleRemainingDebt': 'Remaining debt',
      'homeSubtitleClassCount': '{count} classes',
      // Additional Drawer / Popups
      'scoreRules': 'Score Rules',
      'avatarUpdateSuccess': 'Avatar updated successfully!',
    },
    'vi': {
      // General
      'save': 'Lưu',
      'cancel': 'Hủy',
      'delete': 'Xóa',
      'edit': 'Sửa',
      'add': 'Thêm',
      'close': 'Đóng',
      'confirm': 'Xác nhận',
      'error': 'Lỗi',
      'success': 'Thành công',
      'loading': 'Đang tải...',
      'noData': 'Không có dữ liệu.',
      'version': 'Phiên bản',

      // Main Drawer & Bottom Nav
      'home': 'Trang Chủ',
      'classManagement': 'Lớp học',
      'studentManagement': 'Học sinh',
      'feeManagement': 'Học phí',
      'mainFunctions': 'CHỨC NĂNG CHÍNH',
      'utilities': 'TIỆN ÍCH',
      'exportPdfReport': 'Xuất Báo Cáo PDF',
      'statistics': 'Thống Kê',
      'settings': 'Cài Đặt',
      'userGuide': 'Hướng dẫn sử dụng',

      // Settings Page
      'appSettings': 'CÀI ĐẶT ỨNG DỤNG',
      'darkMode': 'Chế độ tối',
      'language': 'Ngôn ngữ',
      'managerInfo': 'Thông tin người quản lý',
      'managerName': 'Tên người quản lý',
      'email': 'Email',
      'feeSettings': 'Thiết lập mức thu học phí (VND)',
      'feePerSession': 'Học phí theo buổi',
      'feePerMonth': 'Mức thu theo tháng (Chưa dùng)',
      'saveSettings': 'LƯU CÀI ĐẶT CHUNG',
      'schoolList': 'Danh sách các trường học',
      'addSchool': 'Thêm Trường học mới',
      'editSchool': 'Sửa Trường học',
      'schoolName': 'Tên Trường',
      'backupAndRestore': 'Sao lưu & Phục hồi',
      'backupData': 'Sao lưu Dữ liệu',
      'restoreData': 'Phục hồi Dữ liệu',
      'backupSuccess': 'Đã sao lưu thành công vào: {path}',
      'backupError': 'Lỗi khi sao lưu: {error}',
      'restoreConfirmTitle': 'Xác nhận Phục hồi',
      'restoreConfirmContent':
          'Thao tác này sẽ ghi đè toàn bộ dữ liệu hiện tại bằng dữ liệu từ file sao lưu. Bạn có chắc chắn muốn tiếp tục không?',
      'restoreSuccessTitle': 'Phục hồi thành công',
      'restoreSuccessContent':
          'Dữ liệu đã được phục hồi. Vui lòng khởi động lại ứng dụng để áp dụng thay đổi.',
      'restart': 'KHỞI ĐỘNG LẠI',
      'restoreError': 'Lỗi khi phục hồi: {error}',
      'deleteSchoolSuccess': 'Đã xóa trường thành công!',
      'saveSettingsSuccess': 'Đã lưu cài đặt thành công!',

      // Fee Management Page
      'feeManagementTitle': 'QUẢN LÍ HỌC PHÍ',
      'year': 'NĂM',
      'showOnlyClassesWithDebt': 'Chỉ hiển thị lớp còn nợ',
      'allClassesPaid': 'Tất cả các lớp đã hoàn thành học phí.',
      'totalCollected': 'TỔNG TIỀN ĐÃ THU',
      'totalDebt': 'TỔNG TIỀN CÒN NỢ',
      'allStudentsInClassPaid':
          'Tất cả học sinh lớp {className} đã hoàn thành học phí tháng {month}.',
      'amountDue': 'Cần nộp',
      'amountPaid': 'Đã đóng',
      'due': 'NỢ',
      'paymentUpdated': 'Đã cập nhật thanh toán!',
      'paymentUpdateError': 'Lỗi cập nhật thanh toán: {error}',
      'collectPaymentFor': 'Thu tiền học phí cho {studentName}',
      'month': 'Tháng',
      'feeRule': 'Học phí quy định',
      'status': 'Trạng thái',
      'statusPaid': 'Đã đóng đủ',
      'statusNotPaid': 'Chưa đóng đủ',
      'amountToCollect': 'Số tiền thu thêm',
      'noteOptional': 'Ghi chú (Tùy chọn)',
      'invalidAmount': 'Vui lòng nhập số tiền hợp lệ',
      'collectedAmount': 'Đã thu {amount} của {studentName}',

      // Student List Page
      'studentListTitle': 'DANH SÁCH HỌC SINH',
      'searchStudentHint': 'Tìm kiếm theo tên học sinh...',
      'noStudentsYet': 'Chưa có học sinh nào.',
      'noStudentsFound': 'Không tìm thấy học sinh nào.',
      'deleteStudentConfirmTitle': 'Xác nhận Xóa',
      'deleteStudentConfirmContent':
          'Bạn có chắc chắn muốn xóa học sinh "{studentName}" khỏi hệ thống không? Thao tác này không thể hoàn tác.',
      'deleteStudentSuccess': 'Đã xóa học sinh thành công!',
      'addStudentSuccess': 'Đã thêm học sinh mới!',
      'updateStudentSuccess': 'Đã cập nhật học sinh!',
      // Splash Screen
      'splashSubtitle': 'Hệ thống Quản lý Học sinh & Học phí',
      'splashTagline': 'Hiệu quả - Chuyên nghiệp - Tin cậy',
      'getStarted': 'Bắt Đầu Ngay',
      // Home Page
      'homePageHeader': 'TRANG CHỦ',
      'studentDistributionTitle': 'PHÂN BỐ HỌC SINH THEO KHỐI',
      'noStudentDataChart': 'Chưa có dữ liệu học sinh để tạo biểu đồ.',
      'todayScheduleTitle': 'LỊCH HỌC HÔM NAY',
      'noScheduleToday': 'Không có ca học nào hôm nay.',
      'grade': 'Khối {grade}',
      'homeMetricStudent': 'Học Sinh',
      'homeMetricClass': 'Ca Học',
      'homeMetricRevenue': 'Doanh Thu',
      'homeMetricDebt': 'Công Nợ',
      'homeSubtitleToday': 'Hôm nay',
      'homeSubtitleCollectionRate': 'Tỷ lệ thu',
      'homeSubtitleRemainingDebt': 'Tiền còn nợ',
      'homeSubtitleClassCount': '{count} lớp',
      // Additional Drawer / Popups
      'scoreRules': 'Quy Tắc Điểm',
      'avatarUpdateSuccess': 'Đã cập nhật ảnh đại diện!',
    },
  };

  String? get(String key) {
    return _localizedValues[locale.languageCode]?[key];
  }

  // General
  String get success => get('success')!;
  String get close => get('close')!;
  String get cancel => get('cancel')!;
  String get delete => get('delete')!;
  String get edit => get('edit')!;
  String get confirm => get('confirm')!;
  String get error => get('error')!;

  // Home Page
  String get homePageTitle => get('home')!;
  String get classLabel => get('classManagement')!;
  String get studentLabel => get('studentManagement')!;
  String get feeLabel => get('feeManagement')!;

  // Drawer
  String get mainFunctions => get('mainFunctions')!;
  String get utilities => get('utilities')!;
  String get exportPdfReport => get('exportPdfReport')!;
  String get statistics => get('statistics')!;
  String get settings => get('settings')!;
  String get userGuide => get('userGuide')!;
  String get version => get('version')!;

  // Settings Page
  String get appSettings => get('appSettings')!;
  String get darkMode => get('darkMode')!;
  String get language => get('language')!;
  String get managerInfo => get('managerInfo')!;
  String get managerName => get('managerName')!;
  String get email => get('email')!;
  String get feeSettings => get('feeSettings')!;
  String get feePerSession => get('feePerSession')!;
  String get feePerMonth => get('feePerMonth')!;
  String get saveSettings => get('saveSettings')!;
  String get schoolList => get('schoolList')!;
  String get addSchool => get('addSchool')!;
  String get editSchool => get('editSchool')!;
  String get schoolName => get('schoolName')!;
  String get backupAndRestore => get('backupAndRestore')!;
  String get backupData => get('backupData')!;
  String get restoreData => get('restoreData')!;
  String get deleteSchoolSuccess => get('deleteSchoolSuccess')!;
  String get saveSettingsSuccess => get('saveSettingsSuccess')!;
  String get restoreConfirmTitle => get('restoreConfirmTitle')!;
  String get restoreConfirmContent => get('restoreConfirmContent')!;
  String get restoreSuccessTitle => get('restoreSuccessTitle')!;
  String get restoreSuccessContent => get('restoreSuccessContent')!;
  String get restart => get('restart')!;
  String backupSuccess(String path) =>
      get('backupSuccess')!.replaceAll('{path}', path);
  String backupError(String error) =>
      get('backupError')!.replaceAll('{error}', error);
  String restoreError(String error) =>
      get('restoreError')!.replaceAll('{error}', error);

  // Fee Management Page
  String get feeManagementTitle => get('feeManagementTitle')!;
  String get year => get('year')!;
  String get showOnlyClassesWithDebt => get('showOnlyClassesWithDebt')!;
  String get allClassesPaid => get('allClassesPaid')!;
  String get totalCollected => get('totalCollected')!;
  String get totalDebt => get('totalDebt')!;
  String allStudentsInClassPaid(String className, String month) => get(
    'allStudentsInClassPaid',
  )!.replaceAll('{className}', className).replaceAll('{month}', month);
  String get amountDue => get('amountDue')!;
  String get amountPaid => get('amountPaid')!;
  String get due => get('due')!;
  String get paymentUpdated => get('paymentUpdated')!;
  String paymentUpdateError(String error) =>
      get('paymentUpdateError')!.replaceAll('{error}', error);
  String collectPaymentFor(String studentName) =>
      get('collectPaymentFor')!.replaceAll('{studentName}', studentName);

  // Student List Page
  String get studentListTitle => get('studentListTitle')!;
  String get searchStudentHint => get('searchStudentHint')!;
  String get noStudentsYet => get('noStudentsYet')!;
  String get noStudentsFound => get('noStudentsFound')!;
  String get deleteStudentConfirmTitle => get('deleteStudentConfirmTitle')!;
  String deleteStudentConfirmContent(String studentName) => get(
    'deleteStudentConfirmContent',
  )!.replaceAll('{studentName}', studentName);
  String get deleteStudentSuccess => get('deleteStudentSuccess')!;
  String get addStudentSuccess => get('addStudentSuccess')!;
  String get updateStudentSuccess => get('updateStudentSuccess')!;

  // Splash Screen
  String get splashSubtitle => get('splashSubtitle')!;
  String get splashTagline => get('splashTagline')!;
  String get getStarted => get('getStarted')!;

  // Home Page
  String get homePageHeader => get('homePageHeader')!;
  String get studentDistributionTitle => get('studentDistributionTitle')!;
  String get noStudentDataChart => get('noStudentDataChart')!;
  String get todayScheduleTitle => get('todayScheduleTitle')!;
  String get noScheduleToday => get('noScheduleToday')!;
  String grade(String gradeNum) => get('grade')!.replaceAll('{grade}', gradeNum);
  String get homeMetricStudent => get('homeMetricStudent')!;
  String get homeMetricClass => get('homeMetricClass')!;
  String get homeMetricRevenue => get('homeMetricRevenue')!;
  String get homeMetricDebt => get('homeMetricDebt')!;
  String get homeSubtitleToday => get('homeSubtitleToday')!;
  String get homeSubtitleCollectionRate => get('homeSubtitleCollectionRate')!;
  String get homeSubtitleRemainingDebt => get('homeSubtitleRemainingDebt')!;
  String homeSubtitleClassCount(String count) => get('homeSubtitleClassCount')!.replaceAll('{count}', count);

  // Additional Drawer / Popups
  String get scoreRules => get('scoreRules')!;
  String get avatarUpdateSuccess => get('avatarUpdateSuccess')!;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'vi'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
