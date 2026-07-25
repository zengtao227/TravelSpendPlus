import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// Points `path_provider` at a real temp directory during tests, so any
/// code that calls `getApplicationDocumentsDirectory()` (e.g.
/// TripPhotoStore) works without a platform channel. Call
/// [FakePathProviderPlatform.install] once in a test file's `setUp`.
class FakePathProviderPlatform extends PathProviderPlatform {
  final String documentsPath;
  FakePathProviderPlatform(this.documentsPath);

  static void install(String documentsPath) {
    PathProviderPlatform.instance = FakePathProviderPlatform(documentsPath);
  }

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}
