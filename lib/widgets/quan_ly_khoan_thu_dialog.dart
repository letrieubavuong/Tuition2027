import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/khoan_thu.dart';
import '../models/lop.dart';
import '../services/khoan_thu_service.dart';

class QuanLyKhoanThuDialog extends StatefulWidget {
  final List<Lop> lops;
  final String thang;

  const QuanLyKhoanThuDialog({
    super.key,
    required this.lops,
    required this.thang,
  });

  @override
  State<QuanLyKhoanThuDialog> createState() => _QuanLyKhoanThuDialogState();
}

class _QuanLyKhoanThuDialogState extends State<QuanLyKhoanThuDialog> {
  final _service = KhoanThuService();
  int? _lopId;
  late Future<List<KhoanThu>> _future;
  final _money = NumberFormat('#,##0', 'vi_VN');

  @override
  void initState() {
    super.initState();
    _lopId = widget.lops.isEmpty ? null : widget.lops.first.id;
    _reload();
  }

  void _reload() {
    _future = _lopId == null
        ? Future.value([])
        : _service.layKhoanThu(_lopId!, widget.thang);
  }

  Future<void> _themKhoanThu() async {
    if (_lopId == null) return;
    final name = TextEditingController();
    final amount = TextEditingController();
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thêm khoản thu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Tên khoản thu'),
            ),
            TextField(
              controller: amount,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Số tiền mỗi học sinh',
              ),
            ),
            TextField(
              controller: note,
              decoration: const InputDecoration(labelText: 'Ghi chú'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Tạo'),
          ),
        ],
      ),
    );
    final value = int.tryParse(amount.text) ?? 0;
    if (ok == true && name.text.trim().isNotEmpty && value > 0) {
      await _service.taoKhoanThu(
        idLop: _lopId!,
        thang: widget.thang,
        ten: name.text.trim(),
        soTien: value,
        ghiChu: note.text.trim(),
      );
      if (mounted) setState(_reload);
    }
    name.dispose();
    amount.dispose();
    note.dispose();
  }

  Future<void> _thuTien(KhoanThu charge, KhoanThuHocSinh student) async {
    final controller = TextEditingController(text: student.daDong.toString());
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${charge.ten} - ${student.tenHocSinh}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: 'Đã thu (tối đa ${_money.format(charge.soTien)}đ)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final paid = (int.tryParse(controller.text) ?? 0)
          .clamp(0, charge.soTien)
          .toInt();
      await _service.capNhatThanhToan(
        idKhoanThu: charge.id,
        idHocSinh: student.idHocSinh,
        soTienDaDong: paid,
      );
      if (mounted) setState(_reload);
    }
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: Text('Khoản thu khác - ${widget.thang}'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(onPressed: _themKhoanThu, icon: const Icon(Icons.add)),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: DropdownButtonFormField<int>(
                initialValue: _lopId,
                decoration: const InputDecoration(labelText: 'Lớp'),
                items: widget.lops
                    .map(
                      (lop) =>
                          DropdownMenuItem(value: lop.id, child: Text(lop.ten)),
                    )
                    .toList(),
                onChanged: (value) => setState(() {
                  _lopId = value;
                  _reload();
                }),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<KhoanThu>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Lỗi: ${snapshot.error}'),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () => setState(_reload),
                            child: const Text('Thử lại'),
                          ),
                        ],
                      ),
                    );
                  }
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());
                  final charges = snapshot.data!;
                  if (charges.isEmpty)
                    return const Center(
                      child: Text('Chưa có khoản thu khác trong tháng này.'),
                    );
                  return ListView.builder(
                    itemCount: charges.length,
                    itemBuilder: (context, index) {
                      final charge = charges[index];
                      return ExpansionTile(
                        title: Text(charge.ten),
                        subtitle: Text(
                          'Phải thu ${_money.format(charge.tongPhaiThu)}đ • Đã thu ${_money.format(charge.tongDaThu)}đ • Còn nợ ${_money.format(charge.tongConNo)}đ',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            final isVi =
                                Localizations.localeOf(context).languageCode ==
                                'vi';
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text(
                                  isVi
                                      ? 'Xác nhận xóa khoản thu'
                                      : 'Confirm Delete Charge',
                                ),
                                content: Text(
                                  isVi
                                      ? 'Bạn có chắc chắn muốn xóa khoản thu "${charge.ten}"?\n\n'
                                            'Tổng đã thu: ${_money.format(charge.tongDaThu)} VNĐ'
                                      : 'Are you sure you want to delete "${charge.ten}"?\n\n'
                                            'Total collected: ${_money.format(charge.tongDaThu)} VND',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: Text(isVi ? 'Hủy' : 'Cancel'),
                                  ),
                                  FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                    ),
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: Text(isVi ? 'Xóa' : 'Delete'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await _service.xoaKhoanThu(charge.id);
                              if (mounted) setState(_reload);
                            }
                          },
                        ),
                        children: charge.hocSinhs.map((student) {
                          final debt = charge.soTien - student.daDong;
                          return ListTile(
                            title: Text(student.tenHocSinh),
                            subtitle: Text(
                              'Đã thu ${_money.format(student.daDong)}đ • Còn nợ ${_money.format(debt)}đ',
                            ),
                            trailing: Icon(
                              debt == 0
                                  ? Icons.check_circle
                                  : Icons.payments_outlined,
                            ),
                            onTap: () => _thuTien(charge, student),
                          );
                        }).toList(),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
