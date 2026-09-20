// File: lib/screens/form_hoc_sinh.dart

import 'package:flutter/material.dart';
import '../models/hs.dart';
import '../services/hoc_sinh_service.dart';
import '../widgets/hs_form.dart';

class FormHocSinh extends StatelessWidget {
  final HS? hocSinh;
  const FormHocSinh({super.key, this.hocSinh});

  @override
  Widget build(BuildContext context) {
    return HocSinhFormDialog(
      hocSinh: hocSinh,
      danhSachTruong: const [],
      hsService: HocSinhService(),
    );
  }
}
