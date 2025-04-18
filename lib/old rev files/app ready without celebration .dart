import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import '../data/surah_data.dart';
import '../services/srs_scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart' as shared_prefs;

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
  final prefs = await shared_prefs.SharedPreferences.getInstance();
  final String? savedLanguage = prefs.getString('language');

  runApp(MyApp(initialLanguage: savedLanguage));
}

class MyApp extends StatelessWidget {
  final String? initialLanguage;

  const MyApp({Key? key, this.initialLanguage}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        scaffoldBackgroundColor: Color(0xFFF2F4F3),
        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xFF4F757C),
          elevation: 0,
        ),
        colorScheme: ColorScheme.light(
          primary: Color(0xFF417D7A),
          secondary: Color(0xFF2B4141),
        ),
      ),
      home: initialLanguage == null
          ? LanguageSelectionPage()
          : Scaffold(
              appBar: AppBar(
                toolbarHeight: kToolbarHeight,
                title: const Text('Qurany'),
              ),
              body: SimpleList(
                selectedLanguage: AppLanguage.values.firstWhere(
                  (e) => e.toString() == initialLanguage,
                  orElse: () => AppLanguage.english,
                ),
              ),
            ),
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
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Color(0xFF417D7A),
                      padding:
                          EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Color(0xFF417D7A), width: 2),
                      ),
                      minimumSize: Size(double.infinity, 60),
                    ),
                    onPressed: () async {
                      final prefs =
                          await shared_prefs.SharedPreferences.getInstance();
                      await prefs.setString('language', entry.key.toString());

                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => Scaffold(
                            appBar: AppBar(
                              toolbarHeight: kToolbarHeight,
                              title: const Text('Qurany'),
                            ),
                            body: SimpleList(
                              selectedLanguage: entry.key,
                            ),
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
    );
  }
}

class SimpleList extends StatefulWidget {
  final AppLanguage selectedLanguage;

