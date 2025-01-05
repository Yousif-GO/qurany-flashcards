import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import '../data/surah_data.dart';
import '../services/srs_scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart' as shared_prefs;
import 'package:confetti/confetti.dart';
import 'dart:math' show pi, Random;
import 'package:audioplayers/audioplayers.dart' as audio;
import '../pages/mode_selection_page.dart';
import '../pages/tutorial_page.dart';
import '../services/audio_service.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import '../services/firebase_service.dart';
import '../screens/quran_room_screen.dart';
import 'dart:async'; // Add this import for StreamController
import '../widgets/feedback_dialog.dart';
import '../firebase_options.dart';
import '../services/tajweed_parser.dart';
import '../services/comments_service.dart';
import '../widgets/comments_dialog.dart';
import '../models/comment.dart';

enum AppLanguage {
  arabic,
  english,
  urdu,
  indonesian,
  spanish,
  hindi,
  russian,
  chinese,
  turkish,
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.web,
    );
  } else if (Platform.isAndroid) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.android,
    );
  } else if (Platform.isIOS) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.ios,
    );
  } else {
    await Firebase.initializeApp();
  }
  final prefs = await shared_prefs.SharedPreferences.getInstance();
  final String? savedLanguage = prefs.getString('language');
  final bool hasSeenTutorial = prefs.getBool('has_seen_tutorial') ?? false;
  final bool hasSelectedMode = prefs.getBool('has_selected_mode') ?? false;
  await SRSScheduler().mergeDuplicateItems();

  // Create a stream controller for deep links
  final deepLinkController = StreamController<Map<String, String>>.broadcast();

  // Handle incoming links
  if (Uri.base.hasQuery) {
    final group = Uri.base.queryParameters['group'];
    final khatma = Uri.base.queryParameters['khatma'];
    if (group != null && khatma != null) {
      deepLinkController.add({
        'group': group,
        'khatma': khatma,
      });
    }
  }

  runApp(MyApp(
    initialLanguage: savedLanguage,
    hasSeenTutorial: hasSeenTutorial,
    hasSelectedMode: hasSelectedMode,
    deepLinkStream: deepLinkController.stream,
  ));
}

class MyApp extends StatelessWidget {
  final String? initialLanguage;
  final bool hasSeenTutorial;
  final bool hasSelectedMode;
  final Stream<Map<String, String>>? deepLinkStream;

  const MyApp({
    Key? key,
    this.initialLanguage,
    required this.hasSeenTutorial,
    required this.hasSelectedMode,
    this.deepLinkStream,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Qurany Cards Pro',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        primaryColor: Color(0xFF417D7A),
        scaffoldBackgroundColor: Color(0xFFF9F9F9),
        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xFF417D7A),
          elevation: 0,
        ),
      ),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        // Get the current URL in web
        if (kIsWeb) {
          final uri = Uri.base;

          // Check if it's a join link
          if (uri.path == '/join') {
            return MaterialPageRoute(
              builder: (context) => QuranRoomScreen(
                selectedLanguage: AppLanguage.values.firstWhere(
                  (e) =>
                      e.toString() ==
                      (initialLanguage ?? 'AppLanguage.english'),
                  orElse: () => AppLanguage.english,
                ),
                isGroupReading: true,
                initialValues: {
                  'group': uri.queryParameters['group'] ?? '',
                  'khatma': uri.queryParameters['khatma'] ?? '',
                },
              ),
            );
          }
        }

        // Default route
        return MaterialPageRoute(
          builder: (context) => SimpleList(
            selectedLanguage: AppLanguage.values.firstWhere(
              (e) => e.toString() == (initialLanguage ?? 'AppLanguage.english'),
              orElse: () => AppLanguage.english,
            ),
            isGroupReading: false,
          ),
        );
      },
    );
  }
}

class LanguageSelectionPage extends StatelessWidget {
  final Map<AppLanguage, Map<String, dynamic>> languages = {
    AppLanguage.arabic: {
      'name': 'العربية',
      'nativeName': 'Arabic',
      'flag': '🇸🇦',
      'tafsirFile': 'ar.muyassar.txt',
    },
    AppLanguage.english: {
      'name': 'English',
      'nativeName': 'English',
      'flag': '🇬🇧',
      'tafsirFile': 'ar.muyassar.txt',
    },
    AppLanguage.spanish: {
      'name': 'Español',
      'nativeName': 'Spanish',
      'flag': '🇪🇸',
      'tafsirFile': 'es.garcia.txt',
    },
    AppLanguage.hindi: {
      'name': 'हिंदी',
      'nativeName': 'Hindi',
      'flag': '🇮🇳',
      'tafsirFile': 'hi.farooq.txt',
    },
    AppLanguage.urdu: {
      'name': 'اردو',
      'nativeName': 'Urdu',
      'flag': '🇵🇰',
      'tafsirFile': 'ur.maududi.txt',
    },
    AppLanguage.indonesian: {
      'name': 'Bahasa Indonesia',
      'nativeName': 'Indonesian',
      'flag': '🇮🇩',
      'tafsirFile': 'id.indonesian.txt',
    },
    AppLanguage.russian: {
      'name': 'Русский',
      'nativeName': 'Russian',
      'flag': '🇷🇺',
      'tafsirFile': 'ru.kalam.txt',
    },
    AppLanguage.chinese: {
      'name': '中文',
      'nativeName': 'Chinese',
      'flag': '🇨🇳',
      'tafsirFile': 'zh.jian.txt',
    },
    AppLanguage.turkish: {
      'name': 'Türkçe',
      'nativeName': 'Turkish',
      'flag': '🇹🇷',
      'tafsirFile': 'tr.ozturk.txt',
    },
  };

  LanguageSelectionPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            // Add this wrapper
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Select Your Language',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2B4141),
                    ),
                  ),
                  SizedBox(height: 40),
                  ...languages.entries.map((entry) {
                    return Padding(
                      padding:
                          EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Color(0xFF417D7A),
                          padding: EdgeInsets.symmetric(
                              horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side:
                                BorderSide(color: Color(0xFF417D7A), width: 2),
                          ),
                          minimumSize: Size(double.infinity, 60),
                        ),
                        onPressed: () async {
                          final prefs = await shared_prefs.SharedPreferences
                              .getInstance();
                          await prefs.setString(
                              'language', entry.key.toString());

                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ModeSelectionPage(
                                selectedLanguage: entry.key,
                              ),
                            ),
                          );
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              entry.value['flag'] + ' ' + entry.value['name'],
                              style: TextStyle(
                                fontSize: 18,
                                color: Color(0xFF2B4141),
                              ),
                            ),
                            Text(
                              entry.value['nativeName'],
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF417D7A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SimpleList extends StatefulWidget {
  final AppLanguage selectedLanguage;
  final bool isGroupReading;
  final String? groupName;
  final String? khatmaName;
  final String? userName;

  const SimpleList({
    Key? key,
    required this.selectedLanguage,
    required this.isGroupReading,
    this.groupName,
    this.khatmaName,
    this.userName,
  }) : super(key: key);

  @override
  State<SimpleList> createState() => _SimpleListState();
}

class _SimpleListState extends State<SimpleList> {
  final Map<int, int> _currentAyahNumbers = {};
  final SRSScheduler _srsScheduler = SRSScheduler();
  bool _globalAutoPlayEnabled = true;
  final Map<int, Map<String, dynamic>> _surahInfo = SurahData.surahInfo;
  bool _showFirstWordOnly = false;

  // Add translations map
  final Map<AppLanguage, Map<String, String>> translations = {
    AppLanguage.arabic: {
      'auto_play_enabled': 'تم تفعيل التشغيل التلقائي',
      'auto_play_disabled': 'تم تعطيل التشغيل التلقائي',
      'show_first_word_enabled': 'تم تفعيل وضع إظهار الكلمة الأولى',
      'show_first_word_disabled': 'تم تعطيل وضع إظهار الكلمة الأولى',
      'ayahs_for_review': 'آيات للمراجعة:',
      'page': 'صفحة',
      'toggle_auto_play': 'تبديل التشغيل التلقائي',
      'previous_ayah': 'الآية السابقة',
      'mark_for_review': 'غير صحيح - علامة للمراجعة',
      'remove_from_review': 'صحيح - إزالة من المراجعة',
      'kids_mode_on': '🎉 تم تفعيل وضع الأطفال',
      'kids_mode_off': 'تم إلغاء وضع الأطفال',
      'kids_sound_on': 'مؤثرات صوتية للأطفال مفعلة',
      'kids_sound_off': 'مؤثرات صوتية للأطفال معطلة',
    },
    AppLanguage.english: {
      'auto_play_enabled': 'Audio auto-play enabled',
      'auto_play_disabled': 'Audio auto-play disabled',
      'show_first_word_enabled': 'Show first word mode activated',
      'show_first_word_disabled': 'Show first word mode deactivated',
      'ayahs_for_review': 'Ayahs for review:',
      'page': 'Page',
      'toggle_auto_play': 'Toggle Auto-play',
      'previous_ayah': 'Previous Ayah',
      'mark_for_review': 'Incorrect - Mark for review',
      'remove_from_review': 'Correct - Remove from review',
      'kids_mode_on': 'Kids Mode Activated! 🎉',
      'kids_mode_off': 'Kids Mode Deactivated',
      'kids_sound_on': 'Kids Sound Effects On',
      'kids_sound_off': 'Kids Sound Effects Off',
    },
    AppLanguage.spanish: {
      'auto_play_enabled': 'Reproducción automática activada',
      'auto_play_disabled': 'Reproducción automática desactivada',
      'show_first_word_enabled': 'Modo mostrar primera palabra activado',
      'show_first_word_disabled': 'Modo mostrar primera palabra desactivado',
      'ayahs_for_review': 'Aleyas para revisar:',
      'page': 'Página',
      'toggle_auto_play': 'Alternar reproducción automática',
      'previous_ayah': 'Aleya anterior',
      'mark_for_review': 'Incorrecto - Marcar para revisar',
      'remove_from_review': 'Correcto - Quitar de revisión',
      'kids_mode_on': '¡Modo Niños Activado! 🎉',
      'kids_mode_off': 'Modo Niños Desactivado',
      'kids_sound_on': 'Efectos de sonido para niños activados',
      'kids_sound_off': 'Efectos de sonido para niños desactivados',
    },
    AppLanguage.hindi: {
      'auto_play_enabled': 'ऑटो-प्ले सक्रिय किया गया',
      'auto_play_disabled': 'ऑटो-प्ले निष्क्रिय किया गया',
      'show_first_word_enabled': 'पहला शब्द दिखाने का मोड सक्रिय',
      'show_first_word_disabled': 'पहला शब्द दिखाने का मोड निष्क्रिय',
      'ayahs_for_review': 'समीक्षा के लिए आयतें:',
      'page': 'पृष्ठ',
      'toggle_auto_play': 'ऑटो-प्ले टॉगल करें',
      'previous_ayah': 'पिछली आयत',
      'mark_for_review': 'गलत - समीक्षा के लिए चिह्नित करें',
      'remove_from_review': 'सही - समीक्षा से हटाएं',
      'kids_mode_on': 'बच्चों का मोड सक्रिय! 🎉',
      'kids_mode_off': 'बच्चों का मोड निष्क्रिय',
      'kids_sound_on': 'आवाज प्रभाव उच्च है',
      'kids_sound_off': 'आवाज प्रभाव कम है',
    },
    AppLanguage.russian: {
      'auto_play_enabled': 'Автовоспроизведение включено',
      'auto_play_disabled': 'Автовоспроизведение выключено',
      'show_first_word_enabled': 'Режим показа первого слова активирован',
      'show_first_word_disabled': 'Режим показа первого слова деактивирован',
      'ayahs_for_review': 'Аяты для повторения:',
      'page': 'Страница',
      'toggle_auto_play': 'Переключить автовоспроизведение',
      'previous_ayah': 'Предыдущий аят',
      'mark_for_review': 'Неверно - Отметить для повторения',
      'remove_from_review': 'Верно - Убрать из повторения',
      'kids_mode_on': 'Детский режим активирован! 🎉',
      'kids_mode_off': 'Детский режим деактивирован',
      'kids_sound_on': 'Включены звуковые эффекты для детей',
      'kids_sound_off': 'Выключены звуковые эффекты для детей',
    },
    AppLanguage.chinese: {
      'auto_play_enabled': '自动播放已启用',
      'auto_play_disabled': '自动播放已禁用',
      'show_first_word_enabled': '显示首词模式已激活',
      'show_first_word_disabled': '显示首词模式已停用',
      'ayahs_for_review': '需要复习的经文：',
      'page': '页',
      'toggle_auto_play': '切换自动播放',
      'previous_ayah': '上一节经文',
      'mark_for_review': '错误 - 标记为复习',
      'remove_from_review': '正确 - 从复习中移除',
      'kids_mode_on': '儿童模式已启用！🎉',
      'kids_mode_off': '儿童模式已关闭',
      'kids_sound_on': '儿童声音效果已启用',
      'kids_sound_off': '儿童声音效果已关闭',
    },
    AppLanguage.turkish: {
      'auto_play_enabled': 'Otomatik oynatma etkin',
      'auto_play_disabled': 'Otomatik oynatma devre dışı',
      'show_first_word_enabled': 'İlk kelime gösterme modu etkin',
      'show_first_word_disabled': 'İlk kelime gösterme modu devre dışı',
      'ayahs_for_review': 'Tekrar için ayetler:',
      'page': 'Sayfa',
      'toggle_auto_play': 'Otomatik oynatmayı değiştir',
      'previous_ayah': 'Önceki ayet',
      'mark_for_review': 'Yanlış - Tekrar için işaretle',
      'remove_from_review': 'Doğru - Tekrardan kaldır',
      'kids_mode_on': 'Çocuk Modu Etkinleştirildi! 🎉',
      'kids_mode_off': 'Çocuk Modu Devre Dışı',
      'kids_sound_on': 'Çocuk ses efektleri aktif',
      'kids_sound_off': 'Çocuk ses efektleri devre dışı',
    },
    AppLanguage.urdu: {
      'auto_play_enabled': 'آٹو-پلے فعال کر دیا گیا',
      'auto_play_disabled': 'آٹو-پلے غیر فعال کر دیا گیا',
      'show_first_word_enabled': 'پہلا الفاظ دکھانے کا موڈ فعال',
      'show_first_word_disabled': 'پہلا الفاظ دکھانے کا موڈ غیر فعال',
      'ayahs_for_review': 'جدول کے لئے آیتیں:',
      'page': 'صفحہ',
      'toggle_auto_play': 'آٹو-پلے ٹوگل کریں',
      'previous_ayah': 'پچھلی آیت',
      'mark_for_review': 'غلط - جدول کے لئے نشان لگائیں',
      'remove_from_review': 'صحیح - جدول سے ہٹا دیں',
      'kids_mode_on': '🎉 بچوں کا موڈ فعال',
      'kids_mode_off': 'بچوں کا موڈ غیر فعال',
      'kids_sound_on': 'بچوں کے صوتی اثر مفعل ہیں',
      'kids_sound_off': 'بچوں کے صوتی اثر معطل ہیں',
    },
    AppLanguage.indonesian: {
      'auto_play_enabled': 'Pemutaran otomatis diaktifkan',
      'auto_play_disabled': 'Pemutaran otomatis dinonaktifkan',
      'show_first_word_enabled': 'Mode tampilkan kata pertama diaktifkan',
      'show_first_word_disabled': 'Mode tampilkan kata pertama dinonaktifkan',
      'ayahs_for_review': 'Ayat untuk ditinjau:',
      'page': 'Halaman',
      'toggle_auto_play': 'Beralih Pemutaran Otomatis',
      'previous_ayah': 'Ayat Sebelumnya',
      'mark_for_review': 'Tidak Benar - Tandai untuk ditinjau',
      'remove_from_review': 'Benar - Hapus dari tinjauan',
      'kids_mode_on': 'Mode Anak Diaktifkan! 🎉',
      'kids_mode_off': 'Mode Anak Dinonaktifkan',
      'kids_sound_on': 'Suara Efek untuk Anak Diaktifkan',
      'kids_sound_off': 'Suara Efek untuk Anak Dinonaktifkan',
    },
  };

  // Add helper method to get translations
  String getTranslation(String key) {
    return translations[widget.selectedLanguage]?[key] ??
        translations[AppLanguage.english]![key]!;
  }

  Map<int, List<int>> _getSurahPages() {
    Map<int, List<int>> surahPages = {};

    for (int surahNum = 1; surahNum <= 114; surahNum++) {
      int startPage = _surahInfo[surahNum]!['start_page'];
      int endPage =
          surahNum < 114 ? _surahInfo[surahNum + 1]!['start_page'] - 1 : 604;

      surahPages[surahNum] =
          List.generate(endPage - startPage + 1, (index) => startPage + index);
    }

    return surahPages;
  }

  // Add this method to get all due pages efficiently
  bool _hasDueItems(List<int> pages) {
    // Cache due items count per page
    final dueItemCounts = _srsScheduler.getDueItemCounts();
    return pages.any((pageNum) => dueItemCounts[pageNum] != null);
  }

  Map<String, dynamic>? roomDetails;
  bool _hasShownInitialInfo = false;

  @override
  void initState() {
    super.initState();
    if (widget.isGroupReading) {
      _loadRoomDetails().then((_) {
        if (!_hasShownInitialInfo) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showRoomInfoDialog();
            _hasShownInitialInfo = true;
          });
        }
      });
    }
  }

  Future<void> _loadRoomDetails() async {
    if (widget.groupName != null && widget.khatmaName != null) {
      roomDetails = await FirebaseService().getRoomDetails(
        groupName: widget.groupName!,
        khatmaName: widget.khatmaName!,
      );
      setState(() {});
    }
  }

  // Add the new dialog methods
  void _showRoomInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Khatma Progress'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.group, color: Color(0xFF417D7A)),
                title: Text('Group: ${widget.groupName}'),
                subtitle:
                    Text('Created by: ${roomDetails?['createdBy'] ?? 'N/A'}'),
              ),
              ListTile(
                leading: Icon(Icons.calendar_today, color: Color(0xFF417D7A)),
                title: Text('Started'),
                subtitle: Text(
                  '${roomDetails?['createdAt']?.toDate().toString() ?? 'N/A'}',
                ),
              ),
              Divider(),
              Text(
                'Members',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              ...(roomDetails?['members'] as List? ?? []).map(
                (member) => ListTile(
                  leading: Icon(Icons.person_outline),
                  title: Text(member),
                ),
              ),
              Divider(),
              Text(
                'Recently Completed Pages',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              ..._getRecentCompletions(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  List<Widget> _getRecentCompletions() {
    final pages = roomDetails?['pages'] as Map? ?? {};
    final completedPages = pages.entries
        .where((e) => e.value['completed'] == true)
        .take(5) // Show last 5 completed pages
        .map((e) => ListTile(
              leading: Icon(Icons.check_circle, color: Colors.green),
              title: Text('Page ${e.key}'),
              subtitle: Text(
                'By: ${e.value['completedBy']}\n${e.value['completedAt']?.toDate().toString() ?? 'N/A'}',
              ),
              dense: true,
            ))
        .toList();

    return completedPages.isEmpty
        ? [Text('No pages completed yet')]
        : completedPages;
  }

  void _showCompletionSnackbar(int pageNumber) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Page $pageNumber completed successfully! 🎉',
          style: TextStyle(fontSize: 16),
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Add this to your build method to show room info
  Widget _buildRoomInfo() {
    if (!widget.isGroupReading || roomDetails == null) return SizedBox();

    return Card(
      margin: EdgeInsets.all(8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Group: ${widget.groupName}'),
            Text('Khatma: ${widget.khatmaName}'),
            Text('Created by: ${roomDetails!['createdBy']}'),
            Text(
                'Created at: ${roomDetails!['createdAt']?.toDate().toString() ?? 'N/A'}'),
            Text(
                'Members: ${(roomDetails!['members'] as List?)?.join(", ") ?? "None"}'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final surahPages = _getSurahPages();

    // Update the special pages reference
    final Map<int, List<int>> specialPages = SurahData.specialPages;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        actions: [
          // Language Selection Button
          IconButton(
            icon: Icon(Icons.language, color: Colors.white),
            tooltip: 'Change Language',
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => LanguageSelectionPage(),
              ),
            ),
          ),
          // Tutorial Button
          IconButton(
            icon: Icon(Icons.help_outline, color: Colors.white),
            tooltip: 'Tutorial',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => TutorialPage(
                  selectedLanguage: widget.selectedLanguage,
                ),
              ),
            ),
          ),
          // Feedback Button
          IconButton(
            icon: Icon(Icons.feedback_outlined, color: Colors.white),
            tooltip: 'Send Feedback',
            onPressed: () => showDialog(
              context: context,
              builder: (context) => FeedbackDialog(),
            ),
          ),
          // Existing Group Reading Button
          TextButton.icon(
            icon: Icon(Icons.menu_book, color: Colors.white),
            label:
                Text('Read with Group', style: TextStyle(color: Colors.white)),
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => QuranRoomScreen(
                  selectedLanguage: widget.selectedLanguage,
                  isGroupReading: true,
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: 114,
        itemBuilder: (context, index) {
          final surahNum = index + 1;
          final surahData = _surahInfo[surahNum]!;
          final pages = surahPages[surahNum]!;

          // Add special pages to the surah's page list if it's part of a multi-surah page
          List<int> additionalPages = [];
          specialPages.forEach((pageNum, surahs) {
            if (surahs.contains(surahNum) && !pages.contains(pageNum)) {
              additionalPages.add(pageNum);
            }
          });
          final allPages = [...pages, ...additionalPages]..sort();

          return Directionality(
            textDirection: TextDirection.rtl,
            child: ExpansionTile(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _surahInfo[surahNum]!['name']!,
                        style: TextStyle(
                          fontSize: 16,
                          fontFamily: 'Scheherazade',
                        ),
                      ),
                      // Use cached check for due items
                      if (_hasDueItems(allPages))
                        Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Icon(Icons.flag,
                              size: 16, color: Color(0xFF417D7A)),
                        ),
                    ],
                  ),
                  Text(
                    _surahInfo[surahNum]!['name_en']!,
                    style: TextStyle(
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              children: allPages.map((pageNum) {
                final multipleSurahs = specialPages[pageNum] ?? [];

                return ListTile(
                  title: Row(
                    children: [
                      Text('صفحة $pageNum'),
                      SizedBox(width: 8),
                      if (widget.isGroupReading &&
                          roomDetails != null &&
                          (roomDetails?['pages'] as Map?)?[pageNum.toString()]
                                  ?['completed'] ==
                              true)
                        Expanded(
                          child: Text(
                            '✓ Completed by: ${(roomDetails?['pages'] as Map?)?[pageNum.toString()]?['completedBy'] ?? 'Unknown'}',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      // Use cached due item counts
                      if (_srsScheduler.getDueItemCounts()[pageNum] != null)
                        Badge(
                          label: Text(
                              '${_srsScheduler.getDueItemCounts()[pageNum]}'),
                        ),
                      if (_srsScheduler.hasScheduledReviews(pageNum)) ...[
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Level: ${_srsScheduler.getLevel(pageNum, _srsScheduler.getFirstScheduledAyah(pageNum))}, next: ${_srsScheduler.getNextReviewDateTime(pageNum)}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.left,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      if (multipleSurahs.isNotEmpty) ...[
                        SizedBox(width: 8),
                        Text(
                          '(${multipleSurahs.map((s) => _surahInfo[s]!['name']).join(' - ')})',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                            fontFamily: '_Othmani',
                          ),
                        ),
                      ],
                    ],
                  ),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SurahPage(
                          pageNumber: pageNum,
                          currentAyah: 1,
                          onAyahChanged: (newAyah) {
                            setState(() {
                              _currentAyahNumbers[pageNum] = 1;
                            });
                          },
                          initialSurah: multipleSurahs.contains(surahNum)
                              ? surahNum
                              : null,
                          autoPlayEnabled: _globalAutoPlayEnabled,
                          onAutoPlayChanged: (enabled) {
                            setState(() {
                              _globalAutoPlayEnabled = enabled;
                            });
                          },
                          showFirstWordOnly: _showFirstWordOnly,
                          onShowFirstWordOnlyChanged: (value) {
                            setState(() {
                              _showFirstWordOnly = value;
                            });
                          },
                          selectedLanguage: widget.selectedLanguage,
                          groupName: widget.groupName,
                          khatmaName: widget.khatmaName,
                          userName: widget.userName,
                          isGroupReading: widget.isGroupReading,
                        ),
                      ),
                    );
                    // Refresh room details when returning from the page
                    if (widget.isGroupReading) {
                      await _loadRoomDetails();
                    }
                    // Trigger rebuild
                    setState(() {});
                  },
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}

class SurahPage extends StatefulWidget {
  final int pageNumber;
  final int currentAyah;
  final Function(int) onAyahChanged;
  final int? initialSurah;
  final bool autoPlayEnabled;
  final Function(bool) onAutoPlayChanged;
  final bool showFirstWordOnly;
  final Function(bool) onShowFirstWordOnlyChanged;
  final AppLanguage selectedLanguage;
  final String? groupName; // Make optional
  final String? khatmaName; // Make optional
  final String? userName; // Make optional
  final bool isGroupReading;

  const SurahPage({
    Key? key,
    required this.pageNumber,
    required this.currentAyah,
    required this.onAyahChanged,
    this.initialSurah,
    required this.autoPlayEnabled,
    required this.onAutoPlayChanged,
    required this.showFirstWordOnly,
    required this.onShowFirstWordOnlyChanged,
    required this.selectedLanguage,
    this.groupName, // Optional parameter
    this.khatmaName, // Optional parameter
    this.userName, // Optional parameter
    required this.isGroupReading,
  }) : super(key: key);

  @override
  State<SurahPage> createState() => _SurahPageState();
}

class _SurahPageState extends State<SurahPage> {
  late int _currentAyah;
  List<Map<String, dynamic>> _pageAyahs = [];
  List<Map<String, dynamic>> _currentAyahData = [];
  bool _isLoading = false;
  Map<String, String> _tafsirMap = {};
  Map<String, String> _translationMap = {};
  Map<String, List<String>> _pageMapping =
      {}; // Format: 'pageNum': ['surah|ayah', ...]
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  bool _autoPlayEnabled = true;
  Set<int> _revealedAyahs = {};
  late bool _showFirstWordOnly;
  Set<int> _partiallyRevealedAyahs = {};
  Set<int> _fullyRevealedAyahs = {};
  String? _surahBismillah;

  final Map<int, Map<String, dynamic>> _surahInfo = SurahData.surahInfo;

  static Map<int, Set<int>> _forgottenAyahs =
      {}; // Store forgotten ayahs by page number
  int _currentReviewAyah = 1;
  final SRSScheduler _srsScheduler = SRSScheduler();

  // Add this property to the state class
  bool _kidsSoundEnabled = true;
  // Add translations map
  final Map<AppLanguage, Map<String, String>> translations = {
    AppLanguage.arabic: {
      'auto_play_enabled': 'تم تفعيل التشغيل التلقائي',
      'auto_play_disabled': 'تم تعطيل التشغيل التلقائي',
      'show_first_word_enabled': 'تم تفعيل وضع إظهار الكلمة الأولى',
      'show_first_word_disabled': 'تم تعطيل وضع إظهار الكلمة الأولى',
      'ayahs_for_review': 'آيات للمراجعة:',
      'page': 'صفحة',
      'toggle_auto_play': 'تبديل التشغيل التلقائي',
      'previous_ayah': 'الآية السابقة',
      'mark_for_review': 'غير صحيح - علامة للمراجعة',
      'remove_from_review': 'صحيح - إزالة من المراجعة',
      'kids_mode_on': '🎉 تم تفعيل وضع الأطفال',
      'kids_mode_off': 'تم إلغاء وضع الأطفال',
      'kids_sound_on': 'مؤثرات صوتية للأطفال مفعلة',
      'kids_sound_off': 'مؤثرات صوتية للأطفال معطلة',
    },
    AppLanguage.english: {
      'auto_play_enabled': 'Audio auto-play enabled',
      'auto_play_disabled': 'Audio auto-play disabled',
      'show_first_word_enabled': 'Show first word mode activated',
      'show_first_word_disabled': 'Show first word mode deactivated',
      'ayahs_for_review': 'Ayahs for review:',
      'page': 'Page',
      'toggle_auto_play': 'Toggle Auto-play',
      'previous_ayah': 'Previous Ayah',
      'mark_for_review': 'Incorrect - Mark for review',
      'remove_from_review': 'Correct - Remove from review',
      'kids_mode_on': 'Kids Mode Activated! 🎉',
      'kids_mode_off': 'Kids Mode Deactivated',
      'kids_sound_on': 'Kids Sound Effects On',
      'kids_sound_off': 'Kids Sound Effects Off',
    },
    AppLanguage.spanish: {
      'auto_play_enabled': 'Reproducción automática activada',
      'auto_play_disabled': 'Reproducción automática desactivada',
      'show_first_word_enabled': 'Modo mostrar primera palabra activado',
      'show_first_word_disabled': 'Modo mostrar primera palabra desactivado',
      'ayahs_for_review': 'Aleyas para revisar:',
      'page': 'Página',
      'toggle_auto_play': 'Alternar reproducción automática',
      'previous_ayah': 'Aleya anterior',
      'mark_for_review': 'Incorrecto - Marcar para revisar',
      'remove_from_review': 'Correcto - Quitar de revisión',
      'kids_mode_on': '¡Modo Niños Activado! 🎉',
      'kids_mode_off': 'Modo Niños Desactivado',
      'kids_sound_on': 'Efectos de sonido para niños activados',
      'kids_sound_off': 'Efectos de sonido para niños desactivados',
    },
    AppLanguage.hindi: {
      'auto_play_enabled': 'ऑटो-प्ले सक्रिय किया गया',
      'auto_play_disabled': 'ऑटो-प्ले निष्क्रिय किया गया',
      'show_first_word_enabled': 'पहला शब्द दिखाने का मोड सक्रिय',
      'show_first_word_disabled': 'पहला शब्द दिखाने का मोड निष्क्रिय',
      'ayahs_for_review': 'समीक्षा के लिए आयतें:',
      'page': 'पृष्ठ',
      'toggle_auto_play': 'ऑटो-प्ले टॉगल करें',
      'previous_ayah': 'पिछली आयत',
      'mark_for_review': 'गलत - समीक्षा के लिए चिह्नित करें',
      'remove_from_review': 'सही - समीक्षा से हटाएं',
      'kids_mode_on': 'बच्चों का मोड सक्रिय! 🎉',
      'kids_mode_off': 'बच्चों का मोड निष्क्रिय',
      'kids_sound_on': 'आवाज प्रभाव उच्च है',
      'kids_sound_off': 'आवाज प्रभाव कम है',
    },
    AppLanguage.russian: {
      'auto_play_enabled': 'Автовоспроизведение включено',
      'auto_play_disabled': 'Автовоспроизведение выключено',
      'show_first_word_enabled': 'Режим показа первого слова активирован',
      'show_first_word_disabled': 'Режим показа первого слова деактивирован',
      'ayahs_for_review': 'Аяты для повторения:',
      'page': 'Страница',
      'toggle_auto_play': 'Переключить автовоспроизведение',
      'previous_ayah': 'Предыдущий аят',
      'mark_for_review': 'Неверно - Отметить для повторения',
      'remove_from_review': 'Верно - Убрать из повторения',
      'kids_mode_on': 'Детский режим активирован! 🎉',
      'kids_mode_off': 'Детский режим деактивирован',
      'kids_sound_on': 'Включены звуковые эффекты для детей',
      'kids_sound_off': 'Выключены звуковые эффекты для детей',
    },
    AppLanguage.chinese: {
      'auto_play_enabled': '自动播放已启用',
      'auto_play_disabled': '自动播放已禁用',
      'show_first_word_enabled': '显示首词模式已激活',
      'show_first_word_disabled': '显示首词模式已停用',
      'ayahs_for_review': '需要复习的经文：',
      'page': '页',
      'toggle_auto_play': '切换自动播放',
      'previous_ayah': '上一节经文',
      'mark_for_review': '错误 - 标记为复习',
      'remove_from_review': '正确 - 从复习中移除',
      'kids_mode_on': '儿童模式已启用！🎉',
      'kids_mode_off': '儿童模式已关闭',
      'kids_sound_on': '儿童声音效果已启用',
      'kids_sound_off': '儿童声音效果已关闭',
    },
    AppLanguage.turkish: {
      'auto_play_enabled': 'Otomatik oynatma etkin',
      'auto_play_disabled': 'Otomatik oynatma devre dışı',
      'show_first_word_enabled': 'İlk kelime gösterme modu etkin',
      'show_first_word_disabled': 'İlk kelime gösterme modu devre dışı',
      'ayahs_for_review': 'Tekrar için ayetler:',
      'page': 'Sayfa',
      'toggle_auto_play': 'Otomatik oynatmayı değiştir',
      'previous_ayah': 'Önceki ayet',
      'mark_for_review': 'Yanlış - Tekrar için işaretle',
      'remove_from_review': 'Doğru - Tekrardan kaldır',
      'kids_mode_on': 'Çocuk Modu Etkinleştirildi! 🎉',
      'kids_mode_off': 'Çocuk Modu Devre Dışı',
      'kids_sound_on': 'Çocuk ses efektleri aktif',
      'kids_sound_off': 'Çocuk ses efektleri devre dışı',
    },
    AppLanguage.urdu: {
      'auto_play_enabled': 'آٹو-پلے فعال کر دیا گیا',
      'auto_play_disabled': 'آٹو-پلے غیر فعال کر دیا گیا',
      'show_first_word_enabled': 'پہلا الفاظ دکھانے کا موڈ فعال',
      'show_first_word_disabled': 'پہلا الفاظ دکھانے کا موڈ غیر فعال',
      'ayahs_for_review': 'جدول کے لئے آیتیں:',
      'page': 'صفحہ',
      'toggle_auto_play': 'آٹو-پلے ٹوگل کریں',
      'previous_ayah': 'پچھلی آیت',
      'mark_for_review': 'غلط - جدول کے لئے نشان لگائیں',
      'remove_from_review': 'صحیح - جدول سے ہٹا دیں',
      'kids_mode_on': '🎉 بچوں کا موڈ فعال',
      'kids_mode_off': 'بچوں کا موڈ غیر فعال',
      'kids_sound_on': 'بچوں کے صوتی اثر مفعل ہیں',
      'kids_sound_off': 'بچوں کے صوتی اثر معطل ہیں',
    },
    AppLanguage.indonesian: {
      'auto_play_enabled': 'Pemutaran otomatis diaktifkan',
      'auto_play_disabled': 'Pemutaran otomatis dinonaktifkan',
      'show_first_word_enabled': 'Mode tampilkan kata pertama diaktifkan',
      'show_first_word_disabled': 'Mode tampilkan kata pertama dinonaktifkan',
      'ayahs_for_review': 'Ayat untuk ditinjau:',
      'page': 'Halaman',
      'toggle_auto_play': 'Beralih Pemutaran Otomatis',
      'previous_ayah': 'Ayat Sebelumnya',
      'mark_for_review': 'Tidak Benar - Tandai untuk ditinjau',
      'remove_from_review': 'Benar - Hapus dari tinjauan',
      'kids_mode_on': 'Mode Anak Diaktifkan! 🎉',
      'kids_mode_off': 'Mode Anak Dinonaktifkan',
      'kids_sound_on': 'Suara Efek untuk Anak Diaktifkan',
      'kids_sound_off': 'Suara Efek untuk Anak Dinonaktifkan',
    },
  };

  String getTranslation(String key) {
    return translations[widget.selectedLanguage]?[key] ??
        translations[AppLanguage.english]![key]!;
  }

  // Add controller for confetti
  late List<ConfettiController> _confettiControllers;
  bool _kidsMode = false;
  final Random _random = Random();

  // List of celebration configurations
  final List<Map<String, dynamic>> _celebrationStyles = [
    // 1. Standard Confetti (existing)
    {
      'alignment': Alignment.topCenter,
      'direction': pi / 2,
      'colors': [Colors.red, Colors.blue, Colors.yellow, Colors.green],
      'particles': 30,
      'type': 'standard'
    },
    // 2. Birthday Style (existing)
    {
      'alignment': Alignment.center,
      'direction': 0,
      'colors': [
        Colors.pink,
        Colors.purple,
        Colors.orange,
        Colors.yellow,
        Colors.blue
      ],
      'particles': 50,
      'type': 'birthday'
    },
    // 3. Fireworks Style (existing)
    {
      'alignment': Alignment.bottomCenter,
      'direction': -pi / 2,
      'colors': [
        Colors.red,
        Colors.amber,
        Colors.blue,
        Colors.green,
        Colors.purple
      ],
      'particles': 40,
      'type': 'fireworks'
    },
    // 4. Spiral Burst
    {
      'alignment': Alignment.center,
      'direction': pi,
      'colors': [Colors.teal, Colors.indigo, Colors.lime, Colors.orange],
      'particles': 60,
      'type': 'spiral'
    },
    // 5. Rain Effect
    {
      'alignment': Alignment.topCenter,
      'direction': pi / 2,
      'colors': [
        Colors.blue[300]!,
        Colors.blue[400]!,
        Colors.blue[500]!,
        Colors.white
      ],
      'particles': 100,
      'type': 'rain'
    },
    // 6. Side Sweep
    {
      'alignment': Alignment.centerRight,
      'direction': pi,
      'colors': [
        Colors.deepPurple,
        Colors.deepOrange,
        Colors.cyan,
        Colors.amber
      ],
      'particles': 45,
      'type': 'sweep'
    },
    // 7. Diamond Shower
    {
      'alignment': Alignment.topCenter,
      'direction': pi / 2,
      'colors': [
        Colors.pink[300]!,
        Colors.pink[400]!,
        Colors.purple[300]!,
        Colors.purple[400]!
      ],
      'particles': 35,
      'type': 'diamond'
    },
    // 8. Star Burst
    {
      'alignment': Alignment.center,
      'direction': 0,
      'colors': [
        Colors.amber,
        Colors.yellow,
        Colors.orange[400]!,
        Colors.orange[600]!
      ],
      'particles': 40,
      'type': 'star'
    },
    // 9. Fountain
    {
      'alignment': Alignment.bottomCenter,
      'direction': -pi / 2,
      'colors': [Colors.lightBlue, Colors.cyan, Colors.teal, Colors.blue],
      'particles': 55,
      'type': 'fountain'
    },
    // 10. Glitter Explosion
    {
      'alignment': Alignment.center,
      'direction': 0,
      'colors': [
        Colors.amber[200]!,
        Colors.yellow[200]!,
        Colors.white,
        Colors.grey[300]!
      ],
      'particles': 80,
      'type': 'glitter'
    }
  ];

  // Add audio player for clapping
  late AudioPlayer _clappingPlayer;
  late AudioPlayer _praisePlayer;

  final List<String> _praiseSounds = [
    'audio/mashallah.mp3',
    'audio/jazakAllhKhair.mp3',
    'audio/barkAllhfik.mp3',
    'audio/ahsnAllhElik.mp3'
  ];

  bool _showClickHint = false;

  final FirebaseService _firebaseService = FirebaseService();

  Map<String, dynamic>? roomDetails;

  bool _showTajweedMenu = false; // Add this to your state variables

  @override
  void initState() {
    super.initState();
    _checkFirstTimeUser();
    _currentAyah = widget.currentAyah;
    _showFirstWordOnly = widget.showFirstWordOnly;
    _autoPlayEnabled = widget.autoPlayEnabled;
    _audioPlayer = AudioPlayer();
    _clappingPlayer = AudioPlayer();
    _praisePlayer = AudioPlayer();

    // Initialize _currentReviewAyah based on forgotten ayahs
    _currentReviewAyah = _getForgottenAyahCount();

    _loadData().then((_) {
      setState(() {
        // Check for review ayahs
        List<int> reviewAyahs = _getForgottenAyahList();
        print('reviewAyahs: $reviewAyahs');
        if (reviewAyahs.isNotEmpty) {
          // If there are ayahs to review, reveal them and set current ayah
          _revealAyahsforReview(reviewAyahs);
          _currentAyah = reviewAyahs[0] - 1;
        }

        if (widget.initialSurah != null) {
          // Show all ayahs but hide selected surah's ayahs
          _currentAyahData = _pageAyahs;
          // Find first ayah index of selected surah
          int firstAyahIndex = _pageAyahs
              .indexWhere((ayah) => ayah['surah'] == widget.initialSurah);
          if (firstAyahIndex != -1) {
            _currentAyah = firstAyahIndex + 1;
            _revealedAyahs = Set.from(_pageAyahs
                .asMap()
                .entries
                .where((entry) => entry.value['surah'] != widget.initialSurah)
                .map((entry) => entry.key + 1));
          }
        } else if (SurahData.specialPages.containsKey(widget.pageNumber)) {
          _currentAyahData = _pageAyahs;
        } else {
          _currentAyahData = _pageAyahs;
        }
      });
    });

    // Play first ayah if auto-play is enabled
    if (_autoPlayEnabled && _pageAyahs.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final firstAyah = _pageAyahs[0];
        _playAudio(firstAyah['surah'], firstAyah['ayah']);
      });
    }

    // Add this to update _forgottenAyahs with due items
    _updateDueItems();

    // Initialize a controller for each style
    _confettiControllers = List.generate(_celebrationStyles.length,
        (_) => ConfettiController(duration: const Duration(seconds: 2)));
    _loadKidsMode();

    Future.delayed(Duration.zero, () => showAudioDownloadDialog(context));

    _loadSoundPreference();
  }

  Future<void> _checkFirstTimeUser() async {
    final prefs = await shared_prefs.SharedPreferences.getInstance();
    final hasClickedBefore = prefs.getBool('hasClickedBefore') ?? false;
    if (!hasClickedBefore) {
      setState(() {
        _showClickHint = true;
      });
    }
  }

  void _handleFirstClick() async {
    if (_showClickHint) {
      final prefs = await shared_prefs.SharedPreferences.getInstance();
      await prefs.setBool('hasClickedBefore', true);
      setState(() {
        _showClickHint = false;
      });
    }
  }

  Future<void> _loadSoundPreference() async {
    final prefs = await shared_prefs.SharedPreferences.getInstance();
    setState(() {
      _kidsSoundEnabled = prefs.getBool('kidsSoundEnabled') ?? true;
    });
  }

  Future<void> _toggleSound() async {
    final prefs = await shared_prefs.SharedPreferences.getInstance();
    setState(() {
      _kidsSoundEnabled = !_kidsSoundEnabled;
      prefs.setBool('kidsSoundEnabled', _kidsSoundEnabled);
    });
  }

  void showAudioDownloadDialog(BuildContext context) async {
    final prefs = await shared_prefs.SharedPreferences.getInstance();
    if (prefs.getBool('skipAudioDownload') == true) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Audio Download'),
        content: Text('Audio files will be downloaded as you browse pages.'),
        actions: [
          TextButton(
            child: Text('Don\'t Show Again'),
            onPressed: () async {
              await prefs.setBool('skipAudioDownload', true);
              Navigator.pop(context);
            },
          ),
          TextButton(
            child: Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _audioPlayer.stop();
    _audioPlayer.dispose();
    _clappingPlayer.dispose();
    _praisePlayer.dispose();
    for (var controller in _confettiControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load all required text files
      final mappingText =
          await rootBundle.loadString('assets/Txt files/page_ayah_count.txt');
      final quranText = await rootBundle
          .loadString('assets/Txt files/quran-tajweed-numbered.txt');
      // Get the appropriate tafsir file based on language
      String tafsirFile;
      switch (widget.selectedLanguage) {
        case AppLanguage.arabic:
        case AppLanguage.english:
          tafsirFile = 'ar.muyassar.txt';
          break;
        case AppLanguage.spanish:
          tafsirFile = 'es.garcia.txt';
          break;
        case AppLanguage.hindi:
          tafsirFile = 'hi.farooq.txt';
          break;
        case AppLanguage.urdu:
          tafsirFile = 'ur.maududi.txt';
          break;
        case AppLanguage.indonesian:
          tafsirFile = 'id.indonesian.txt';
          break;
        case AppLanguage.russian:
          tafsirFile = 'ru.kalam.txt';
          break;
        case AppLanguage.chinese:
          tafsirFile = 'zh.jian.txt';
          break;
        case AppLanguage.turkish:
          tafsirFile = 'tr.ozturk.txt';
          break;
      }

      final tafsirText =
          await rootBundle.loadString('assets/Txt files/$tafsirFile');
      final translationText =
          await rootBundle.loadString('assets/Txt files/en.yusufali.txt');

      // Parse page mapping
      final mappingLines = mappingText.split('\n');
      for (var line in mappingLines) {
        if (line.trim().isEmpty) continue;
        final parts = line.split('|');
        final pageNum = parts[0];
        final surah = parts[1];
        final ayah = parts[2];

        if (!_pageMapping.containsKey(pageNum)) {
          _pageMapping[pageNum] = [];
        }
        _pageMapping[pageNum]!.add('$surah|$ayah');
      }

      // Parse Quran text
      final quranLines = quranText.split('\n');
      Map<String, String> quranMap = {};
      String? currentBismillah;

      for (var line in quranLines) {
        if (line.trim().isEmpty) continue;
        final parts = line.split('|');
        if (parts.length < 3) continue;

        final surah = int.parse(parts[0]);
        final ayah = int.parse(parts[1]);
        var verse = parts[2];

        // Handle Bismillah for first ayah of each surah
        if (ayah == 1 && surah != 1 && surah != 9) {
          // Skip Surah 1 (Fatiha) and 9 (Tawbah)
          // Split verse into words
          List<String> words = verse.split(' ');
          if (words.length > 4) {
            // Store the Bismillah (first 4 words)
            currentBismillah = words.take(4).join(' ');
            // Keep the rest of the verse
            verse = words.skip(4).join(' ').trim();
          }
        }

        final key = '$surah|$ayah';
        quranMap[key] = verse;
      }

      // Store Bismillah in a way that can be accessed by the UI
      _surahBismillah = currentBismillah;

      // Parse tafsir and translation
      // ... (keep existing parsing code for tafsir and translation) ...
      // Parse tafsir text
      final tafsirLines = tafsirText.split('\n');
      Map<String, String> _tafsirMap = {};
      for (var line in tafsirLines) {
        if (line.trim().isEmpty) continue;
        final parts = line.split('|');
        if (parts.length < 3) continue;
        final key = '${parts[0]}|${parts[1]}';
        _tafsirMap[key] = parts[2];
      }

      // Parse translation text
      final translationLines = translationText.split('\n');
      Map<String, String> _translationMap = {};
      for (var line in translationLines) {
        if (line.trim().isEmpty) continue;
        final parts = line.split('|');
        if (parts.length < 3) continue;
        final key = '${parts[0]}|${parts[1]}';
        _translationMap[key] = parts[2];
      }

      // Get ayahs for current page
      List<Map<String, dynamic>> ayahs = [];
      final pageAyahs = _pageMapping[widget.pageNumber.toString()] ?? [];

      for (var mapping in pageAyahs) {
        final parts = mapping.split('|');
        if (parts.length < 2) continue; // Ensure there are enough parts
        final surah = int.parse(parts[0]);
        final ayah = int.parse(parts[1]);
        final mapKey = '$surah|$ayah';

        ayahs.add({
          'surah': surah,
          'ayah': ayah,
          'verse': quranMap[mapKey] ?? '',
          'tafsir': _tafsirMap['$surah|$ayah'] ?? '',
          'translation': _translationMap['$surah|$ayah'] ?? '',
        });
      }

      setState(() {
        _pageAyahs = ayahs;
        if (ayahs.isNotEmpty) {
          _currentAyahData = [ayahs.first];
        } else {
          _currentAyahData = [];
        }
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _playAudio(int surah, int ayah) async {
    try {
      final surahStr = surah.toString().padLeft(3, '0');
      final ayahStr = ayah.toString().padLeft(3, '0');

      await _audioPlayer.dispose();
      _audioPlayer = AudioPlayer();

      setState(() {
        _isPlaying = true;
      });

      if (kIsWeb) {
        // For web, stream directly from URL
        final url =
            'https://everyayah.com/data/Hudhaify_32kbps/${surahStr}${ayahStr}.mp3';
        await _audioPlayer.play(UrlSource(url));
      } else {
        // For mobile, use local file with download prompt
        final audioFile = await AudioService.getAudioPath(surahStr, ayahStr);
        final prefs = await shared_prefs.SharedPreferences.getInstance();
        final hideDownloadPrompt =
            prefs.getBool('hideAudioDownloadPrompt') ?? false;

        if (!hideDownloadPrompt && !await File(audioFile).exists()) {
          if (!mounted) return;

          final shouldDownload = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Audio Download'),
              content: Text(
                  'This ayah\'s audio will be downloaded. Would you like to proceed?'),
              actions: [
                TextButton(
                  child: Text('Cancel'),
                  onPressed: () => Navigator.pop(context, false),
                ),
                TextButton(
                  child: Text('Don\'t Show Again'),
                  onPressed: () async {
                    await prefs.setBool('hideAudioDownloadPrompt', true);
                    Navigator.pop(context, true);
                  },
                ),
                TextButton(
                  child: Text('Download'),
                  onPressed: () => Navigator.pop(context, true),
                ),
              ],
            ),
          );

          if (shouldDownload != true) {
            setState(() {
              _isPlaying = false;
            });
            return;
          }
        }

        await _audioPlayer.play(DeviceFileSource(audioFile));
      }

      _audioPlayer.onPlayerComplete.listen((event) {
        if (mounted) {
          setState(() {
            _isPlaying = false;
          });
        }
      });
    } catch (e) {
      print('Error playing audio: $e');
      if (mounted) {
        setState(() {
          _isPlaying = false;
        });
      }
    }
  }

  // Add this helper method to get the current ayah data
  Map<String, dynamic> _getCurrentAyahData() {
    // Get the index of the last revealed ayah
    final currentIndex = (_currentAyah - 1).clamp(0, _pageAyahs.length - 1);
    return _pageAyahs[currentIndex];
  }

  void _revealAyahsforReview(List<int> reviewAyahs) {
    // Reveal all ayahs that are marked for review
    for (int i = 0; i < reviewAyahs[0] - 1; i++) {
      _fullyRevealedAyahs.add(i);
    }
  }

  bool firstPass = true;
  void _showNextAyah() {
    if (_currentAyah <= _pageAyahs.length) {
      if (_isPlaying) {
        _audioPlayer.stop();
        setState(() {
          _isPlaying = false;
        });
      }

      int nextAyahIndex = _currentAyah - 1;

      // Only apply the surah filter for the first ayah on special pages
      if (nextAyahIndex == 0 && widget.initialSurah != null) {
        while (nextAyahIndex < _pageAyahs.length &&
            _pageAyahs[nextAyahIndex]['surah'] != widget.initialSurah) {
          nextAyahIndex++;
        }
      }

      if (nextAyahIndex < _pageAyahs.length) {
        setState(() {
          if (_showFirstWordOnly) {
            if (_partiallyRevealedAyahs.contains(_currentAyah)) {
              _fullyRevealedAyahs.add(_currentAyah);
              _currentAyah++;
              if (_autoPlayEnabled) {
                final currentAyahData = _pageAyahs[nextAyahIndex];
                _playAudio(currentAyahData['surah'], currentAyahData['ayah']);
              }
              widget.onAyahChanged(_currentAyah);
            } else {
              _partiallyRevealedAyahs.add(_currentAyah);
            }
          } else {
            _fullyRevealedAyahs.add(_currentAyah);
            _currentAyah++;
            if (_autoPlayEnabled) {
              final currentAyahData = _pageAyahs[nextAyahIndex];
              _playAudio(currentAyahData['surah'], currentAyahData['ayah']);
            }
            widget.onAyahChanged(_currentAyah);
          }
        });
      } else {
        if (_getForgottenAyahList().isNotEmpty) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => SurahPage(
                pageNumber: widget.pageNumber,
                currentAyah: 1,
                onAyahChanged: (newAyah) {},
                autoPlayEnabled: _autoPlayEnabled,
                onAutoPlayChanged: (enabled) {
                  setState(() {
                    _autoPlayEnabled = enabled;
                  });
                },
                showFirstWordOnly: _showFirstWordOnly,
                onShowFirstWordOnlyChanged: widget.onShowFirstWordOnlyChanged,
                selectedLanguage: widget.selectedLanguage,
                groupName: widget.groupName,
                khatmaName: widget.khatmaName,
                userName: widget.userName,
                isGroupReading: widget.isGroupReading,
              ),
            ),
          );
        } else {
          _navigateToNextPage();
        }
      }
    } else {
      if (_getForgottenAyahList().isNotEmpty) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SurahPage(
              pageNumber: widget.pageNumber,
              currentAyah: 1,
              onAyahChanged: (newAyah) {},
              autoPlayEnabled: _autoPlayEnabled,
              onAutoPlayChanged: (enabled) {
                setState(() {
                  _autoPlayEnabled = enabled;
                });
              },
              showFirstWordOnly: _showFirstWordOnly,
              onShowFirstWordOnlyChanged: widget.onShowFirstWordOnlyChanged,
              selectedLanguage: widget.selectedLanguage,
              groupName: widget.groupName,
              khatmaName: widget.khatmaName,
              userName: widget.userName,
              isGroupReading: widget.isGroupReading,
            ),
          ),
        );
      } else {
        _navigateToNextPage();
      }
    }
  }

  void _navigateToNextPage() async {
    // Determine next page number (1 if current page is 604, otherwise increment)
    int nextPage = widget.pageNumber == 604 ? 1 : widget.pageNumber + 1;

    if (widget.isGroupReading &&
        widget.groupName != null &&
        widget.khatmaName != null &&
        widget.userName != null) {
      setState(() => _isLoading = true); // Show loading

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 12),
              Text('Updating progress...'),
            ],
          ),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );

      try {
        await FirebaseService().markPageAsCompleted(
          groupName: widget.groupName!,
          khatmaName: widget.khatmaName!,
          userName: widget.userName!,
          pageNumber: widget.pageNumber,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Page ${widget.pageNumber} marked as completed! 🎉',
              style: TextStyle(fontSize: 16),
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        print('Error marking page as completed: $e');
      } finally {
        setState(() => _isLoading = false); // Hide loading
      }
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => SurahPage(
          pageNumber: nextPage,
          currentAyah: 1,
          onAyahChanged: (newAyah) {},
          autoPlayEnabled: _autoPlayEnabled,
          onAutoPlayChanged: (enabled) {
            setState(() {
              _autoPlayEnabled = enabled;
            });
          },
          showFirstWordOnly: _showFirstWordOnly,
          onShowFirstWordOnlyChanged: widget.onShowFirstWordOnlyChanged,
          selectedLanguage: widget.selectedLanguage,
          groupName: widget.groupName,
          khatmaName: widget.khatmaName,
          userName: widget.userName,
          isGroupReading: widget.isGroupReading,
        ),
      ),
    );
  }

  // Add this method to group ayahs by surah
  Map<int, List<Map<String, dynamic>>> _groupAyahsBySurah(
      List<Map<String, dynamic>> ayahs) {
    Map<int, List<Map<String, dynamic>>> grouped = {};
    for (var ayah in ayahs) {
      final surah = ayah['surah'] as int;
      if (!grouped.containsKey(surah)) {
        grouped[surah] = [];
      }
      grouped[surah]!.add(ayah);
    }
    return grouped;
  }

  int _getForgottenAyahCount() {
    return _forgottenAyahs[widget.pageNumber]?.length ?? 1;
  }

  List<int> _getForgottenAyahList() {
    return _forgottenAyahs[widget.pageNumber]?.toList() ?? [];
  }

  void _markAyahAsForgotten() {
    setState(() {
      _forgottenAyahs.putIfAbsent(widget.pageNumber, () => {});
      _forgottenAyahs[widget.pageNumber]!.add(_currentAyah);

      // Add to SRS system
      _srsScheduler.addItems(widget.pageNumber, {_currentAyah});

      _fullyRevealedAyahs.remove(_currentAyah - 1);
      _partiallyRevealedAyahs.remove(_currentAyah - 1);
    });
  }

  void _resetForgottenAyahs() async {
    setState(() {
      _forgottenAyahs[widget.pageNumber]?.remove(_currentAyah);
      _srsScheduler.markReviewed(widget.pageNumber, _currentAyah, true);
    });
    List<int> reviewAyahs = _getForgottenAyahList();
    if (_kidsMode && _kidsSoundEnabled && reviewAyahs.isNotEmpty) {
      try {
        final soundFile = _praiseSounds[_random.nextInt(_praiseSounds.length)];
        await _praisePlayer.play(AssetSource(soundFile));
        _playCelebration();
      } catch (e) {
        print('Error playing audio: $e');
        _playCelebration();
      }
    } else if (_kidsMode) {
      _playCelebration();
    }

    // Get review ayahs list

    print('reviewAyahs: $reviewAyahs');
    // Only refresh if there are more than one review ayahs remaining
    if (reviewAyahs.isNotEmpty && reviewAyahs.length >= 1) {
      _revealAyahsforReview(reviewAyahs);
      _currentAyah = reviewAyahs[0] - 1;
      if (_isPlaying) {
        _audioPlayer.stop();
        setState(() {
          _isPlaying = false;
        });
      }
    }
  }

  void _updateDueItems() {
    final dueItems = _srsScheduler.getDueItems(widget.pageNumber);
    if (dueItems.isNotEmpty) {
      setState(() {
        _forgottenAyahs[widget.pageNumber] = dueItems;
      });
    }
  }

  void _showPreviousAyah() {
    if (_currentAyah > 1) {
      if (_isPlaying) {
        _audioPlayer.stop();
        setState(() {
          _isPlaying = false;
        });
      }

      setState(() {
        _currentAyah--;
        _fullyRevealedAyahs.remove(_currentAyah);
        _partiallyRevealedAyahs.remove(_currentAyah);
        widget.onAyahChanged(_currentAyah);
      });
    }
  }

  Future<void> _loadKidsMode() async {
    final prefs = await shared_prefs.SharedPreferences.getInstance();
    setState(() {
      _kidsMode = prefs.getBool('kids_mode') ?? false;
    });
  }

  Future<void> _toggleKidsMode() async {
    final prefs = await shared_prefs.SharedPreferences.getInstance();
    setState(() {
      _kidsMode = !_kidsMode;
      prefs.setBool('kids_mode', _kidsMode);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            getTranslation(_kidsMode ? 'kids_mode_on' : 'kids_mode_off'),
            textAlign: isRTL(widget.selectedLanguage)
                ? TextAlign.right
                : TextAlign.left,
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _kidsMode ? Colors.green : Colors.grey,
          duration: Duration(seconds: 2),
        ),
      );
    });
  }

  void _playCelebration() {
    if (!_kidsMode) return;

    // Play random celebration
    final randomIndex = _random.nextInt(_confettiControllers.length);
    _confettiControllers[randomIndex].play();
  }

  Future<void> _loadRoomDetails() async {
    if (widget.groupName != null && widget.khatmaName != null) {
      roomDetails = await FirebaseService().getRoomDetails(
        groupName: widget.groupName!,
        khatmaName: widget.khatmaName!,
      );
      setState(() {});
    }
  }

  void _showCompletionSnackbar(int pageNumber) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Page $pageNumber completed successfully! 🎉',
          style: TextStyle(fontSize: 16),
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Add this to your build method to show room info
  Widget _buildRoomInfo() {
    if (!widget.isGroupReading || roomDetails == null) return SizedBox();

    return Card(
      margin: EdgeInsets.all(8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Group: ${widget.groupName}'),
            Text('Khatma: ${widget.khatmaName}'),
            Text('Created by: ${roomDetails!['createdBy']}'),
            Text(
                'Created at: ${roomDetails!['createdAt']?.toDate().toString() ?? 'N/A'}'),
            Text(
                'Members: ${(roomDetails!['members'] as List?)?.join(", ") ?? "None"}'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Calculate responsive font sizes based on screen dimensions
    double getQuranFontSize() {
      final screenWidth = MediaQuery.of(context).size.width;
      if (screenWidth <= 600) return screenWidth * 0.06;
      if (screenWidth <= 1024) return screenWidth * 0.04;
      return 24.0; // Default size for larger screens
    }

    double getSymbolFontSize() {
      final quranFontSize = getQuranFontSize();
      return quranFontSize *
          0.8; // Make symbol slightly smaller than Quran text
    }

    // Calculate responsive padding
    double getHorizontalPadding() {
      if (screenWidth <= 600) return 16.0;
      if (screenWidth <= 1024) return 24.0;
      return 32.0;
    }

    double getVerticalPadding() {
      if (screenHeight <= 800) return 16.0;
      return 20.0;
    }

    // Get the current surah number from the first ayah on the page
    int? currentSurah = _pageAyahs.isNotEmpty ? _pageAyahs[0]['surah'] : null;
    bool isStartOfSurah = currentSurah != null &&
        _surahInfo[currentSurah]!['start_page'] == widget.pageNumber;

    return Stack(
      children: [
        GestureDetector(
          onTap: _handleFirstClick,
          child: Scaffold(
            appBar: AppBar(
              toolbarHeight:
                  isStartOfSurah ? kToolbarHeight * 1.5 : kToolbarHeight,
              title: Column(
                children: [
                  Text('Page ${widget.pageNumber}'),
                  if (isStartOfSurah &&
                      currentSurah != 9) // Don't show Bismillah for Surah 9
                    Container(
                      width: double.infinity,
                      alignment: Alignment.center,
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: TextStyle(
                            fontFamily: 'Scheherazade',
                            color: Colors.white70,
                          ),
                          children: [
                            TextSpan(
                              text:
                                  'أَعُوذُ بِاللَّهِ مِنَ الشَّيْطَانِ الرَّجِيمِ ﴿١﴾ بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                              style: TextStyle(
                                fontFamily: 'Scheherazade',
                                fontSize: 18,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              centerTitle: true,
              actions: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          _showFirstWordOnly ? Icons.edit_note : Icons.subject,
                          size: 24,
                        ),
                        onPressed: () {
                          setState(() {
                            _showFirstWordOnly = !_showFirstWordOnly;
                          });
                          widget.onShowFirstWordOnlyChanged(_showFirstWordOnly);

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                _showFirstWordOnly
                                    ? 'Show first word mode activated'
                                    : 'Show first word mode deactivated',
                                textAlign: TextAlign.center,
                              ),
                              duration: Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: Icon(
                          _autoPlayEnabled
                              ? Icons.play_circle
                              : Icons.play_circle_outline,
                          color: _autoPlayEnabled
                              ? Color.fromARGB(255, 0, 0, 0)
                              : Colors.grey,
                          size: 24,
                        ),
                        onPressed: () {
                          setState(() {
                            _autoPlayEnabled = !_autoPlayEnabled;
                          });
                          widget.onAutoPlayChanged(_autoPlayEnabled);

                          if (_autoPlayEnabled) {
                            final currentAyahData = _getCurrentAyahData();
                            _playAudio(
                              currentAyahData['surah'],
                              currentAyahData['ayah'],
                            );
                          }

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                _autoPlayEnabled
                                    ? 'Audio auto-play enabled'
                                    : 'Audio auto-play disabled',
                                textAlign: TextAlign.center,
                              ),
                              duration: Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back_ios, // Left arrow for going back
                          color: Color.fromARGB(255, 0, 0, 0),
                          size: 24,
                        ),
                        onPressed: widget.pageNumber > 1
                            ? () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => SurahPage(
                                      pageNumber: widget.pageNumber - 1,
                                      currentAyah: 1,
                                      onAyahChanged: (newAyah) {},
                                      autoPlayEnabled: _autoPlayEnabled,
                                      onAutoPlayChanged: (enabled) {
                                        setState(() {
                                          _autoPlayEnabled = enabled;
                                        });
                                      },
                                      showFirstWordOnly: _showFirstWordOnly,
                                      onShowFirstWordOnlyChanged:
                                          widget.onShowFirstWordOnlyChanged,
                                      selectedLanguage: widget.selectedLanguage,
                                      groupName: widget.groupName,
                                      khatmaName: widget.khatmaName,
                                      userName: widget.userName,
                                      isGroupReading: widget.isGroupReading,
                                    ),
                                  ),
                                );
                              }
                            : null,
                      ),
                      IconButton(
                        icon: Icon(
                          Icons
                              .arrow_forward_ios, // Right arrow for going forward
                          color: Color(0xFF000000),
                          size: 20,
                        ),
                        onPressed: widget.pageNumber < 604
                            ? () => _navigateToNextPage()
                            : null,
                      ),
                    ],
                  ),
                ),
                // Add kids mode toggle
                IconButton(
                  icon: Icon(_kidsMode ? Icons.child_care : Icons.person),
                  onPressed: _toggleKidsMode,
                  tooltip: getTranslation(
                      _kidsMode ? 'kids_mode_on' : 'kids_mode_off'),
                ),
                if (_kidsMode)
                  IconButton(
                    icon: Icon(
                        _kidsSoundEnabled ? Icons.volume_up : Icons.volume_off),
                    onPressed: _toggleSound,
                  ),
              ],
            ),
            body: Column(
              children: [
                if (_srsScheduler.hasScheduledReviews(widget.pageNumber) ||
                    (_forgottenAyahs[widget.pageNumber]?.isNotEmpty ?? false))
                  Container(
                    padding: EdgeInsets.all(8),
                    color: Color(0xFF417D7A).withOpacity(0.1),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (_srsScheduler
                            .hasScheduledReviews(widget.pageNumber))
                          Expanded(
                            child: Text(
                              '(next: ${_srsScheduler.getNextReviewDateTime(widget.pageNumber)})',
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context)
                                    .colorScheme
                                    .secondary
                                    .withOpacity(0.8),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        Text(
                          getTranslation('page'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                        Text(
                          '${widget.pageNumber}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: Center(
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: 800,
                      ),
                      decoration: BoxDecoration(
                        color: Color(0xFFF2F4F3),
                      ),
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : SingleChildScrollView(
                              child: Column(
                                children: _groupAyahsBySurah(_currentAyahData)
                                    .entries
                                    .map((entry) {
                                  final surahNumber = entry.key;
                                  final surahAyahs = entry.value;

                                  return Align(
                                    alignment: Alignment.topLeft,
                                    child: Card(
                                      margin: EdgeInsets.all(
                                          getHorizontalPadding() * 0.5),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(15),
                                        side: BorderSide(
                                          color: Color(0xFF4F757C),
                                          width: 3,
                                        ),
                                      ),
                                      elevation: 5,
                                      child: InkWell(
                                        onTap: _showNextAyah,
                                        child: Container(
                                          width: double.infinity,
                                          constraints: BoxConstraints(
                                            maxWidth: screenWidth > 1024
                                                ? 1024
                                                : double.infinity,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(15),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withOpacity(0.2),
                                                spreadRadius: 2,
                                                blurRadius: 10,
                                                offset: Offset(5, 5),
                                              ),
                                            ],
                                          ),
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal:
                                                  getHorizontalPadding(),
                                              vertical: getVerticalPadding(),
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text(
                                                      'سورة ${_surahInfo[surahNumber]!['name']}',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .titleMedium
                                                          ?.copyWith(
                                                            color: Color(
                                                                0xFF2B4141),
                                                            fontSize:
                                                                getQuranFontSize() *
                                                                    0.75,
                                                            fontFamily:
                                                                'Scheherazade',
                                                          ),
                                                    ),
                                                    if (surahAyahs.isNotEmpty)
                                                      Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          IconButton(
                                                            icon: Icon(
                                                              _autoPlayEnabled
                                                                  ? Icons
                                                                      .repeat_one
                                                                  : Icons
                                                                      .repeat_one_outlined,
                                                              color: _autoPlayEnabled
                                                                  ? Color
                                                                      .fromARGB(
                                                                          255,
                                                                          0,
                                                                          0,
                                                                          0)
                                                                  : Colors.grey,
                                                              size: 20,
                                                            ),
                                                            onPressed: () {
                                                              setState(() {
                                                                _autoPlayEnabled =
                                                                    !_autoPlayEnabled;
                                                              });
                                                              widget.onAutoPlayChanged(
                                                                  _autoPlayEnabled);
                                                            },
                                                            tooltip:
                                                                'Toggle Auto-play',
                                                          ),
                                                          IconButton(
                                                            icon: Icon(
                                                              _isPlaying
                                                                  ? Icons.pause
                                                                  : Icons
                                                                      .play_arrow,
                                                              color: Color
                                                                  .fromARGB(255,
                                                                      0, 0, 0),
                                                            ),
                                                            onPressed:
                                                                _isPlaying
                                                                    ? () {
                                                                        _audioPlayer
                                                                            .pause();
                                                                        setState(
                                                                            () {
                                                                          _isPlaying =
                                                                              false;
                                                                        });
                                                                      }
                                                                    : () {
                                                                        final currentAyahData =
                                                                            _getCurrentAyahData();
                                                                        _playAudio(
                                                                          currentAyahData[
                                                                              'surah'],
                                                                          currentAyahData[
                                                                              'ayah'],
                                                                        );
                                                                      },
                                                          ),
                                                        ],
                                                      ),
                                                  ],
                                                ),
                                                SizedBox(
                                                    height:
                                                        getVerticalPadding()),
                                                Container(
                                                  decoration: _forgottenAyahs[
                                                                  widget
                                                                      .pageNumber]
                                                              ?.contains(
                                                                  _currentAyah) ??
                                                          false
                                                      ? BoxDecoration(
                                                          color: Colors.orange
                                                              .withOpacity(0.2),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(4),
                                                        )
                                                      : null,
                                                  child: RichText(
                                                    textAlign:
                                                        TextAlign.justify,
                                                    textDirection:
                                                        TextDirection.rtl,
                                                    text: TextSpan(
                                                      style: TextStyle(
                                                        fontFamily:
                                                            'Scheherazade',
                                                        fontSize:
                                                            getQuranFontSize(),
                                                        height: 1.5,
                                                        letterSpacing: 0,
                                                      ),
                                                      children: [
                                                        TajweedParser
                                                            .parseTajweedText(
                                                          (() {
                                                            String fullText =
                                                                '';
                                                            for (var i = 0;
                                                                i <
                                                                    _pageAyahs
                                                                        .length;
                                                                i++) {
                                                              var ayah =
                                                                  _pageAyahs[i];
                                                              final ayahIndex =
                                                                  i + 1;

                                                              if (_fullyRevealedAyahs
                                                                  .contains(
                                                                      ayahIndex)) {
                                                                // Second click - show full ayah
                                                                String cleanVerse = ayah[
                                                                        'verse']
                                                                    .toString()
                                                                    .replaceAll(
                                                                        '\n',
                                                                        ' ')
                                                                    .replaceAll(
                                                                        RegExp(
                                                                            r'\s+'),
                                                                        ' ');
                                                                fullText +=
                                                                    '﴿${ayah['ayah']}﴾ $cleanVerse ';
                                                              } else if (_partiallyRevealedAyahs
                                                                  .contains(
                                                                      ayahIndex)) {
                                                                // First click - show first word
                                                                String firstWord = ayah[
                                                                        'verse']
                                                                    .toString()
                                                                    .replaceAll(
                                                                        '\n',
                                                                        ' ')
                                                                    .split(
                                                                        ' ')[0];
                                                                fullText +=
                                                                    '﴿${ayah['ayah']}﴾ $firstWord ... ';
                                                              } else if (_currentAyah >
                                                                  ayahIndex) {
                                                                // Show full text for previous ayahs
                                                                String cleanVerse = ayah[
                                                                        'verse']
                                                                    .toString()
                                                                    .replaceAll(
                                                                        '\n',
                                                                        ' ')
                                                                    .replaceAll(
                                                                        RegExp(
                                                                            r'\s+'),
                                                                        ' ');
                                                                fullText +=
                                                                    '﴿${ayah['ayah']}﴾ $cleanVerse ';
                                                              }
                                                            }

                                                            return fullText
                                                                    .isEmpty
                                                                ? 'أَعُوذُ بِاللَّهِ مِنَ الشَّيْطَانِ الرَّجِيمِ ﴿﴾ بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ'
                                                                : fullText
                                                                    .trim();
                                                          })(),
                                                          getQuranFontSize(),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                if (surahAyahs.isNotEmpty &&
                                                    _currentAyah <=
                                                        _pageAyahs.length +
                                                            1) ...[
                                                  Divider(
                                                    height:
                                                        getVerticalPadding() *
                                                            2,
                                                    thickness: 1,
                                                    color: Color(0xFF4F757C)
                                                        .withOpacity(0.3),
                                                  ),
                                                  Text(
                                                    _pageAyahs[(_currentAyah -
                                                                2)
                                                            .clamp(
                                                                0,
                                                                _pageAyahs
                                                                        .length -
                                                                    1)]['tafsir'] ??
                                                        '',
                                                    style: TextStyle(
                                                      fontSize:
                                                          getQuranFontSize() *
                                                              0.65,
                                                      height: 1.5,
                                                      color: Color(0xFF2B4141)
                                                          .withOpacity(0.8),
                                                    ),
                                                    textAlign:
                                                        TextAlign.justify,
                                                    textDirection:
                                                        TextDirection.rtl,
                                                  ),
                                                  SizedBox(
                                                      height:
                                                          getVerticalPadding() *
                                                              0.5),
                                                  Text(
                                                    _pageAyahs[(_currentAyah -
                                                                    2)
                                                                .clamp(
                                                                    0,
                                                                    _pageAyahs
                                                                            .length -
                                                                        1)]
                                                            ['translation'] ??
                                                        '',
                                                    style: TextStyle(
                                                      fontSize:
                                                          getQuranFontSize() *
                                                              0.65,
                                                      height: 1.5,
                                                      color: Color(0xFF2B4141)
                                                          .withOpacity(0.8),
                                                      fontStyle:
                                                          FontStyle.italic,
                                                    ),
                                                    textAlign:
                                                        TextAlign.justify,
                                                  ),
                                                ],
                                                Container(
                                                  child: Column(
                                                    children: [
                                                      Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .spaceBetween,
                                                        children: [
                                                          ElevatedButton.icon(
                                                            icon: Icon(
                                                              _showTajweedMenu
                                                                  ? Icons
                                                                      .visibility_off
                                                                  : Icons
                                                                      .visibility,
                                                              color: Color(
                                                                  0xFF417D7A),
                                                            ),
                                                            label: Text(
                                                              _showTajweedMenu
                                                                  ? 'Hide Tajweed Menu'
                                                                  : 'Show Tajweed Menu',
                                                              style: TextStyle(
                                                                  color: Color(
                                                                      0xFF417D7A)),
                                                            ),
                                                            style:
                                                                ElevatedButton
                                                                    .styleFrom(
                                                              backgroundColor:
                                                                  Colors
                                                                      .transparent,
                                                              elevation: 0,
                                                              side: BorderSide(
                                                                  color: Color(
                                                                      0xFF417D7A),
                                                                  width: 2),
                                                            ),
                                                            onPressed: () {
                                                              setState(() {
                                                                _showTajweedMenu =
                                                                    !_showTajweedMenu;
                                                              });
                                                            },
                                                          ),
                                                          if (widget
                                                                  .groupName !=
                                                              null)
                                                            StreamBuilder<
                                                                List<Comment>>(
                                                              stream: CommentsService()
                                                                  .getCommentsStream(
                                                                pageNumber: widget
                                                                    .pageNumber,
                                                                groupId: widget
                                                                    .groupName!,
                                                              ),
                                                              builder: (context,
                                                                  snapshot) {
                                                                final commentCount =
                                                                    snapshot.data
                                                                            ?.length ??
                                                                        0;
                                                                return TextButton
                                                                    .icon(
                                                                  icon: Icon(
                                                                    Icons
                                                                        .comment_outlined,
                                                                    color: Color(
                                                                        0xFF417D7A),
                                                                    size: 20,
                                                                  ),
                                                                  label: Text(
                                                                    'Thoughts : تدبر ($commentCount)',
                                                                    style:
                                                                        TextStyle(
                                                                      color: Color(
                                                                          0xFF417D7A),
                                                                      fontSize:
                                                                          14,
                                                                    ),
                                                                  ),
                                                                  style: TextButton
                                                                      .styleFrom(
                                                                    shape:
                                                                        RoundedRectangleBorder(
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                              8),
                                                                      side: BorderSide(
                                                                          color: Color(
                                                                              0xFF417D7A),
                                                                          width:
                                                                              1),
                                                                    ),
                                                                    padding: EdgeInsets.symmetric(
                                                                        horizontal:
                                                                            12,
                                                                        vertical:
                                                                            8),
                                                                  ),
                                                                  onPressed:
                                                                      () {
                                                                    showDialog(
                                                                      context:
                                                                          context,
                                                                      builder:
                                                                          (context) =>
                                                                              CommentsDialog(
                                                                        pageNumber:
                                                                            widget.pageNumber,
                                                                        groupId:
                                                                            widget.groupName!,
                                                                        userName:
                                                                            widget.userName ??
                                                                                'Anonymous',
                                                                      ),
                                                                    );
                                                                  },
                                                                );
                                                              },
                                                            ),
                                                        ],
                                                      ),
                                                      if (_showTajweedMenu) ...[
                                                        SizedBox(height: 8),
                                                        Text(
                                                          'Click on any rule to toggle it on/off\nاضغط على أي قاعدة لتشغيلها أو إيقافها',
                                                          textAlign:
                                                              TextAlign.center,
                                                          style: TextStyle(
                                                            fontSize: 14,
                                                            color: Colors
                                                                .grey[600],
                                                          ),
                                                        ),
                                                        SizedBox(height: 16),
                                                        Wrap(
                                                          spacing: 8,
                                                          runSpacing: 8,
                                                          alignment:
                                                              WrapAlignment
                                                                  .center,
                                                          children: [
                                                            // Your existing Tajweed toggle buttons go here
                                                            Wrap(
                                                              spacing: 8,
                                                              runSpacing: 8,
                                                              alignment:
                                                                  WrapAlignment
                                                                      .center,
                                                              children: [
                                                                _buildTajweedToggle(
                                                                  'Necessary Prolongation\nمد لازم',
                                                                  TajweedColor
                                                                      .darkRed,
                                                                  'necessary',
                                                                  (value) => setState(() =>
                                                                      TajweedParser
                                                                              .tajweedColorToggles['necessary'] =
                                                                          value),
                                                                ),
                                                                _buildTajweedToggle(
                                                                  'Obligatory Prolongation\nمد واجب متصل',
                                                                  TajweedColor
                                                                      .bloodRed,
                                                                  'obligatory',
                                                                  (value) => setState(() =>
                                                                      TajweedParser
                                                                              .tajweedColorToggles['obligatory'] =
                                                                          value),
                                                                ),
                                                                _buildTajweedToggle(
                                                                  'Permissible Prolongation\nمد جائز منفصل',
                                                                  TajweedColor
                                                                      .cuminRed,
                                                                  'permissible',
                                                                  (value) => setState(() =>
                                                                      TajweedParser
                                                                              .tajweedColorToggles['permissible'] =
                                                                          value),
                                                                ),
                                                                _buildTajweedToggle(
                                                                  'Silent Letters\nحروف لا تنطق',
                                                                  TajweedColor
                                                                      .gray,
                                                                  'silent',
                                                                  (value) => setState(() =>
                                                                      TajweedParser
                                                                              .tajweedColorToggles['silent'] =
                                                                          value),
                                                                ),
                                                                _buildTajweedToggle(
                                                                  'Qalqalah\nقلقلة',
                                                                  TajweedColor
                                                                      .lightBlue,
                                                                  'qalqalah',
                                                                  (value) => setState(() =>
                                                                      TajweedParser
                                                                              .tajweedColorToggles['qalqalah'] =
                                                                          value),
                                                                ),
                                                                _buildTajweedToggle(
                                                                  'Nasalization\nغنة',
                                                                  TajweedColor
                                                                      .green,
                                                                  'nasalization',
                                                                  (value) => setState(() =>
                                                                      TajweedParser
                                                                              .tajweedColorToggles['nasalization'] =
                                                                          value),
                                                                ),
                                                                _buildTajweedToggle(
                                                                  'Idgham\nادغام',
                                                                  TajweedColor
                                                                      .teal,
                                                                  'idgham',
                                                                  (value) => setState(() =>
                                                                      TajweedParser
                                                                              .tajweedColorToggles['idgham'] =
                                                                          value),
                                                                ),
                                                                _buildTajweedToggle(
                                                                  'Wasl\nوصل',
                                                                  TajweedColor
                                                                      .olive,
                                                                  'wasl',
                                                                  (value) => setState(() =>
                                                                      TajweedParser
                                                                              .tajweedColorToggles['wasl'] =
                                                                          value),
                                                                ),
                                                                _buildTajweedToggle(
                                                                  'Combined Letters\nحروف مركبة',
                                                                  TajweedColor
                                                                      .indigo,
                                                                  'combined',
                                                                  (value) => setState(() =>
                                                                      TajweedParser
                                                                              .tajweedColorToggles['combined'] =
                                                                          value),
                                                                ),
                                                                _buildTajweedToggle(
                                                                  'Idgam/guana/ahkam\nادغام/غنة/احكام',
                                                                  TajweedColor
                                                                      .brown,
                                                                  'ahkam',
                                                                  (value) => setState(() =>
                                                                      TajweedParser
                                                                              .tajweedColorToggles['ahkam'] =
                                                                          value),
                                                                ),
                                                              ],
                                                            ),
                                                            // ... rest of your toggle buttons ...
                                                          ],
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
            floatingActionButton: Padding(
              padding: EdgeInsets.only(bottom: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back button
                  Padding(
                    padding: EdgeInsets.only(left: 32.0),
                    child: FloatingActionButton.small(
                      heroTag: 'backButton',
                      onPressed: _showPreviousAyah,
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Color(0xFF417D7A), width: 2),
                      ),
                      child: Transform.rotate(
                        angle: pi, // Rotate 180 degrees
                        child: Icon(
                          Icons.refresh, // Changed from arrow_back to refresh
                          color: Color(0xFF417D7A),
                          size: 20,
                        ),
                      ),
                      tooltip: getTranslation('previous_ayah'),
                    ),
                  ),
                  // Existing buttons
                  Row(
                    children: [
                      FloatingActionButton.small(
                        heroTag: 'markForgotten',
                        onPressed: _markAyahAsForgotten,
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Color(0xFF417D7A), width: 2),
                        ),
                        child: Icon(
                          Icons.close,
                          color: Color(0xFF417D7A),
                          size: 20,
                        ),
                        tooltip: 'Incorrect - Mark for review',
                      ),
                      FloatingActionButton.small(
                        heroTag: 'resetReview',
                        onPressed: _resetForgottenAyahs,
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Color(0xFF417D7A), width: 2),
                        ),
                        child: Icon(
                          Icons.check,
                          color: Color(0xFF2B4141),
                          size: 20,
                        ),
                        tooltip: 'Correct - Remove from review',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_kidsMode)
          ..._celebrationStyles
              .asMap()
              .entries
              .map((entry) => Align(
                    alignment: entry.value['alignment'],
                    child: ConfettiWidget(
                      confettiController: _confettiControllers[entry.key],
                      blastDirection: entry.value['direction'].toDouble(),
                      maxBlastForce: entry.value['type'] == 'fireworks'
                          ? 30.0
                          : 20.0, // Increased force
                      minBlastForce: entry.value['type'] == 'fireworks'
                          ? 15.0
                          : 10.0, // Increased force
                      emissionFrequency:
                          entry.value['type'] == 'birthday' ? 0.1 : 0.05,
                      numberOfParticles:
                          entry.value['particles'] * 2, // Doubled particles
                      gravity: entry.value['type'] == 'fireworks' ? 0.1 : 0.2,
                      colors: entry.value['colors'],
                      minimumSize: const Size(10, 10), // Increased minimum size
                      maximumSize: entry.value['type'] == 'fireworks'
                          ? const Size(
                              20, 20) // Increased maximum size for fireworks
                          : const Size(
                              15, 15), // Increased maximum size for others
                      particleDrag: 0.05,
                      createParticlePath: (size) {
                        switch (entry.value['type']) {
                          case 'birthday':
                            return Path()
                              ..addOval(Rect.fromCircle(
                                center: Offset(0, 0),
                                radius: 2,
                              ));
                          case 'fireworks':
                            return Path()
                              ..addPolygon([
                                Offset(-2, -2),
                                Offset(2, -2),
                                Offset(2, 2),
                                Offset(-2, 2),
                              ], true);
                          case 'star':
                            return Path()
                              ..addPolygon([
                                Offset(0, -3),
                                Offset(1, -1),
                                Offset(3, -1),
                                Offset(1.5, 1),
                                Offset(2, 3),
                                Offset(0, 2),
                                Offset(-2, 3),
                                Offset(-1.5, 1),
                                Offset(-3, -1),
                                Offset(-1, -1),
                              ], true);
                          case 'diamond':
                            return Path()
                              ..addPolygon([
                                Offset(0, -3),
                                Offset(2, 0),
                                Offset(0, 3),
                                Offset(-2, 0),
                              ], true);
                          case 'rain':
                            return Path()..addOval(Rect.fromLTWH(0, 0, 1.5, 4));
                          case 'spiral':
                            return Path()
                              ..addArc(
                                  Rect.fromCircle(
                                      center: Offset(0, 0), radius: 3),
                                  0,
                                  pi * 1.5);
                          case 'fountain':
                            return Path()
                              ..moveTo(0, -3)
                              ..quadraticBezierTo(3, 0, 0, 3)
                              ..quadraticBezierTo(-3, 0, 0, -3);
                          case 'glitter':
                            return Path()
                              ..addOval(Rect.fromCircle(
                                  center: Offset(0, 0), radius: 1));
                          case 'sweep':
                            return Path()
                              ..addArc(
                                  Rect.fromCircle(
                                      center: Offset(0, 0), radius: 2),
                                  0,
                                  pi);
                          default:
                            return Path()..addRect(Rect.fromLTWH(0, 0, 2, 2));
                        }
                      },
                      blastDirectionality: entry.value['type'] == 'birthday'
                          ? BlastDirectionality.explosive
                          : BlastDirectionality.directional,
                    ),
                  ))
              .toList(),
        if (_showClickHint)
          Positioned.fill(
            child: Material(
              color: Colors.black54,
              child: InkWell(
                onTap: _handleFirstClick,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.touch_app,
                        color: Colors.white,
                        size: 48,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Tap on the page to get next ayah',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (widget.isGroupReading) _buildRoomInfo(),
      ],
    );
  }

  Widget _buildTajweedToggle(
      String label, Color color, String key, Function(bool) onToggle) {
    return GestureDetector(
      onTap: () {
        onToggle(!TajweedParser.tajweedColorToggles[key]!);
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: TajweedParser.tajweedColorToggles[key]!
              ? color
              : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color, width: 2),
        ),
        child: Text(
          label,
          style: TextStyle(
            color:
                TajweedParser.tajweedColorToggles[key]! ? Colors.white : color,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

bool isRTL(AppLanguage language) {
  return language == AppLanguage.arabic || language == AppLanguage.urdu;
}
