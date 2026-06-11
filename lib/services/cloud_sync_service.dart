import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../utils/db.dart';
import 'dart:developer' as developer;

class CloudSyncService {
  static final CloudSyncService instance = CloudSyncService._init();
  
  bool get isInitialized => Firebase.apps.isNotEmpty;
  
  FirebaseAuth get _auth {
    if (!isInitialized) throw StateError('Firebase has not been initialized. Please add google-services.json.');
    return FirebaseAuth.instance;
  }
  
  FirebaseStorage get _storage {
    if (!isInitialized) throw StateError('Firebase has not been initialized. Please add google-services.json.');
    return FirebaseStorage.instance;
  }

  CloudSyncService._init();

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Đăng ký tài khoản mới
  Future<UserCredential?> dangKy(String email, String password) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } catch (e) {
      developer.log('❌ Lỗi đăng ký tài khoản: $e', name: 'CloudSyncService');
      rethrow;
    }
  }

  // Đăng nhập
  Future<UserCredential?> dangNhap(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } catch (e) {
      developer.log('❌ Lỗi đăng nhập: $e', name: 'CloudSyncService');
      rethrow;
    }
  }

  // Đăng xuất
  Future<void> dangXuat() async {
    await _auth.signOut();
  }

  // Sao lưu Database (.db) lên Firebase Storage
  Future<bool> saoLuuLenDamMay() async {
    final user = currentUser;
    if (user == null) {
      developer.log('⚠️ Chưa đăng nhập để sao lưu.', name: 'CloudSyncService');
      return false;
    }

    try {
      // Đóng tạm thời kết nối DB để đảm bảo file .db không bị lock/corruption
      await DBHelper.instance.close();

      final dbPath = await getDatabasesPath();
      final sourcePath = p.join(dbPath, 'quan_ly_hs.db');
      final file = File(sourcePath);

      if (!await file.exists()) {
        developer.log('❌ File database gốc không tồn tại!', name: 'CloudSyncService');
        await DBHelper.instance.database; // Reopen DB
        return false;
      }

      // Upload lên Firebase Storage tại đường dẫn: users/{uid}/quan_ly_hs.db
      final ref = _storage.ref().child('users/${user.uid}/quan_ly_hs.db');
      await ref.putFile(file);

      developer.log('✅ Sao lưu dữ liệu lên đám mây thành công!', name: 'CloudSyncService');
      
      // Mở lại DB
      await DBHelper.instance.database;
      return true;
    } catch (e) {
      developer.log('❌ Lỗi khi tải file database lên đám mây: $e', name: 'CloudSyncService');
      await DBHelper.instance.database; // Reopen DB
      return false;
    }
  }

  // Khôi phục Database (.db) từ Firebase Storage
  Future<bool> khoiPhucTuDamMay() async {
    final user = currentUser;
    if (user == null) {
      developer.log('⚠️ Chưa đăng nhập để khôi phục.', name: 'CloudSyncService');
      return false;
    }

    try {
      final ref = _storage.ref().child('users/${user.uid}/quan_ly_hs.db');
      
      final dbPath = await getDatabasesPath();
      final targetPath = p.join(dbPath, 'quan_ly_hs.db');
      final tempFile = File('$targetPath.temp');

      // Tải file về file tạm
      await ref.writeToFile(tempFile);

      // Đóng kết nối Database hiện tại
      await DBHelper.instance.close();

      // Ghi đè file cũ bằng file tạm mới tải về
      final originalFile = File(targetPath);
      if (await originalFile.exists()) {
        await originalFile.delete();
      }
      await tempFile.rename(targetPath);

      developer.log('✅ Khôi phục dữ liệu từ đám mây thành công!', name: 'CloudSyncService');
      
      // Mở lại DB
      await DBHelper.instance.database;
      return true;
    } catch (e) {
      developer.log('❌ Lỗi khi khôi phục database từ đám mây: $e', name: 'CloudSyncService');
      await DBHelper.instance.database; // Reopen DB
      return false;
    }
  }
}
