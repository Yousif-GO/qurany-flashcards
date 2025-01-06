import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'dart:html' as html;

class VersionService {
  static Future<void> initialize() async {
    final remoteConfig = FirebaseRemoteConfig.instance;
    await remoteConfig.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(minutes: 1),
      minimumFetchInterval: Duration.zero,
    ));
    await remoteConfig.fetchAndActivate();
  }

  static Future<void> checkForUpdate(BuildContext context) async {
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.fetchAndActivate();

      final currentVersion = remoteConfig.getString('app_version');
      if (currentVersion.isNotEmpty) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text('Update Available'),
            content: Text('Please refresh the page to get the latest version.'),
            actions: [
              TextButton(
                child: Text('Refresh'),
                onPressed: () => html.window.location.reload(),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      print('Error checking version: $e');
    }
  }
}
