import 'dart:convert';

class EncodingService {
  static String encodeToBase64(String data) {
    final bytes = utf8.encode(data);
    return base64Url.encode(bytes);
  }

  static String decodeFromBase64(String encoded) {
    final bytes = base64Url.decode(encoded);
    return utf8.decode(bytes);
  }
}