  const SimpleList({
    Key? key,
    this.selectedLanguage = AppLanguage.english,
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
    },
    // Add translations for Urdu and Indonesian here
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

  @override
  Widget build(BuildContext context) {
    final surahPages = _getSurahPages();

    // Update the special pages reference
    final Map<int, List<int>> specialPages = SurahData.specialPages;

    return ListView.builder(
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
                    // Use cached due item counts
                    if (_srsScheduler.getDueItemCounts()[pageNum] != null)
                      Badge(
                        label: Text(
                            '${_srsScheduler.getDueItemCounts()[pageNum]}'),
                      ),
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
                onTap: () {
                  Navigator.push(
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
                        initialSurah:
                            multipleSurahs.contains(surahNum) ? surahNum : null,
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
                      ),
                    ),
                  );
                },
              );
            }).toList(),
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
    },
    // Add translations for Urdu and Indonesian here
  };

  String getTranslation(String key) {
    return translations[widget.selectedLanguage]?[key] ??
        translations[AppLanguage.english]![key]!;
  }

  @override
  void initState() {
    super.initState();
    _currentAyah = widget.currentAyah;
    _showFirstWordOnly = widget.showFirstWordOnly;
    _autoPlayEnabled = widget.autoPlayEnabled;
    _audioPlayer = AudioPlayer();

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
  }

  @override
  void dispose() {
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load all required text files
      final mappingText =
          await rootBundle.loadString('assets/Txt files/page_mapping.txt');
      final quranText =
          await rootBundle.loadString('assets/Txt files/quran-uthmani (1).txt');

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
          'tafsir': _tafsirMap[mapKey] ?? '',
          'translation': _translationMap[mapKey] ?? '',
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
      await _audioPlayer.dispose();
      _audioPlayer = AudioPlayer();

      // Format surah and ayah numbers to 3 digits
      final surahStr = surah.toString().padLeft(3, '0');
      final ayahStr = ayah.toString().padLeft(3, '0');
      final audioFile = 'audio_files_Hudhaify/$surahStr$ayahStr.mp3';

      setState(() {
        _isPlaying = true;
      });

      await _audioPlayer.play(AssetSource(audioFile));

      _audioPlayer.onPlayerComplete.listen((event) {
        setState(() {
          _isPlaying = false;
        });
      });
    } catch (e) {
      print('Error playing audio: $e');
      setState(() {
        _isPlaying = false;
      });
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
            ),
          ),
        );
      } else {
        _navigateToNextPage();
      }
    }
  }

  void _navigateToNextPage() {
    if (widget.pageNumber < 604) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => SurahPage(
            pageNumber: widget.pageNumber + 1,
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
          ),
        ),
      );
    }
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

  void _resetForgottenAyahs() {
    setState(() {
      _forgottenAyahs[widget.pageNumber]?.remove(_currentAyah);

      // Mark as reviewed in SRS system
      _srsScheduler.markReviewed(widget.pageNumber, _currentAyah, true);
    });
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Calculate responsive font sizes based on screen dimensions
    double getQuranFontSize() {
      if (screenWidth <= 600) return screenWidth * 0.06;
      if (screenWidth <= 1024) return screenWidth * 0.04;
      return 24.0;
    }

    double getSymbolFontSize() {
      if (screenWidth <= 600) return screenWidth * 0.04;
      if (screenWidth <= 1024) return screenWidth * 0.025;
      return 22.0;
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

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: isStartOfSurah ? kToolbarHeight * 1.5 : kToolbarHeight,
        title: Column(
          children: [
            Text('Page ${widget.pageNumber}'),
            if (isStartOfSurah &&
                currentSurah != 9) // Don't show Bismillah for Surah 9
              Container(
                width: double.infinity,
                alignment: Alignment.center,
                child: Text(
                  _surahBismillah ?? 'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ',
                  style: TextStyle(
                    fontFamily: 'Scheherazade',
                    fontSize: 18,
                    color: Colors.white70,
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
                    color: _autoPlayEnabled ? Color(0xFF417D7A) : Colors.grey,
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
                  icon: Icon(Icons.arrow_back_ios),
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
                              ),
                            ),
                          );
                        }
                      : null,
                ),
                IconButton(
                  icon: Icon(Icons.arrow_forward_ios),
                  onPressed: widget.pageNumber < 604
                      ? () => _navigateToNextPage()
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_forgottenAyahs[widget.pageNumber]?.isNotEmpty ?? false)
            Container(
              padding: EdgeInsets.all(8),
              color: Color(0xFF417D7A).withOpacity(0.1),
              child: Text(
                '${getTranslation('ayahs_for_review')} ${_forgottenAyahs[widget.pageNumber]?.length ?? 0}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.secondary,
                ),
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
                                      borderRadius: BorderRadius.circular(15),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          spreadRadius: 2,
                                          blurRadius: 10,
                                          offset: Offset(5, 5),
                                        ),
                                      ],
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: getHorizontalPadding(),
                                        vertical: getVerticalPadding(),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'سورة ${_surahInfo[surahNumber]!['name']}',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      color: Color(0xFF2B4141),
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
                                                            ? Icons.repeat_one
                                                            : Icons
                                                                .repeat_one_outlined,
                                                        color: _autoPlayEnabled
                                                            ? Color(0xFF417D7A)
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
                                                            : Icons.play_arrow,
                                                        color:
                                                            Color(0xFF417D7A),
                                                      ),
                                                      onPressed: _isPlaying
                                                          ? () {
                                                              _audioPlayer
                                                                  .pause();
                                                              setState(() {
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
                                              height: getVerticalPadding()),
                                          RichText(
                                            textAlign: TextAlign.justify,
                                            textDirection: TextDirection.rtl,
                                            text: TextSpan(
                                              style: TextStyle(
                                                fontFamily: 'Scheherazade',
                                                fontSize: getQuranFontSize(),
                                                height: 1.5,
                                                letterSpacing: 0,
                                                color: Color(0xFF2B4141),
                                              ),
                                              children: surahAyahs.map((ayah) {
                                                final ayahIndex =
                                                    _pageAyahs.indexOf(ayah) +
                                                        1;
                                                final isPartiallyRevealed =
                                                    _partiallyRevealedAyahs
                                                        .contains(ayahIndex);
                                                final isFullyRevealed =
                                                    _fullyRevealedAyahs
                                                        .contains(ayahIndex);
                                                final isRevealed =
                                                    isPartiallyRevealed ||
                                                        isFullyRevealed;

                                                return TextSpan(
                                                  children: [
                                                    TextSpan(
                                                      text: _showFirstWordOnly
                                                          ? (isFullyRevealed
                                                              ? ayah['verse']
                                                              : (isPartiallyRevealed
                                                                  ? ayah['verse']
                                                                          .toString()
                                                                          .split(
                                                                              ' ')[0] +
                                                                      ' ...'
                                                                  : ''))
                                                          : ayah['verse'],
                                                      style: TextStyle(
                                                        fontFamily:
                                                            'Scheherazade',
                                                        fontSize:
                                                            getQuranFontSize(),
                                                        height: 1.5,
                                                        letterSpacing: 0,
                                                        color:
                                                            _showFirstWordOnly
                                                                ? (isRevealed
                                                                    ? (_forgottenAyahs[widget.pageNumber]?.contains(ayahIndex + 1) ??
                                                                            false
                                                                        ? const Color
                                                                            .fromARGB(
                                                                            255,
                                                                            66,
                                                                            10,
                                                                            10) // Light red for specific review ayah
                                                                        : Color(
                                                                            0xFF2B4141)) // Regular color
                                                                    : Colors
                                                                        .white)
                                                                : (isRevealed
                                                                    ? (_forgottenAyahs[widget.pageNumber]?.contains(ayahIndex +
                                                                                1) ??
                                                                            false
                                                                        ? const Color
                                                                            .fromARGB(
                                                                            255,
                                                                            66,
                                                                            10,
                                                                            10) // Light red for specific review ayah
                                                                        : Color(
                                                                            0xFF2B4141)) // Regular color
                                                                    : Colors
                                                                        .white),
                                                      ),
                                                    ),
                                                    TextSpan(
                                                      text:
                                                          ' ۝${ayah['ayah'].toString().replaceAll('0', '٠').replaceAll('1', '١').replaceAll('2', '٢').replaceAll('3', '٣').replaceAll('4', '٤').replaceAll('5', '٥').replaceAll('6', '٦').replaceAll('7', '٧').replaceAll('8', '٨').replaceAll('9', '٩')} ',
                                                      style: TextStyle(
                                                        fontFamily:
                                                            'Scheherazade',
                                                        fontSize:
                                                            getSymbolFontSize(),
                                                        color:
                                                            Color(0xFF417D7A),
                                                        letterSpacing: 0,
                                                        height: 1.2,
                                                        textBaseline:
                                                            TextBaseline
                                                                .alphabetic,
                                                      ),
                                                    ),
                                                  ],
                                                );
                                              }).toList(),
                                            ),
                                          ),
                                          if (surahAyahs.isNotEmpty &&
                                              _currentAyah <=
                                                  _pageAyahs.length + 1) ...[
                                            Divider(
                                              height: getVerticalPadding() * 2,
                                              thickness: 1,
                                              color: Color(0xFF4F757C)
                                                  .withOpacity(0.3),
                                            ),
                                            Text(
                                              _pageAyahs[(_currentAyah - 2)
                                                      .clamp(
                                                          0,
                                                          _pageAyahs.length -
                                                              1)]['tafsir'] ??
                                                  '',
                                              style: TextStyle(
                                                fontSize:
                                                    getQuranFontSize() * 0.65,
                                                height: 1.5,
                                                color: Color(0xFF2B4141)
                                                    .withOpacity(0.8),
                                              ),
                                              textAlign: TextAlign.justify,
                                              textDirection: TextDirection.rtl,
                                            ),
                                            SizedBox(
                                                height:
                                                    getVerticalPadding() * 0.5),
                                            Text(
                                              _pageAyahs[(_currentAyah - 2)
                                                          .clamp(
                                                              0,
                                                              _pageAyahs
                                                                      .length -
                                                                  1)]
                                                      ['translation'] ??
                                                  '',
                                              style: TextStyle(
                                                fontSize:
                                                    getQuranFontSize() * 0.65,
                                                height: 1.5,
                                                color: Color(0xFF2B4141)
                                                    .withOpacity(0.8),
                                                fontStyle: FontStyle.italic,
                                              ),
                                              textAlign: TextAlign.justify,
                                            ),
                                          ],
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
                child: Icon(
                  Icons.arrow_back,
                  color: Color(0xFF417D7A),
                  size: 20,
                ),
                tooltip: 'Previous Ayah',
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
    );
  }
}
