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
import '../widgets/comments_dialog.dart';
import '../services/comments_service.dart';
import '../models/comment.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/main_surah_view.dart';
import '../pages/quran_image_page.dart';
import '../utils/khatma_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import '../screens/legal_pages.dart';

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

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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
      routes: {
        '/terms': (context) => TermsOfServicePage(),
        '/privacy': (context) => PrivacyPolicyPage(),
      },
      navigatorKey: navigatorKey,
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

  // Add search controller and state variables
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  List<int> _searchResults = [];

  // Add scroll controller for navigation
  final ScrollController _scrollController = ScrollController();

  // Map to store surah item positions
  final Map<int, double> _surahPositions = {};

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
      'show_first_word_enabled': 'پہلا الفاظ دکھانے کا موڈڈ فعال',
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

  // Add search-related translations
  void _initSearchTranslations() {
    translations[AppLanguage.arabic]?['search_surah'] = 'البحث عن سورة';
    translations[AppLanguage.english]?['search_surah'] = 'Search Surah';
    translations[AppLanguage.spanish]?['search_surah'] = 'Buscar Sura';
    translations[AppLanguage.hindi]?['search_surah'] = 'सूरह खोजें';
    translations[AppLanguage.russian]?['search_surah'] = 'Поиск суры';
    translations[AppLanguage.chinese]?['search_surah'] = '搜索章节';
    translations[AppLanguage.turkish]?['search_surah'] = 'Sure Ara';
    translations[AppLanguage.urdu]?['search_surah'] = 'سورہ تلاش کریں';
    translations[AppLanguage.indonesian]?['search_surah'] = 'Cari Surah';
  }

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
    _initSearchTranslations();

    // Add post-frame callback to calculate surah positions
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateSurahPositions();
    });

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

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Method to calculate surah positions in the list
  void _calculateSurahPositions() {
    // This will be called after the list is built
    for (int i = 1; i <= 114; i++) {
      final context = _getSurahContext(i);
      if (context != null) {
        final RenderBox box = context.findRenderObject() as RenderBox;
        final position = box.localToGlobal(Offset.zero).dy;
        _surahPositions[i] = position;
      }
    }
  }

  // Helper method to get the build context for a surah
  BuildContext? _getSurahContext(int surahNum) {
    try {
      return _surahKeys[surahNum]?.currentContext;
    } catch (e) {
      return null;
    }
  }

  // Map to store keys for each surah
  final Map<int, GlobalKey> _surahKeys = {
    for (int i = 1; i <= 114; i++) i: GlobalKey(),
  };

  // Add search method
  void _performSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    final results = <int>[];
    final lowercaseQuery = query.toLowerCase();

    // Search by surah name (Arabic and English)
    for (int i = 1; i <= 114; i++) {
      final surahName = _surahInfo[i]!['name']!.toLowerCase();
      final surahNameEn = _surahInfo[i]!['name_en']!.toLowerCase();
      final surahNumber = i.toString();

      if (surahName.contains(lowercaseQuery) ||
          surahNameEn.contains(lowercaseQuery) ||
          surahNumber == query) {
        results.add(i);
      }
    }

    setState(() {
      _searchResults = results;
      _isSearching = true;
    });
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
    if (widget.groupName == null || widget.khatmaName == null) return;

    // Calculate juz progress
    final allPagesRead = roomDetails!['pages']
        .entries
        .where((page) => page.value['completed'] == true)
        .map((page) => int.parse(page.key))
        .toList();

    final uncompletedJuz = <int>[];
    final juzPages = {
      1: [1, 21],
      2: [22, 41],
      3: [42, 61],
      4: [62, 81],
      5: [82, 101],
      6: [102, 121],
      7: [122, 141],
      8: [142, 161],
      9: [162, 181],
      10: [182, 201],
      11: [202, 221],
      12: [222, 241],
      13: [242, 261],
      14: [262, 281],
      15: [282, 301],
      16: [302, 321],
      17: [322, 341],
      18: [342, 361],
      19: [362, 381],
      20: [382, 401],
      21: [402, 421],
      22: [422, 441],
      23: [442, 461],
      24: [462, 481],
      25: [482, 501],
      26: [502, 521],
      27: [522, 541],
      28: [542, 561],
      29: [562, 581],
      30: [582, 604],
    };

    for (int juz = 1; juz <= 30; juz++) {
      final startPage = juzPages[juz]![0];
      final endPage = juzPages[juz]![1];

      final pagesInJuz = allPagesRead
          .where((page) => page >= startPage && page <= endPage)
          .toList();

      if (pagesInJuz.length < (endPage - startPage + 1)) {
        uncompletedJuz.add(juz);
      }
    }

    final uncompletedJuzInfo = uncompletedJuz.isEmpty
        ? 'All juz completed! 🎉'
        : ' ${uncompletedJuz.join(', ')}';

    final roomStatus = KhatmaUtils.generateKhatmaStatus({
      ...?roomDetails,
      'groupName': widget.groupName,
      'khatmaName': widget.khatmaName,
    });

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
              Text('Unread Juz:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text(uncompletedJuzInfo),
              Divider(),
              SelectableText(roomStatus),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            icon: Icon(Icons.copy),
            label: Text('Copy Status'),
            onPressed: () {
              Clipboard.setData(ClipboardData(
                  text: '$roomStatus\n\n Unread Juz :\n$uncompletedJuzInfo'));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Status copied to clipboard!')),
              );
            },
          ),
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
        .take(20) // Show last 5 completed pages
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

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline, color: Colors.white, size: 20),
          SizedBox(width: 4),
          Text(
            '${roomDetails!['members']?.length ?? 0} members',
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  // Add this field
  Widget _buildThoughtsButton() {
    if (widget.groupName == null) return Container();

    return StreamBuilder<Map<int, int>>(
      stream: _getCommentsCountStream(),
      builder: (context, snapshot) {
        final commentsPerPage = snapshot.data ?? {};
        final totalComments =
            commentsPerPage.values.fold(0, (sum, count) => sum + count);

        return TextButton.icon(
          icon: Icon(Icons.comment_outlined, color: Colors.white),
          label: Text(
            'Thoughts ($totalComments)',
            style: TextStyle(color: Colors.white),
          ),
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('Pages with Thoughts'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: commentsPerPage.entries
                        .where((e) => e.value > 0)
                        .toList()
                        .sorted((a, b) => b.value.compareTo(a.value))
                        .map((e) => ListTile(
                              leading: Icon(Icons.comment),
                              title: Text('Page ${e.key}'),
                              trailing: Text('${e.value} thoughts'),
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => QuranImagePage(
                                      pageNumber: e.key,
                                      groupName: widget.groupName,
                                      khatmaName: widget.khatmaName,
                                      userName: widget.userName,
                                      isGroupReading: true,
                                    ),
                                  ),
                                );
                              },
                            ))
                        .toList(),
                  ),
                ),
                actions: [
                  TextButton(
                    child: Text('Close'),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Stream<Map<int, int>> _getCommentsCountStream() {
    return FirebaseFirestore.instance
        .collection('quranRooms')
        .doc(widget.groupName)
        .collection('comments')
        .snapshots()
        .map((snapshot) {
      Map<int, int> counts = {};
      for (var doc in snapshot.docs) {
        final pageNumber = doc.data()['pageNumber'] as int;
        counts[pageNumber] = (counts[pageNumber] ?? 0) + 1;
      }
      return counts;
    });
  }

  @override
  Widget build(BuildContext context) {
    final surahPages = _getSurahPages();

    // Update the special pages reference
    final Map<int, List<int>> specialPages = SurahData.specialPages;

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        toolbarHeight: 60,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: LayoutBuilder(
          builder: (context, constraints) {
            final showText =
                constraints.maxWidth > 600; // Adjust breakpoint as needed
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: BouncingScrollPhysics(),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  // Settings Menu (Three Dots)
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: Colors.white),
                    onSelected: (String result) {
                      switch (result) {
                        case 'language':
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                                builder: (context) => LanguageSelectionPage()),
                          );
                          break;
                        case 'tutorial':
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => TutorialPage(
                                selectedLanguage: widget.selectedLanguage,
                              ),
                            ),
                          );
                          break;
                        case 'feedback':
                          showDialog(
                            context: context,
                            builder: (context) => FeedbackDialog(),
                          );
                          break;
                        case 'terms':
                          Navigator.pushNamed(context, '/terms');
                          break;
                        case 'privacy':
                          Navigator.pushNamed(context, '/privacy');
                          break;
                        case 'private':
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (context) => SimpleList(
                                selectedLanguage: widget.selectedLanguage,
                                isGroupReading: false,
                              ),
                            ),
                          );
                          break;
                      }
                    },
                    itemBuilder: (BuildContext context) =>
                        <PopupMenuEntry<String>>[
                      const PopupMenuItem<String>(
                        value: 'language',
                        child: Row(
                          children: [
                            Icon(Icons.language, color: Colors.black),
                            SizedBox(width: 8),
                            Text('Change Language'),
                          ],
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'tutorial',
                        child: Row(
                          children: [
                            Icon(Icons.help_outline, color: Colors.black),
                            SizedBox(width: 8),
                            Text('Tutorial'),
                          ],
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'feedback',
                        child: Row(
                          children: [
                            Icon(Icons.feedback_outlined, color: Colors.black),
                            SizedBox(width: 8),
                            Text('Send Feedback'),
                          ],
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'terms',
                        child: Row(
                          children: [
                            Icon(Icons.description, color: Colors.black),
                            SizedBox(width: 8),
                            Text('Terms of Service'),
                          ],
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'privacy',
                        child: Row(
                          children: [
                            Icon(Icons.privacy_tip, color: Colors.black),
                            SizedBox(width: 8),
                            Text('Privacy Policy'),
                          ],
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'private',
                        child: Row(
                          children: [
                            Icon(Icons.person, color: Colors.black),
                            SizedBox(width: 8),
                            Text('Private Reading'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // Room Info and Thoughts Button
                  if (widget.groupName != null) ...[
                    _buildRoomInfo(),
                    _buildThoughtsButton(),
                  ],
                  // Group Icon
                  IconButton(
                    icon: Icon(Icons.group, color: Colors.white),
                    tooltip: widget.groupName != null
                        ? '${widget.groupName?.split(' ')[0]} - ${widget.khatmaName?.split(' ')[0]}'
                        : 'Group Reading',
                    onPressed: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => QuranRoomScreen(
                          selectedLanguage: widget.selectedLanguage,
                          isGroupReading: true,
                        ),
                      ),
                    ),
                  ),
                  // Optional text labels
                  if (showText) ...[
                    if (widget.groupName != null)
                      Text(
                        ' ${widget.groupName?.split(' ')[0]} - ${widget.khatmaName?.split(' ')[0]}',
                        style: TextStyle(color: Colors.white),
                      ),
                  ],
                ],
              ),
            );
          },
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(50),
          child: Column(
            children: [
              // Search bar
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: getTranslation('search_surah'),
                    hintStyle: TextStyle(color: Colors.white70),
                    prefixIcon: Icon(Icons.search, color: Colors.white70),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: Colors.white70),
                            onPressed: () {
                              _searchController.clear();
                              _performSearch('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white24,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: _performSearch,
                ),
              ),
              LinearProgressIndicator(
                backgroundColor: Colors.white24,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                value: 0,
              ),
            ],
          ),
        ),
      ),
      body: _isSearching
          ? (_searchResults.isNotEmpty
              ? _buildSearchResults(surahPages, specialPages)
              : _buildNoResultsFound())
          : ListView.builder(
              controller: _scrollController,
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
                  key: _surahKeys[surahNum],
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
                            Text('$pageNum'),
                            SizedBox(width: 8),
                            if (widget.isGroupReading &&
                                roomDetails != null &&
                                (roomDetails?['pages']
                                            as Map?)?[pageNum.toString()]
                                        ?['completed'] ==
                                    true)
                              Expanded(
                                child: Text(
                                  '✓  ${(roomDetails?['pages'] as Map?)?[pageNum.toString()]?['completedBy'] ?? 'Unknown'}',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            // Use cached due item counts
                            if (_srsScheduler.getDueItemCounts()[pageNum] !=
                                null)
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
                          // Show dialog to choose view type
                          final viewType = await showDialog<String>(
                            context: context,
                            builder: (BuildContext context) => AlertDialog(
                              title: Text('Select View Type'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    leading: Icon(Icons.text_fields),
                                    title: Text('memorize (حفظ) '),
                                    onTap: () => Navigator.pop(context, 'text'),
                                  ),
                                  ListTile(
                                    leading: Icon(Icons.image),
                                    title: Text('Read (تجويد) '),
                                    onTap: () =>
                                        Navigator.pop(context, 'image'),
                                  ),
                                ],
                              ),
                            ),
                          );

                          if (viewType != null) {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => viewType == 'text'
                                    ? SurahPage(
                                        pageNumber: pageNum,
                                        currentAyah: 1,
                                        onAyahChanged: (newAyah) {
                                          setState(() {
                                            _currentAyahNumbers[pageNum] = 1;
                                          });
                                        },
                                        initialSurah:
                                            multipleSurahs.contains(surahNum)
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
                                        selectedLanguage:
                                            widget.selectedLanguage,
                                        groupName: widget.groupName,
                                        khatmaName: widget.khatmaName,
                                        userName: widget.userName,
                                        isGroupReading: widget.isGroupReading,
                                      )
                                    : QuranImagePage(
                                        pageNumber: pageNum,
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
                          }
                        },
                      );
                    }).toList(),
                  ),
                );
              },
            ),
    );
  }

  // Add a widget to show when no search results are found
  Widget _buildNoResultsFound() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            'No surahs found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Try a different search term',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 24),
          TextButton.icon(
            icon: Icon(Icons.clear),
            label: Text('Clear Search'),
            onPressed: () {
              setState(() {
                _searchController.clear();
                _isSearching = false;
                _searchResults = [];
              });
            },
          ),
        ],
      ),
    );
  }

  // Build search results widget
  Widget _buildSearchResults(
      Map<int, List<int>> surahPages, Map<int, List<int>> specialPages) {
    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final surahNum = _searchResults[index];
        final surahData = _surahInfo[surahNum]!;
        final pages = surahPages[surahNum]!;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Card(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 2,
            child: InkWell(
              onTap: () {
                // Navigate to the surah in the main list
                setState(() {
                  _searchController.clear();
                  _isSearching = false;
                });

                // Use a post-frame callback to ensure the list is built
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  // Find the position of the surah in the list
                  final position =
                      (surahNum - 1) * 50.0; // Approximate position

                  // Scroll to the position
                  _scrollController.animateTo(
                    position,
                    duration: Duration(milliseconds: 500),
                    curve: Curves.easeInOut,
                  );
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF417D7A),
                          ),
                          child: Center(
                            child: Text(
                              '$surahNum',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _surahInfo[surahNum]!['name']!,
                              style: TextStyle(
                                fontSize: 18,
                                fontFamily: 'Scheherazade',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Pages: ${pages.first}-${pages.last}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Text(
                      _surahInfo[surahNum]!['name_en']!,
                      style: TextStyle(
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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
  bool _showImageView = false;

  @override
  Widget build(BuildContext context) {
    return MainSurahView(
      pageNumber: widget.pageNumber,
      currentAyah: widget.currentAyah,
      showImageView: _showImageView,
      onToggleImageView: () {
        setState(() {
          _showImageView = !_showImageView;
        });
      },
      initialSurah: widget.initialSurah,
      autoPlayEnabled: widget.autoPlayEnabled,
      onAutoPlayChanged: widget.onAutoPlayChanged,
      showFirstWordOnly: widget.showFirstWordOnly,
      onShowFirstWordOnlyChanged: widget.onShowFirstWordOnlyChanged,
      selectedLanguage: widget.selectedLanguage,
      groupName: widget.groupName,
      khatmaName: widget.khatmaName,
      userName: widget.userName,
      isGroupReading: widget.isGroupReading,
      onAyahChanged: widget.onAyahChanged,
    );
  }
}
