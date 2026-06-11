// Tool: quét các file .dart trong thư mục lib để tìm 'lopId' và (tuỳ chọn) thay bằng 'id_lop'.
// Usage:
//   dart run tools/scan_lopid.dart            -> chỉ liệt kê
//   dart run tools/scan_lopid.dart --apply    -> hiển thị thay đổi dự kiến, yêu cầu xác nhận rồi áp dụng
// LƯU Ý: Đây là thay thế văn bản thô. Kiểm tra kỹ kết quả trước khi commit.

import 'dart:io';

final target = 'lopId';
final replacement = 'id_lop';

void main(List<String> args) async {
  final apply = args.contains('--apply');
  final root = Directory.current;
  final libDir = Directory('${root.path}${Platform.pathSeparator}lib');
  if (!await libDir.exists()) {
    print('Thư mục lib không tồn tại ở: ${libDir.path}');
    exit(1);
  }

  final dartFiles = <File>[];
  await for (final entry in libDir.list(recursive: true, followLinks: false)) {
    if (entry is File && entry.path.endsWith('.dart')) {
      dartFiles.add(entry);
    }
  }

  final occurrences = <String, List<int>>{};

  for (final file in dartFiles) {
    final lines = await file.readAsLines();
    final hits = <int>[];
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].contains(target)) {
        hits.add(i + 1);
      }
    }
    if (hits.isNotEmpty) occurrences[file.path] = hits;
  }

  if (occurrences.isEmpty) {
    print('Không tìm thấy chuỗi "$target" trong thư mục lib.');
    return;
  }

  print('Tìm thấy ${occurrences.length} file có "$target":\n');
  occurrences.forEach((path, lines) {
    print('- $path (dòng: ${lines.join(', ')})');
  });

  if (!apply) {
    print(
      '\nChạy với --apply để áp dụng thay thế "$target" -> "$replacement" (script sẽ yêu cầu xác nhận).',
    );
    return;
  }

  stdout.write(
    '\nBạn đã chọn --apply: script sẽ thực hiện thay thế trong các file trên. Tiếp tục? (y/N): ',
  );
  final confirm = stdin.readLineSync();
  if (confirm?.toLowerCase() != 'y') {
    print('Hủy thao tác.');
    return;
  }

  for (final file in occurrences.keys) {
    final f = File(file);
    final content = await f.readAsString();

    // Preview: chỉ hiển thị vài đoạn trước khi sửa
    final preview = _previewReplace(content, target, replacement, 3);
    print('\n--- Preview $file ---\n$preview\n--- end preview ---\n');

    stdout.write('Áp dụng thay thế vào file này? (y/N): ');
    final ok = stdin.readLineSync();
    if (ok?.toLowerCase() != 'y') {
      print('Bỏ qua $file');
      continue;
    }

    // Backup
    final bak = File('$file.bak');
    if (!await bak.exists()) {
      await bak.writeAsString(content);
      print('Đã tạo backup: ${bak.path}');
    } else {
      print('Backup đã tồn tại: ${bak.path}');
    }

    // Thực hiện thay thế văn bản thô
    final newContent = content.replaceAllMapped(
      RegExp(r'\b' + RegExp.escape(target) + r'\b'),
      (m) => replacement,
    );

    await f.writeAsString(newContent);
    print('Đã thay thế trong $file');
  }

  print(
    '\nHoàn tất. Vui lòng kiểm tra thay đổi và chạy flutter analyzer / build trước khi commit.',
  );
}

String _previewReplace(String content, String from, String to, int maxChunks) {
  final occurrences = <String>[];
  final lines = content.split('\n');
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].contains(from)) {
      final start = (i - 2).clamp(0, lines.length - 1);
      final end = (i + 2).clamp(0, lines.length - 1);
      final chunk = lines.sublist(start, end + 1).join('\n');
      final chunkReplaced = chunk.replaceAll(
        RegExp(r'\b' + RegExp.escape(from) + r'\b'),
        to,
      );
      occurrences.add(
        '... (dòng ${start + 1}-${end + 1}) ...\n$chunk\n----->\n$chunkReplaced\n',
      );
      if (occurrences.length >= maxChunks) break;
    }
  }
  return occurrences.join('\n\n');
}
