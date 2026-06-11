import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../services/lop_service.dart';
import '../services/lop_hoc_sinh_service.dart';
import '../services/lich_hoc_service.dart';
import '../services/lich_hoc_chung_service.dart';
import '../services/report_service.dart';
import '../services/diem_danh_service.dart';

part 'service_providers.g.dart';

@riverpod
LopService lopService(LopServiceRef ref) => LopService();

@riverpod
LopHocSinhService lopHocSinhService(LopHocSinhServiceRef ref) => LopHocSinhService();

@riverpod
LichHocService lichHocService(LichHocServiceRef ref) => LichHocService();

@riverpod
LichHocChungService lichHocChungService(LichHocChungServiceRef ref) => LichHocChungService();

@riverpod
ReportService reportService(ReportServiceRef ref) => ReportService();

@riverpod
DiemDanhService diemDanhService(DiemDanhServiceRef ref) => DiemDanhService();