import 'package:flutter/material.dart';

import '../models/hs.dart';
import 'student/student_detail_page.dart';

export 'student/student_detail_page.dart';

class HSDetail extends StatelessWidget {
  final HS hocSinh;
  final int initialTabIndex;

  const HSDetail({super.key, required this.hocSinh, this.initialTabIndex = 0});

  @override
  Widget build(BuildContext context) {
    return StudentDetailPage(
      hocSinh: hocSinh,
      initialTabIndex: initialTabIndex,
    );
  }
}
