import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Stores one compressed, app-local photo per expense, keyed by expense id.
/// Deliberately not a database column — the file's presence at the
/// deterministic path returned by [photoFile] IS the "does this expense have
/// a photo" state, so nothing else needs to reference it. Identical scheme
/// to TripPhotoStore, just keyed by expense id and a different subdirectory.
class ExpensePhotoStore {
  static const int _maxDimension = 640;
  static const int _jpegQuality = 80;

  static Future<Directory>? _photosDirFuture;

  @visibleForTesting
  static void resetForTesting() {
    _photosDirFuture = null;
  }

  static Future<Directory> _photosDir() {
    return _photosDirFuture ??= () async {
      final dir = await getApplicationDocumentsDirectory();
      final photosDir = Directory(p.join(dir.path, 'expense_photos'));
      if (!await photosDir.exists()) await photosDir.create(recursive: true);
      return photosDir;
    }();
  }

  static Future<File> photoFile(String expenseId) async {
    final photosDir = await _photosDir();
    return File(p.join(photosDir.path, '$expenseId.jpg'));
  }

  static Future<bool> hasPhoto(String expenseId) async {
    final file = await photoFile(expenseId);
    return file.exists();
  }

  static Future<void> saveFromPath(String expenseId, String sourcePath) async {
    final bytes = await File(sourcePath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return;
    final needsResize = decoded.width > _maxDimension || decoded.height > _maxDimension;
    final resized = needsResize
        ? img.copyResize(
            decoded,
            width: decoded.width >= decoded.height ? _maxDimension : null,
            height: decoded.height > decoded.width ? _maxDimension : null,
          )
        : decoded;
    final jpg = img.encodeJpg(resized, quality: _jpegQuality);
    final file = await photoFile(expenseId);
    await file.writeAsBytes(jpg);
  }

  static Future<void> delete(String expenseId) async {
    final file = await photoFile(expenseId);
    if (await file.exists()) await file.delete();
  }

  static Future<String?> readBase64(String expenseId) async {
    final file = await photoFile(expenseId);
    if (!await file.exists()) return null;
    return base64Encode(await file.readAsBytes());
  }

  static Future<void> writeBase64(String expenseId, String base64Data) async {
    final file = await photoFile(expenseId);
    await file.writeAsBytes(base64Decode(base64Data));
  }
}
