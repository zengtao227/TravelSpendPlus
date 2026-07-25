import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:travelspendplus/services/trip_photo_store.dart';

import '../test_helpers/fake_path_provider.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('trip_photo_store_test');
    FakePathProviderPlatform.install(tempDir.path);
    TripPhotoStore.resetForTesting();
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  // A tiny valid JPEG, generated on the fly rather than checked in as a
  // binary fixture — a 300x300 solid-color image is plenty to exercise
  // decode/resize/re-encode.
  Future<String> makeSourceJpeg({int width = 300, int height = 300}) async {
    final image = img.Image(width: width, height: height);
    img.fill(image, color: img.ColorRgb8(200, 100, 50));
    final bytes = img.encodeJpg(image);
    final file = File('${tempDir.path}/source.jpg');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  test('hasPhoto is false before any photo is saved', () async {
    expect(await TripPhotoStore.hasPhoto('t1'), isFalse);
  });

  test('saveFromPath then hasPhoto/photoFile round-trips a stored photo', () async {
    final sourcePath = await makeSourceJpeg();
    await TripPhotoStore.saveFromPath('t1', sourcePath);

    expect(await TripPhotoStore.hasPhoto('t1'), isTrue);
    final file = await TripPhotoStore.photoFile('t1');
    expect(await file.exists(), isTrue);
    expect(await file.length(), greaterThan(0));
  });

  test('saveFromPath downsizes an oversized image to the max dimension', () async {
    final sourcePath = await makeSourceJpeg(width: 2000, height: 1000);
    await TripPhotoStore.saveFromPath('t1', sourcePath);

    final file = await TripPhotoStore.photoFile('t1');
    final decoded = img.decodeImage(await file.readAsBytes())!;
    expect(decoded.width, 640);
    expect(decoded.height, 320);
  });

  test('delete removes a stored photo', () async {
    await TripPhotoStore.saveFromPath('t1', await makeSourceJpeg());
    expect(await TripPhotoStore.hasPhoto('t1'), isTrue);

    await TripPhotoStore.delete('t1');
    expect(await TripPhotoStore.hasPhoto('t1'), isFalse);
  });

  test('delete on a trip with no stored photo does not throw', () async {
    await TripPhotoStore.delete('nonexistent');
  });

  test('readBase64 returns null for a trip with no stored photo', () async {
    expect(await TripPhotoStore.readBase64('t1'), isNull);
  });

  test('readBase64 then writeBase64 round-trips the exact same bytes to a different trip',
      () async {
    await TripPhotoStore.saveFromPath('t1', await makeSourceJpeg());
    final originalBytes = await (await TripPhotoStore.photoFile('t1')).readAsBytes();

    final base64 = await TripPhotoStore.readBase64('t1');
    await TripPhotoStore.writeBase64('t2', base64!);

    final copiedBytes = await (await TripPhotoStore.photoFile('t2')).readAsBytes();
    expect(copiedBytes, originalBytes);
  });

  test('two different trips get independent photo files', () async {
    await TripPhotoStore.saveFromPath('t1', await makeSourceJpeg());
    expect(await TripPhotoStore.hasPhoto('t1'), isTrue);
    expect(await TripPhotoStore.hasPhoto('t2'), isFalse);
  });
}
