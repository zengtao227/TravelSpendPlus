import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Stores one compressed, app-local photo per trip, keyed by trip id.
/// Deliberately not a database column — the file's presence at the
/// deterministic path returned by [photoFile] IS the "does this trip have a
/// photo" state, so nothing else needs to reference it.
class TripPhotoStore {
  // Long side capped at this many pixels — plenty for a thumbnail/header
  // image, and small enough that every photo this app stores stays under
  // ~100KB regardless of what the original camera/gallery file weighed.
  static const int _maxDimension = 640;
  static const int _jpegQuality = 80;

  // Memoized rather than calling getApplicationDocumentsDirectory() fresh
  // on every operation — one lookup per app run instead of one per photo
  // read/write/delete.
  static Future<Directory>? _photosDirFuture;

  /// Test-only: clears the memoized directory so a new
  /// FakePathProviderPlatform installed by a later test's setUp actually
  /// takes effect, instead of every test after the first reusing whichever
  /// directory got memoized first.
  @visibleForTesting
  static void resetForTesting() {
    _photosDirFuture = null;
  }

  static Future<Directory> _photosDir() {
    return _photosDirFuture ??= () async {
      final dir = await getApplicationDocumentsDirectory();
      final photosDir = Directory(p.join(dir.path, 'trip_photos'));
      if (!await photosDir.exists()) await photosDir.create(recursive: true);
      return photosDir;
    }();
  }

  static Future<File> photoFile(String tripId) async {
    final photosDir = await _photosDir();
    return File(p.join(photosDir.path, '$tripId.jpg'));
  }

  static Future<bool> hasPhoto(String tripId) async {
    final file = await photoFile(tripId);
    return file.exists();
  }

  /// Reads the image at [sourcePath] (e.g. an image_picker result),
  /// downsizes it so neither side exceeds [_maxDimension], re-encodes it as
  /// a JPEG at [_jpegQuality], and overwrites this trip's stored photo with
  /// the result — the app never keeps a full-resolution copy of whatever
  /// was picked, however large the original file was.
  static Future<void> saveFromPath(String tripId, String sourcePath) async {
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
    final file = await photoFile(tripId);
    await file.writeAsBytes(jpg);
  }

  static Future<void> delete(String tripId) async {
    final file = await photoFile(tripId);
    if (await file.exists()) await file.delete();
  }

  /// Used by backup export — null when the trip has no stored photo, so the
  /// backup JSON simply omits the key rather than storing an empty string.
  static Future<String?> readBase64(String tripId) async {
    final file = await photoFile(tripId);
    if (!await file.exists()) return null;
    return base64Encode(await file.readAsBytes());
  }

  /// Used by backup import. Writes the bytes as-is (already compressed by
  /// whichever app produced the backup) rather than re-running them through
  /// [saveFromPath]'s decode/resize/re-encode — that would just lose quality
  /// a second time for no benefit.
  static Future<void> writeBase64(String tripId, String base64Data) async {
    final file = await photoFile(tripId);
    await file.writeAsBytes(base64Decode(base64Data));
  }
}
