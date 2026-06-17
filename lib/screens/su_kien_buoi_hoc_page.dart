import 'package:flutter/material.dart';
import '../services/danh_gia_buoi_hoc_service.dart';
import '../models/su_kien_hoc_tap.dart';
import '../models/quy_tac_diem.dart';
import '../services/su_kien_hoc_tap_service.dart';
import '../services/quy_tac_diem_service.dart';

import '../models/danh_gia_buoi_hoc.dart';
import '../l10n/app_localizations.dart';
import '../utils/toast_helper.dart';

class SuKienBuoiHocPage extends StatefulWidget {
  final int idDiemDanh;
  final String tenHocSinh;

  const SuKienBuoiHocPage({
    super.key,
    required this.idDiemDanh,
    required this.tenHocSinh,
  });

  @override
  State<SuKienBuoiHocPage> createState() => _SuKienBuoiHocPageState();
}

class _SuKienBuoiHocPageState extends State<SuKienBuoiHocPage> {
  // --- Theme Colors ---
  static const Color darkBackground = Color(0xFF1A1A2E);
  static const Color cardColor = Color(0xFF16213E);
  static const Color lightText = Colors.white;
  static const Color secondaryText = Colors.white70;
  static const Color accentColor = Color(0xFF00BFA5);
  static const Color positiveColor = Colors.greenAccent;
  static const Color negativeColor = Colors.redAccent;

  final _service = SuKienHocTapService();
  final _danhGiaService = DanhGiaBuoiHocService();
  final _quyTacService = QuyTacDiemService();

