import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'database_service.dart';

class MediaCacheService {
  static final MediaCacheService _instance = MediaCacheService._internal();
  factory MediaCacheService() => _instance;
  MediaCacheService._internal();

  final DatabaseService _db = DatabaseService();

  Future<String?> downloadAndSaveMedia(String url, String messageId) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final directory = await getApplicationDocumentsDirectory();
        final mediaDir = Directory('${directory.path}/media');
        if (!await mediaDir.exists()) {
          await mediaDir.create(recursive: true);
        }

        final fileExtension = url.split('.').last.split('?').first; 
        final safeExt = fileExtension.isNotEmpty ? fileExtension : 'jpg';
        final filePath = '${mediaDir.path}/$messageId.$safeExt';
        
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        // Update local database to link the file path to the message
        await _db.updateMessageLocalPath(messageId, filePath);

        return filePath;
      } else {
        print('Media download failed with status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error downloading media: $e');
      return null;
    }
  }

  Future<File?> getLocalMediaFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      return file;
    }
    return null;
  }
}
