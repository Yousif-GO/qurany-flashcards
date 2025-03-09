import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';

class AudioService {
  static const String BASE_URL = 'https://everyayah.com/data/Hudhaify_32kbps/';

  static Future<String> getAudioPath(String surah, String ayah,
      [String reciter = 'Hudhaify_32kbps']) async {
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/audio/$reciter';

    // Create directory if it doesn't exist
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final audioFile = '$path/${surah}${ayah}.mp3';
    final file = File(audioFile);

    if (!await file.exists()) {
      try {
        // Download the file
        final url = 'https://everyayah.com/data/$reciter/${surah}${ayah}.mp3';
        final response = await http.get(Uri.parse(url));

        if (response.statusCode == 200) {
          await file.writeAsBytes(response.bodyBytes);
        } else {
          print('Failed to download audio: ${response.statusCode}');
        }
      } catch (e) {
        print('Error downloading audio: $e');
      }
    }

    return audioFile;
  }

  static Future<bool> isAudioFileExists(String surah, String ayah) async {
    final dir = await getApplicationDocumentsDirectory();
    final fileName = '${surah.padLeft(3, '0')}${ayah.padLeft(3, '0')}.mp3';
    final filePath = '${dir.path}/audio_files_Hudhaify/$fileName';
    return File(filePath).exists();
  }
}
