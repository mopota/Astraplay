enum DrmType { none, widevine, playready, clearkey }

class DrmConfig {
  final DrmType type;
  final String? licenseUrl;
  final Map<String, String>? headers;

  const DrmConfig({
    this.type = DrmType.none,
    this.licenseUrl,
    this.headers,
  });
}
