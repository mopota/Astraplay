import 'dart:io';
import 'dart:typed_data';

class OpenSubtitlesHasher {
  static Future<String> computeHash(File file) async {
    final int size = await file.length();
    int hash = size;

    final RandomAccessFile raf = await file.open();
    try {
      // First 64KB
      final Uint8List first64k = await raf.read(64 * 1024);
      hash = _computeChecksum(first64k, hash);

      // Last 64KB
      final int startLast = size - (64 * 1024);
      await raf.setPosition(startLast < 0 ? 0 : startLast);
      final Uint8List last64k = await raf.read(64 * 1024);
      hash = _computeChecksum(last64k, hash);
    } finally {
      await raf.close();
    }

    return hash.toUnsigned(64).toRadixString(16).padLeft(16, '0');
  }

  static int _computeChecksum(Uint8List data, int currentHash) {
    final ByteData byteData = ByteData.view(data.buffer);
    int hash = currentHash;
    for (int i = 0; i < data.length; i += 8) {
      if (i + 8 <= data.length) {
        hash += byteData.getUint64(i, Endian.little);
      }
    }
    return hash;
  }
}
