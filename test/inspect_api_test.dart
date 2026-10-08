import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('explore Dart File open options and RandomAccessFile', () async {
    final tempDir = await Directory.systemTemp.createTemp('mode_explore_');
    final file = File('${tempDir.path}/test.bin');
    await file.writeAsBytes([1, 2, 3, 4, 5, 6, 7, 8]);

    // Let's check FileMode constructors or subclasses or private fields
    print('FileMode: ${FileMode}');

    // Let's test if there is any other way in dart:io
    await tempDir.delete(recursive: true);
  });
}