  final _nhanXetController = TextEditingController();
  late Future<List<SuKienHocTap>> _loadEventsFuture;
  late Future<DanhGiaBuoiHoc> _loadEvaluationFuture;
  List<QuyTacDiem> _suKienTichCuc = [];
  List<QuyTacDiem> _suKienTieuCuc = [];
  bool _isLoadingQuyTac = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _taiQuyTacDiem();
  }

  void _loadData() {
    setState(() {
      _loadEventsFuture = _service.laySuKienTheoBuoiHoc(widget.idDiemDanh);
      _loadEvaluationFuture = _danhGiaService.layHoacTaoDanhGia(widget.idDiemDanh).then((dg) {
        _nhanXetController.text = dg.nhanXet ?? '';
        return dg;
      });
    });
  }

  @override
  void dispose() {
    _nhanXetController.dispose();
    super.dispose();
  }

  Future<void> _luuNhanXet(String text) async {
    final dg = await _loadEvaluationFuture;
    dg.nhanXet = text;
    await _danhGiaService.luuDanhGia(dg);
  }

  void _loadEvents() {
    _loadData();
  }

  Future<void> _taiQuyTacDiem() async {
    try {
      final tatCaQuyTac = await _quyTacService.docTatCaQuyTacDiem();

      final tichCuc = tatCaQuyTac
          .where((q) => q.loaiQuyTac == 'CONG_DIEM')
          .toList();

      final tieuCuc = tatCaQuyTac
          .where((q) => q.loaiQuyTac == 'TRU_DIEM')
          .toList();

      if (mounted) {
        setState(() {
          _suKienTichCuc = tichCuc;
          _suKienTieuCuc = tieuCuc;
          _isLoadingQuyTac = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingQuyTac = false);
    }
  }

  IconData _getIconForMoTa(String moTa, bool isPositive) {
    moTa = moTa.toLowerCase();
    if (moTa.contains('lên bảng')) return Icons.present_to_all;
    if (moTa.contains('phát biểu')) return Icons.record_voice_over;
    if (moTa.contains('bài tập')) return Icons.assignment_turned_in;
    if (moTa.contains('nói chuyện')) return Icons.chat_bubble_outline;
    if (moTa.contains('trật tự')) return Icons.campaign;
    if (moTa.contains('muộn')) return Icons.timer_off_outlined;

    return isPositive ? Icons.add_circle_outline : Icons.remove_circle_outline;
  }

  Future<void> _themSuKien(QuyTacDiem quyTac) async {
    final suKienMoi = SuKienHocTap(
      idDiemDanh: widget.idDiemDanh,
      loaiSuKien: _mapHangMucToLoaiSuKien(quyTac.hangMuc),
      moTa: quyTac.moTa,
      diemThayDoi: quyTac.diemThayDoi,
    );
    await _service.themSuKien(suKienMoi);
    await _danhGiaService.capNhatDiemTuSuKien(widget.idDiemDanh);
    _loadEvents();
  }

  LoaiSuKien _mapHangMucToLoaiSuKien(String hangMuc) {
    switch (hangMuc) {
      case 'THAI_DO':
        return LoaiSuKien.thaiDo;
      case 'HIEU_BAI':
        return LoaiSuKien.hieuBai;
      case 'BAI_TAP':
        return LoaiSuKien.baiTap;
      default:
        return LoaiSuKien.khac;
    }
  }

  Future<void> _xoaSuKien(int idSuKien) async {
    await _service.xoaSuKien(idSuKien);
    await _danhGiaService.capNhatDiemTuSuKien(widget.idDiemDanh);
    _loadEvents();
  }

  @override
  Widget build(BuildContext context) {
    final isVi = AppLocalizations.of(context)?.locale.languageCode == 'vi';

    return Scaffold(
      backgroundColor: darkBackground,
      appBar: AppBar(
        backgroundColor: cardColor,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isVi ? 'NHẬT KÝ BUỔI HỌC' : 'SESSION LOG', style: const TextStyle(fontSize: 14, color: secondaryText)),
            Text(widget.tenHocSinh, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: lightText)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: accentColor),
            onPressed: _loadEvents,
          ),
        ],
      ),
      body: _isLoadingQuyTac
          ? const Center(child: CircularProgressIndicator(color: accentColor))
          : CustomScrollView(
              slivers: [
                // Section: Evaluation Summary
                SliverToBoxAdapter(
                  child: _buildEvaluationSummary(),
                ),

                // Section: Events Recorded
                SliverToBoxAdapter(
                  child: _buildSectionHeader(isVi ? 'CÁC SỰ KIỆN ĐÃ GHI' : 'RECORDED EVENTS'),
                ),
                _buildRecordedEventsList(),

                // Section: Positive Events to add
                SliverToBoxAdapter(
                  child: _buildSectionHeader(isVi ? 'THÊM SỰ KIỆN TÍCH CỰC (+)' : 'ADD POSITIVE EVENT (+)'),
                ),
                _buildQuyTacList(_suKienTichCuc, positiveColor),

                // Section: Negative Events to add
                SliverToBoxAdapter(
                  child: _buildSectionHeader(isVi ? 'THÊM SỰ KIỆN TIÊU CỰC (-)' : 'ADD NEGATIVE EVENT (-)'),
                ),
                _buildQuyTacList(_suKienTieuCuc, negativeColor),
                
                // Section: Note
                SliverToBoxAdapter(
                  child: _buildNhanXetSection(),
                ),
                
                const SliverPadding(padding: EdgeInsets.only(bottom: 30)),
              ],
            ),
    );
  }

  Widget _buildNhanXetSection() {
    final isVi = AppLocalizations.of(context)?.locale.languageCode == 'vi';
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(isVi ? 'NHẬN XÉT CHUNG' : 'GENERAL COMMENTS'),
          const SizedBox(height: 8),
          TextField(
            controller: _nhanXetController,
            maxLines: 3,
            style: const TextStyle(color: lightText),
            decoration: InputDecoration(
              hintText: isVi ? 'Nhập nhận xét về buổi học...' : 'Enter comments about the session...',
              hintStyle: const TextStyle(color: secondaryText),
              fillColor: cardColor,
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  final dg = await _loadEvaluationFuture;
                  final autoText = _danhGiaService.sinhNhanXetTuDong(
                    dg.diemThaiDo ?? 0.0,
                    dg.diemHieuBai ?? 0.0,
                    dg.diemBaiTap ?? 0.0,
                  );
                  setState(() {
                    _nhanXetController.text = autoText;
                  });
                  await _luuNhanXet(autoText);
                  if (mounted) {
                    ToastHelper.showSuccess(context, isVi ? 'Đã tự sinh nhận xét!' : 'Remarks auto-generated!');
                  }
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: accentColor,
                  side: const BorderSide(color: accentColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: Text(isVi ? 'Tự sinh nhận xét' : 'Auto Remark'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  await _luuNhanXet(_nhanXetController.text);
                  if (mounted) {
                    ToastHelper.showSuccess(context, isVi ? 'Đã lưu nhận xét thành công!' : 'Comments saved successfully!');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: darkBackground,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.save, size: 18),
                label: Text(isVi ? 'Lưu nhận xét' : 'Save Comment'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          color: accentColor,
          fontWeight: FontWeight.bold,
          fontSize: 13,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildEvaluationSummary() {
    return FutureBuilder<DanhGiaBuoiHoc>(
      future: _loadEvaluationFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final dg = snapshot.data!;
        final isVi = AppLocalizations.of(context)?.locale.languageCode == 'vi';

        return Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accentColor.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Text(
                isVi ? 'ĐIỂM TỔNG KẾT BUỔI HỌC' : 'SESSION EVALUATION SCORE',
                style: const TextStyle(
                  color: secondaryText,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildScoreItem(isVi ? 'Thái độ' : 'Attitude', dg.diemThaiDo ?? 0.0),
                  _buildScoreItem(isVi ? 'Hiểu bài' : 'Understanding', dg.diemHieuBai ?? 0.0),
                  _buildScoreItem(isVi ? 'Bài tập' : 'Homework', dg.diemBaiTap ?? 0.0),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                isVi ? 'Dữ liệu được tự động lưu sau mỗi thay đổi' : 'Data is automatically saved after each change',
                style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildScoreItem(String label, double score) {
    return Column(
      children: [
        Text(
          score.toStringAsFixed(1),
          style: const TextStyle(
            color: accentColor,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: secondaryText, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildRecordedEventsList() {
    return FutureBuilder<List<SuKienHocTap>>(
      future: _loadEventsFuture,
      builder: (context, snapshot) {
        final isVi = AppLocalizations.of(context)?.locale.languageCode == 'vi';
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                isVi ? 'Chưa có sự kiện nào được ghi trong buổi này.' : 'No events recorded in this session.',
                style: const TextStyle(color: secondaryText, fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final events = snapshot.data!;
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final event = events[index];
              final isPositive = event.diemThayDoi >= 0;
              final color = isPositive ? positiveColor : negativeColor;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Card(
                  color: cardColor,
                  child: ListTile(
                    leading: Icon(
                      isPositive ? Icons.add_circle : Icons.remove_circle,
                      color: color,
                    ),
                    title: Text(event.moTa, style: const TextStyle(color: lightText)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${isPositive ? "+" : ""}${event.diemThayDoi}',
                          style: TextStyle(color: color, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: secondaryText, size: 20),
                          onPressed: () => _xoaSuKien(event.id!),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
            childCount: events.length,
          ),
        );
      },
    );
  }

  Widget _buildQuyTacList(List<QuyTacDiem> quyTacs, Color color) {
    final isVi = AppLocalizations.of(context)?.locale.languageCode == 'vi';
    if (quyTacs.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(isVi ? 'Không có dữ liệu quy tắc.' : 'No rule data.', style: const TextStyle(color: secondaryText)),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final qt = quyTacs[index];
          final isPositive = qt.loaiQuyTac == 'CONG_DIEM';

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: ListTile(
              onTap: () => _themSuKien(qt),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              tileColor: cardColor.withOpacity(0.5),
              leading: Icon(_getIconForMoTa(qt.moTa, isPositive), color: color, size: 22),
              title: Text(qt.moTa, style: const TextStyle(color: lightText, fontSize: 15)),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Text(
                  '${isPositive ? "+" : ""}${qt.diemThayDoi}',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ),
          );
        },
        childCount: quyTacs.length,
      ),
    );
  }
}
