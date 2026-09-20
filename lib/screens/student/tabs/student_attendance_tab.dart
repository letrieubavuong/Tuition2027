import 'package:flutter/material.dart';

import '../../../models/hs.dart';
import '../../../widgets/bao_cao_diem_danh_widget.dart';

class StudentAttendanceTab extends StatelessWidget {
  final HS hocSinh;
  final int refreshTrigger;

  const StudentAttendanceTab({
    super.key,
    required this.hocSinh,
    required this.refreshTrigger,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: BaoCaoDiemDanhWidget(
        hocSinh: hocSinh,
        refreshTrigger: refreshTrigger,
      ),
    );
  }
}
