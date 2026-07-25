import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Writes [content] to a file named [filename] in the app's temp directory
/// and returns its full path — the file this returns is what gets handed to
/// [shareFile] (the OS share sheet needs a real file on disk, not a string).
Future<String> writeTempFile(String filename, String content) async {
  final dir = await getTemporaryDirectory();
  final file = File(p.join(dir.path, filename));
  await file.writeAsString(content);
  return file.path;
}

/// Opens the OS share sheet for the file at [path] (Files app, Drive,
/// messaging apps, etc. — whatever the user picks). This is the standard
/// Flutter pattern for "export a file" that avoids requesting storage
/// permissions (see the design spec's technical-approach comparison).
Future<void> shareFile(String path, {String? subject}) async {
  // share_plus's static Share.shareXFiles is deprecated as of 13.x in favor
  // of the SharePlus.instance.share(ShareParams(...)) singleton API.
  await SharePlus.instance.share(ShareParams(files: [XFile(path)], subject: subject));
}

/// Opens the OS file picker restricted to `.json` files and returns the
/// picked file's *content* (not just its path — the only thing any caller
/// in this app ever does with the path is immediately read it), or `null`
/// if the user cancelled.
Future<String?> pickJsonFile() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['json'],
  );
  if (result == null || result.files.isEmpty) return null;
  final path = result.files.single.path;
  if (path == null) return null;
  return File(path).readAsString();
}
