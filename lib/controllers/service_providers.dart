import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../services/lop_service.dart';
import '../services/lop_hoc_sinh_service.dart';
import '../services/lich_hoc_service.dart';
import '../services/lich_hoc_chung_service.dart';
import '../services/v2/session_generation_service_v2.dart';
import '../services/v2/roster_service_v2.dart';
import '../services/v2/session_credit_service_v2.dart';
import '../services/v2/tuition_service_v2.dart';
import '../repositories/v2/hoc_sinh_repository_v2.dart';
import '../repositories/v2/lop_repository_v2.dart';

part 'service_providers.g.dart';

@riverpod
LopService lopService(LopServiceRef ref) => LopService();

@riverpod
LopRepositoryV2 lopRepositoryV2(LopRepositoryV2Ref ref) => LopRepositoryV2();

@riverpod
HocSinhRepositoryV2 hocSinhRepositoryV2(HocSinhRepositoryV2Ref ref) => HocSinhRepositoryV2();

@riverpod
TuitionServiceV2 tuitionServiceV2(TuitionServiceV2Ref ref) => TuitionServiceV2();

@riverpod
RosterServiceV2 rosterServiceV2(RosterServiceV2Ref ref) => RosterServiceV2();
