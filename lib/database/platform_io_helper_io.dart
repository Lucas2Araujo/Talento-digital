import 'dart:io';
import 'package:flutter/foundation.dart';

void ensureDirectoryExists(String path) {
  if (!kIsWeb) {
    final dir = Directory(path);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
  }
}
