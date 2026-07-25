import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:travelspendplus/services/expense_photo_store.dart';

import '../test_helpers/fake_path_provider.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('expense_photo_store_test');
    FakePathProviderPlatform.install(tempDir.path);
    ExpensePhotoStore.resetForTesting();
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Future<String> makeSourceJpeg({int width = 300, int height = 300}) async {
    final image = img.Image(width: width, height: height);
    img.fill(image, color: img.ColorRgb8(200, 100, 50));
    final bytes = img.encodeJpg(image);
    final file = File('${tempDir.path}/source.jpg');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  test('hasPhoto is false before any photo is saved', () async {
    expect(await ExpensePhotoStore.hasPhoto('e1'), isFalse);
  });

  test('saveFromPath then hasPhoto/photoFile round-trips a stored photo', () async {
    final sourcePath = await makeSourceJpeg();
    await ExpensePhotoStore.saveFromPath('e1', sourcePath);

    expect(await ExpensePhotoStore.hasPhoto('e1'), isTrue);
    final file = await ExpensePhotoStore.photoFile('e1');
    expect(await file.exists(), isTrue);
    expect(await file.length(), greaterThan(0));
  });

  test('saveFromPath downsizes an oversized image to the max dimension', () async {
    final sourcePath = await makeSourceJpeg(width: 2000, height: 1000);
    await ExpensePhotoStore.saveFromPath('e1', sourcePath);

    final file = await ExpensePhotoStore.photoFile('e1');
    final decoded = img.decodeImage(await file.readAsBytes())!;
    expect(decoded.width, 640);
    expect(decoded.height, 320);
  });

  test('delete removes a stored photo', () async {
    await ExpensePhotoStore.saveFromPath('e1', await makeSourceJpeg());
    expect(await ExpensePhotoStore.hasPhoto('e1'), isTrue);

    await ExpensePhotoStore.delete('e1');
    expect(await ExpensePhotoStore.hasPhoto('e1'), isFalse);
  });

  test('delete on an expense with no stored photo does not throw', () async {
    await ExpensePhotoStore.delete('nonexistent');
  });

  test('readBase64 returns null for an expense with no stored photo', () async {
    expect(await ExpensePhotoStore.readBase64('e1'), isNull);
  });

  test('readBase64 then writeBase64 round-trips the exact same bytes to a different expense',
      () async {
    await ExpensePhotoStore.saveFromPath('e1', await makeSourceJpeg());
    final originalBytes = await (await ExpensePhotoStore.photoFile('e1')).readAsBytes();

    final base64 = await ExpensePhotoStore.readBase64('e1');
    await ExpensePhotoStore.writeBase64('e2', base64!);

    final copiedBytes = await (await ExpensePhotoStore.photoFile('e2')).readAsBytes();
    expect(copiedBytes, originalBytes);
  });

  test('two different expenses get independent photo files', () async {
    await ExpensePhotoStore.saveFromPath('e1', await makeSourceJpeg());
    expect(await ExpensePhotoStore.hasPhoto('e1'), isTrue);
    expect(await ExpensePhotoStore.hasPhoto('e2'), isFalse);
  });
}
