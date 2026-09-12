import 'package:flutter/material.dart';
import '../models/quy_tac_diem.dart';
import '../services/quy_tac_diem_service.dart';
import '../l10n/app_localizations.dart';

// --- Màu sắc động được định nghĩa trong _QuyTacDiemSettingsPageState ---

class QuyTacDiemSettingsPage extends StatefulWidget {
  const QuyTacDiemSettingsPage({super.key});

  @override
  State<QuyTacDiemSettingsPage> createState() => _QuyTacDiemSettingsPageState();
}

class _QuyTacDiemSettingsPageState extends State<QuyTacDiemSettingsPage> {
  Color get darkBackground => Theme.of(context).scaffoldBackgroundColor;
  Color get cardColor => Theme.of(context).cardColor;
  Color get lightText =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
  Color get secondaryText =>
      Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white70;
  Color get accentColor => Theme.of(context).primaryColor;
  Color get deleteColor => Theme.of(context).colorScheme.error;

  final QuyTacDiemService _quyTacDiemService = QuyTacDiemService();
  late Future<List<QuyTacDiem>> _congDiemFuture;
  late Future<List<QuyTacDiem>> _truDiemFuture;

  @override
  void initState() {
    super.initState();
    _taiDuLieu();
  }

  void _taiDuLieu() {
    setState(() {
      _congDiemFuture = _quyTacDiemService.docQuyTacDiemTheoLoai('CONG_DIEM');
      _truDiemFuture = _quyTacDiemService.docQuyTacDiemTheoLoai('TRU_DIEM');
    });
  }

