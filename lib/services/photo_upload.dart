import 'dart:typed_data';

import 'package:http/http.dart' as http;

class PhotoFormat {
  final String extension;
  final String mime;
  const PhotoFormat(this.extension, this.mime);
}

PhotoFormat validateReportPhoto(Uint8List bytes) {
  if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
    throw const FormatException('Choose a photo smaller than 5 MB.');
  }
  if (bytes.length >= 3 &&
      bytes[0] == 255 &&
      bytes[1] == 216 &&
      bytes[2] == 255) {
    return const PhotoFormat('jpg', 'image/jpeg');
  }
  if (bytes.length >= 8 &&
      [
        137,
        80,
        78,
        71,
        13,
        10,
        26,
        10,
      ].asMap().entries.every((e) => bytes[e.key] == e.value)) {
    return const PhotoFormat('png', 'image/png');
  }
  if (bytes.length >= 12 &&
      String.fromCharCodes(bytes.take(4)) == 'RIFF' &&
      String.fromCharCodes(bytes.skip(8).take(4)) == 'WEBP') {
    return const PhotoFormat('webp', 'image/webp');
  }
  throw const FormatException('Choose a JPEG, PNG, or WebP photo.');
}

class ProgressMultipartRequest extends http.MultipartRequest {
  final void Function(double)? onProgress;
  ProgressMultipartRequest(super.method, super.url, {this.onProgress});
  @override
  http.ByteStream finalize() {
    final total = contentLength;
    var sent = 0;
    return http.ByteStream(
      super.finalize().map((chunk) {
        sent += chunk.length;
        onProgress?.call(total == 0 ? 0 : (sent / total).clamp(0, 1));
        return chunk;
      }),
    );
  }
}
