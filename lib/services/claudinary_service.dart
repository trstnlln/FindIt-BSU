import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class CloudinaryService {
  static const String cloudName = 'pa77o7a4';
  static const String uploadPreset = 'finditbsu_unsigned';

  /// Uploads an image and returns its public URL.
  static Future<String> uploadImage(File imageFile) async {
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/pa77o7a4/image/upload',
    );

    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = uploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

    final streamed = await request.send().timeout(
      const Duration(seconds: 30),
    );
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Upload failed (${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(response.body);
    return data['secure_url'] as String;
  }
}