  Future<void> _showQuyTacDiemFormDialog({QuyTacDiem? quyTac}) async {
    final isEditing = quyTac != null;
    final moTaController = TextEditingController(text: quyTac?.moTa);
    final diemThayDoiController = TextEditingController(
      text: quyTac?.diemThayDoi.abs().toString() ?? '0.5',
    );
    String loaiQuyTac = quyTac?.loaiQuyTac ?? 'CONG_DIEM';
    String hangMuc = quyTac?.hangMuc ?? 'THAI_DO';

    final isVi = AppLocalizations.of(context)?.locale.languageCode == 'vi';

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        title: Text(
          isEditing
              ? (isVi ? 'Sửa Quy Tắc Điểm' : 'Edit Score Rule')
              : (isVi ? 'Quy tắc cộng/trừ điểm' : 'Add/Subtract Score Rule'),
          style: TextStyle(color: lightText, fontWeight: FontWeight.bold),
        ),
        content: StatefulBuilder(
          builder: (BuildContext context, StateSetter setStateDialog) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: loaiQuyTac,
                    dropdownColor: darkBackground,
                    style: TextStyle(color: lightText),
                    decoration: InputDecoration(
                      labelText: isVi ? 'Loại Quy Tắc' : 'Rule Type',
                      labelStyle: TextStyle(color: secondaryText),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: darkBackground,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'CONG_DIEM',
                        child: Text(
                          isVi ? 'Cộng điểm' : 'Plus points',
                          style: TextStyle(color: lightText),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'TRU_DIEM',
                        child: Text(
                          isVi ? 'Trừ điểm' : 'Minus points',
                          style: TextStyle(color: lightText),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setStateDialog(() {
                          loaiQuyTac = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: hangMuc,
                    dropdownColor: darkBackground,
                    style: TextStyle(color: lightText),
                    decoration: InputDecoration(
                      labelText: isVi ? 'Hạng mục điểm' : 'Score Category',
                      labelStyle: TextStyle(color: secondaryText),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: darkBackground,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'THAI_DO',
                        child: Text(
                          isVi ? 'Thái độ' : 'Attitude',
                          style: TextStyle(color: lightText),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'HIEU_BAI',
                        child: Text(
                          isVi ? 'Hiểu bài' : 'Understanding',
                          style: TextStyle(color: lightText),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'BAI_TAP',
                        child: Text(
                          isVi ? 'Bài tập' : 'Homework',
                          style: TextStyle(color: lightText),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setStateDialog(() {
                          hangMuc = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: moTaController,
                    style: TextStyle(color: lightText),
                    decoration: InputDecoration(
                      labelText: isVi ? 'Nội dung quy tắc' : 'Rule Description',
                      labelStyle: TextStyle(color: secondaryText),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: darkBackground,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: diemThayDoiController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: TextStyle(color: lightText),
                    decoration: InputDecoration(
                      labelText: isVi ? 'Điểm cộng/trừ' : 'Points to change',
                      labelStyle: TextStyle(color: secondaryText),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: darkBackground,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              isVi ? 'Hủy' : 'Cancel',
              style: TextStyle(color: secondaryText),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final moTa = moTaController.text.trim();
              final diemThayDoiValue = double.tryParse(
                diemThayDoiController.text.trim(),
              );

              if (moTa.isEmpty || diemThayDoiValue == null) {
                return;
              }

              final newDiemThayDoi =
                  loaiQuyTac == 'TRU_DIEM' && diemThayDoiValue > 0
                  ? -diemThayDoiValue
                  : (loaiQuyTac == 'CONG_DIEM' && diemThayDoiValue < 0
                        ? -diemThayDoiValue
                        : diemThayDoiValue);

              if (isEditing) {
                await _quyTacDiemService.capNhatQuyTacDiem(
                  quyTac.copyWith(
                    loaiQuyTac: loaiQuyTac,
                    hangMuc: hangMuc,
                    moTa: moTa,
                    diemThayDoi: newDiemThayDoi,
                  ),
                );
              } else {
                await _quyTacDiemService.taoQuyTacDiem(
                  QuyTacDiem(
                    loaiQuyTac: loaiQuyTac,
                    hangMuc: hangMuc,
                    moTa: moTa,
                    diemThayDoi: newDiemThayDoi,
                  ),
                );
              }
              if (ctx.mounted) {
                Navigator.of(ctx).pop();
                _taiDuLieu();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: darkBackground,
            ),
            child: Text(
              isEditing
                  ? (isVi ? 'Cập Nhật' : 'Update')
                  : (isVi ? 'Thêm' : 'Add'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _xoaQuyTacDiem(int id) async {
    final isVi = AppLocalizations.of(context)?.locale.languageCode == 'vi';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        title: Text(
          isVi ? 'Xác nhận xóa' : 'Confirm Deletion',
          style: TextStyle(color: deleteColor, fontWeight: FontWeight.bold),
        ),
        content: Text(
          isVi
              ? 'Bạn có chắc chắn muốn xóa quy tắc điểm này?'
              : 'Are you sure you want to delete this score rule?',
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
            style: ElevatedButton.styleFrom(
              backgroundColor: deleteColor,
              foregroundColor: lightText,
            ),
            child: Text(isVi ? 'Xóa' : 'Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _quyTacDiemService.xoaQuyTacDiem(id);
      _taiDuLieu();
    }
  }

  Future<void> _tuDongChiaDiem() async {
    final isVi = AppLocalizations.of(context)?.locale.languageCode == 'vi';

    // 1. Đọc toàn bộ quy tắc điểm
    final listQuyTac = await _quyTacDiemService.docTatCaQuyTacDiem();
    if (listQuyTac.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isVi
                  ? 'Chưa có quy tắc nào để chia điểm!'
                  : 'No rules defined yet!',
            ),
          ),
        );
      }
      return;
    }

    final positiveRules = listQuyTac
        .where((r) => r.loaiQuyTac == 'CONG_DIEM')
        .toList();
    final negativeRules = listQuyTac
        .where((r) => r.loaiQuyTac == 'TRU_DIEM')
        .toList();

    // 2. Tính điểm phân phối và cập nhật
    if (positiveRules.isNotEmpty) {
      double sumAllocated = 0.0;
      for (int i = 0; i < positiveRules.length; i++) {
        double share;
        if (i == positiveRules.length - 1) {
          share = 10.0 - sumAllocated;
        } else {
          share = double.parse(
            (10.0 / positiveRules.length).toStringAsFixed(2),
          );
          sumAllocated += share;
        }
        share = double.parse(share.toStringAsFixed(2));
        await _quyTacDiemService.capNhatQuyTacDiem(
          positiveRules[i].copyWith(diemThayDoi: share),
        );
      }
    }

    if (negativeRules.isNotEmpty) {
      double sumAllocated = 0.0;
      for (int i = 0; i < negativeRules.length; i++) {
        double share;
        if (i == negativeRules.length - 1) {
          share = -5.0 - sumAllocated;
        } else {
          share = double.parse(
            (-5.0 / negativeRules.length).toStringAsFixed(2),
          );
          sumAllocated += share;
        }
        share = double.parse(share.toStringAsFixed(2));
        await _quyTacDiemService.capNhatQuyTacDiem(
          negativeRules[i].copyWith(diemThayDoi: share),
        );
      }
    }

    // 3. Tải lại dữ liệu và thông báo
    _taiDuLieu();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isVi
                ? 'Đã chia điểm: Tổng cộng = 10đ, Tổng trừ = -5đ!'
                : 'Points distributed: Total plus = 10, Total minus = -5!',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVi = AppLocalizations.of(context)?.locale.languageCode == 'vi';
    return Scaffold(
      backgroundColor: darkBackground,
      appBar: AppBar(
        title: Text(
          isVi ? 'QUY TẮC ĐÁNH GIÁ BUỔI HỌC' : 'SESSION EVALUATION RULES',
          style: TextStyle(color: lightText, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: cardColor,
        foregroundColor: lightText,
        actions: [
          IconButton(
            tooltip: isVi ? 'Tự động chia điểm' : 'Auto distribute points',
            icon: const Icon(Icons.scale),
            onPressed: _tuDongChiaDiem,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              isVi ? 'Cộng Điểm' : 'Plus Points',
              _congDiemFuture,
              'CONG_DIEM',
            ),
            const SizedBox(height: 32),
            _buildSection(
              isVi ? 'Trừ Điểm' : 'Minus Points',
              _truDiemFuture,
              'TRU_DIEM',
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showQuyTacDiemFormDialog(),
        backgroundColor: accentColor,
        foregroundColor: darkBackground,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSection(
    String title,
    Future<List<QuyTacDiem>> future,
    String loaiQuyTac,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: accentColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Divider(color: secondaryText),
        FutureBuilder<List<QuyTacDiem>>(
          future: future,
          builder: (context, snapshot) {
            final isVi =
                AppLocalizations.of(context)?.locale.languageCode == 'vi';
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  isVi
                      ? 'Lỗi tải dữ liệu: ${snapshot.error}'
                      : 'Error loading data: ${snapshot.error}',
                  style: TextStyle(color: deleteColor),
                ),
              );
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    isVi ? 'Chưa có quy tắc nào.' : 'No rules defined yet.',
                    style: TextStyle(color: secondaryText),
                  ),
                ),
              );
            }
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final quyTac = snapshot.data![index];
                return Card(
                  color: cardColor,
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: loaiQuyTac == 'CONG_DIEM'
                          ? Colors.green.withValues(alpha: 0.2)
                          : deleteColor.withValues(alpha: 0.2),
                      child: Icon(
                        loaiQuyTac == 'CONG_DIEM' ? Icons.add : Icons.remove,
                        color: loaiQuyTac == 'CONG_DIEM'
                            ? Colors.greenAccent
                            : deleteColor,
                      ),
                    ),
                    title: Text(
                      quyTac.moTa,
                      style: TextStyle(
                        color: lightText,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      (isVi ? 'Điểm: ' : 'Points: ') +
                          quyTac.diemThayDoi.toStringAsFixed(1),
                      style: TextStyle(
                        color: loaiQuyTac == 'CONG_DIEM'
                            ? Colors.greenAccent
                            : deleteColor,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit, color: secondaryText),
                          onPressed: () =>
                              _showQuyTacDiemFormDialog(quyTac: quyTac),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete, color: deleteColor),
                          onPressed: () => _xoaQuyTacDiem(quyTac.id!),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
