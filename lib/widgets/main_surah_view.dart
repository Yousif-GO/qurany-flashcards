import '../main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'dart:async'; // Add this import for StreamController
import '../widgets/feedback_dialog.dart';
import '../firebase_options.dart';
import '../widgets/comments_dialog.dart';
import '../services/comments_service.dart';
import '../models/comment.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MainSurahView extends StatefulWidget {
  final int pageNumber;
  final int currentAyah;
  final bool showImageView;
  final VoidCallback onToggleImageView;
  final int? initialSurah;
  final bool autoPlayEnabled;
  final Function(bool) onAutoPlayChanged;
  final bool showFirstWordOnly;
  final Function(bool) onShowFirstWordOnlyChanged;
  final AppLanguage selectedLanguage;
  final String? groupName;
  final String? khatmaName;
  final String? userName;
  final bool isGroupReading;
  final Function(int) onAyahChanged;

  const MainSurahView({
    Key? key,
    required this.pageNumber,
    required this.currentAyah,
    required this.showImageView,
    required this.onToggleImageView,
    this.initialSurah,
    this.autoPlayEnabled = true,
    required this.onAutoPlayChanged,
    this.showFirstWordOnly = false,
    required this.onShowFirstWordOnlyChanged,
    required this.selectedLanguage,
    this.groupName,
    this.khatmaName,
    this.userName,
    this.isGroupReading = false,
    required this.onAyahChanged,
  }) : super(key: key);

  @override
  State<MainSurahView> createState() => _MainSurahViewState();
}

class _MainSurahViewState extends State<MainSurahView> {
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

  // Add new state variables for Quran text selection and font size
  String _selectedQuranText = 'quran-uthmani-min.txt';
  double _quranFontSize = 24.0; // Default font size

  // Add reciter selection
  String _selectedReciter = 'Hudhaify_32kbps';

  // List of available Quran text files
  final List<Map<String, String>> _quranTextOptions = [
    {
      'value': 'quran-uthmani (1).txt',
      'label': 'Uthmani Script (ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَـٰلَمِينَ)',
      'fontFamily': '_Othmani',
    },
    {
      'value': 'quran-uthmani-min.txt',
      'label':
          'Uthmani Minimal (text with a minimal number of diacritics and symbols. (الحَمدُ لِلَّهِ رَبِّ العـٰلَمينَ)',
      'fontFamily': '_Othmani',
    }
  ];

  // List of available reciters (with smaller file sizes preferred)
  final List<Map<String, String>> _reciterOptions = [
    {
      'value': 'AbdulSamad_64kbps_QuranExplorer.Com',
      'label': 'Abdul Samad (64kbps)'
    },
    {
      'value': 'Abdul_Basit_Murattal_192kbps',
      'label': 'Abdul Basit Murattal (192kbps)'
    },
    {
      'value': 'Abdul_Basit_Murattal_64kbps',
      'label': 'Abdul Basit Murattal (64kbps)'
    },
    {
      'value': 'Abdullaah_3awwaad_Al-Juhaynee_128kbps',
      'label': 'Abdullah Awwad Al-Juhaynee (128kbps)'
    },
    {'value': 'Abdullah_Basfar_192kbps', 'label': 'Abdullah Basfar (192kbps)'},
    {'value': 'Abdullah_Basfar_32kbps', 'label': 'Abdullah Basfar (32kbps)'},
    {
      'value': 'Abdullah_Matroud_128kbps',
      'label': 'Abdullah Matroud (128kbps)'
    },
    {
      'value': 'Abdurrahmaan_As-Sudais_192kbps',
      'label': 'Abdurrahmaan As-Sudais (192kbps)'
    },
    {
      'value': 'Abdurrahmaan_As-Sudais_64kbps',
      'label': 'Abdurrahmaan As-Sudais (64kbps)'
    },
    {
      'value': 'Abu_Bakr_Ash-Shaatree_128kbps',
      'label': 'Abu Bakr Ash-Shaatree (128kbps)'
    },
    {
      'value': 'Abu_Bakr_Ash-Shaatree_64kbps',
      'label': 'Abu Bakr Ash-Shaatree (64kbps)'
    },
    {
      'value': 'Ahmed_ibn_Ali_al-Ajamy_128kbps_ketaballah.net',
      'label': 'Ahmed ibn Ali al-Ajamy (128kbps)'
    },
    {'value': 'Akram_AlAlaqimy_128kbps', 'label': 'Akram AlAlaqimy (128kbps)'},
    {'value': 'Alafasy_128kbps', 'label': 'Mishary Alafasy (128kbps)'},
    {'value': 'Alafasy_64kbps', 'label': 'Mishary Alafasy (64kbps)'},
    {
      'value': 'Ali_Hajjaj_AlSuesy_128kbps',
      'label': 'Ali Hajjaj AlSuesy (128kbps)'
    },
    {'value': 'Ali_Jaber_64kbps', 'label': 'Ali Jaber (64kbps)'},
    {'value': 'Ayman_Sowaid_64kbps', 'label': 'Ayman Sowaid (64kbps)'},
    {'value': 'aziz_alili_128kbps', 'label': 'Aziz Alili (128kbps)'},
    {'value': 'Fares_Abbad_64kbps', 'label': 'Fares Abbad (64kbps)'},
    {'value': 'Ghamadi_40kbps', 'label': 'Ghamadi (40kbps)'},
    {'value': 'Hani_Rifai_192kbps', 'label': 'Hani Rifai (192kbps)'},
    {'value': 'Hudhaify_128kbps', 'label': 'Hudhaify (128kbps)'},
    {'value': 'Hudhaify_32kbps', 'label': 'Hudhaify (32kbps)'},
    {'value': 'Husary_128kbps', 'label': 'Husary (128kbps)'},
    {'value': 'Husary_64kbps', 'label': 'Husary (64kbps)'},
    {'value': 'Ibrahim_Akhdar_32kbps', 'label': 'Ibrahim Akhdar (32kbps)'},
    {'value': 'Ibrahim_Akhdar_64kbps', 'label': 'Ibrahim Akhdar (64kbps)'},
    {'value': 'Karim_Mansoori_40kbps', 'label': 'Karim Mansoori (40kbps)'},
    {
      'value': 'khalefa_al_tunaiji_64kbps',
      'label': 'Khalefa Al Tunaiji (64kbps)'
    },
    {
      'value': 'Khaalid_Abdullaah_al-Qahtaanee_192kbps',
      'label': 'Khaalid Abdullaah al-Qahtaanee (192kbps)'
    },
    {
      'value': 'mahmoud_ali_al_banna_32kbps',
      'label': 'Mahmoud Ali Al Banna (32kbps)'
    },
    {'value': 'Maher_AlMuaiqly_64kbps', 'label': 'Maher Al Muaiqly (64kbps)'},
    {'value': 'MaherAlMuaiqly128kbps', 'label': 'Maher Al Muaiqly (128kbps)'},
    {'value': 'Menshawi_16kbps', 'label': 'Menshawi (16kbps)'},
    {
      'value': 'Minshawy_Mujawwad_192kbps',
      'label': 'Minshawy Mujawwad (192kbps)'
    },
    {
      'value': 'Mohammad_al_Tablaway_128kbps',
      'label': 'Mohammad al Tablaway (128kbps)'
    },
    {
      'value': 'Muhammad_AbdulKareem_128kbps',
      'label': 'Muhammad AbdulKareem (128kbps)'
    },
    {'value': 'Muhammad_Ayyoub_128kbps', 'label': 'Muhammad Ayyoub (128kbps)'},
    {'value': 'Muhammad_Ayyoub_32kbps', 'label': 'Muhammad Ayyoub (32kbps)'},
    {
      'value': 'Muhammad_Jibreel_128kbps',
      'label': 'Muhammad Jibreel (128kbps)'
    },
    {'value': 'Muhsin_Al_Qasim_192kbps', 'label': 'Muhsin Al Qasim (192kbps)'},
    {'value': 'Mustafa_Ismail_48kbps', 'label': 'Mustafa Ismail (48kbps)'},
    {'value': 'Nabil_Rifa3i_48kbps', 'label': 'Nabil Rifa3i (48kbps)'},
    {'value': 'Nasser_Alqatami_128kbps', 'label': 'Nasser Alqatami (128kbps)'},
    {'value': 'Sahl_Yassin_128kbps', 'label': 'Sahl Yassin (128kbps)'},
    {
      'value': 'Salaah_AbdulRahman_Bukhatir_128kbps',
      'label': 'Salaah AbdulRahman Bukhatir (128kbps)'
    },
    {'value': 'Salah_Al_Budair_128kbps', 'label': 'Salah Al Budair (128kbps)'},
    {
      'value': 'Saood_ash-Shuraym_128kbps',
      'label': 'Saood ash-Shuraym (128kbps)'
    },
    {'value': 'Yaser_Salamah_128kbps', 'label': 'Yaser Salamah (128kbps)'},
    {
      'value': 'Yasser_Ad-Dussary_128kbps',
      'label': 'Yasser Ad-Dussary (128kbps)'
    },
  ];

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

    // Load saved preferences for Quran text and font size
    _loadTextPreferences();

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

  Future<void> _loadTextPreferences() async {
    final prefs = await shared_prefs.SharedPreferences.getInstance();
    setState(() {
      _selectedQuranText =
          prefs.getString('selectedQuranText') ?? 'quran-uthmani (1).txt';
      _quranFontSize = prefs.getDouble('quranFontSize') ?? 24.0;
      _selectedReciter =
          prefs.getString('selectedReciter') ?? 'Hudhaify_32kbps';
    });
  }

  Future<void> _saveTextPreferences() async {
    final prefs = await shared_prefs.SharedPreferences.getInstance();
    await prefs.setString('selectedQuranText', _selectedQuranText);
    await prefs.setDouble('quranFontSize', _quranFontSize);
    await prefs.setString('selectedReciter', _selectedReciter);
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
          await rootBundle.loadString('assets/Txt files/${_selectedQuranText}');

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

      // Add first ayah of next page
      int nextPage = widget.pageNumber == 604 ? 1 : widget.pageNumber + 1;
      final nextPageAyahs = _pageMapping[nextPage.toString()] ?? [];
      if (nextPageAyahs.isNotEmpty) {
        final firstNextAyah = nextPageAyahs.first.split('|');
        final nextSurah = int.parse(firstNextAyah[0]);
        final nextAyah = int.parse(firstNextAyah[1]);
        final nextMapKey = '$nextSurah|$nextAyah';

        ayahs.add({
          'surah': nextSurah,
          'ayah': nextAyah,
          'verse': quranMap[nextMapKey] ?? '',
          'tafsir': _tafsirMap[nextMapKey] ?? '',
          'translation': _translationMap[nextMapKey] ?? '',
          'isNextPage': true, // Mark this ayah as belonging to next page
        });
      }

      setState(() {
        _pageAyahs = ayahs;
        _currentAyahData = [ayahs.first];
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
            'https://everyayah.com/data/${_selectedReciter}/${surahStr}${ayahStr}.mp3';
        await _audioPlayer.play(UrlSource(url));
      } else {
        // For mobile, use local file with download prompt
        final audioFile = await AudioService.getAudioPath(
            surahStr, ayahStr, _selectedReciter);
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
    } else if (reviewAyahs.isEmpty) {
      _navigateToNextPage();
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
      // Use the user-selected font size instead of calculating based on screen width
      return _quranFontSize;
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
                      child: Text(
                        _surahBismillah ??
                            'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ',
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
                // Add settings icon for text options
                IconButton(
                  icon: Icon(Icons.settings),
                  onPressed: () {
                    _showTextSettingsDialog(context);
                  },
                  tooltip: 'Text Settings',
                ),
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
                                                RichText(
                                                  textAlign: TextAlign.justify,
                                                  textDirection:
                                                      TextDirection.rtl,
                                                  text: TextSpan(
                                                    style: TextStyle(
                                                      fontFamily:
                                                          _getCurrentFontFamily(), // Use the dynamic font family
                                                      fontSize:
                                                          getQuranFontSize(),
                                                      height: 1.5,
                                                      color: Color(0xFF2B4141),
                                                    ),
                                                    children:
                                                        surahAyahs.map((ayah) {
                                                      final ayahIndex =
                                                          _pageAyahs.indexOf(
                                                                  ayah) +
                                                              1;
                                                      final isPartiallyRevealed =
                                                          _partiallyRevealedAyahs
                                                              .contains(
                                                                  ayahIndex);
                                                      final isFullyRevealed =
                                                          _fullyRevealedAyahs
                                                              .contains(
                                                                  ayahIndex);
                                                      final isRevealed =
                                                          isPartiallyRevealed ||
                                                              isFullyRevealed;

                                                      if (ayah['isNextPage'] ==
                                                          true) {
                                                        return TextSpan(
                                                          children: [
                                                            TextSpan(
                                                              text:
                                                                  '\n\n━━━━ Next Page ━━━━\n\n',
                                                              style: TextStyle(
                                                                color: Color(
                                                                    0xFF417D7A),
                                                                fontSize:
                                                                    getQuranFontSize() *
                                                                        0.6,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                            ),
                                                            TextSpan(
                                                              text: _showFirstWordOnly
                                                                  ? (isFullyRevealed
                                                                      ? ayah[
                                                                          'verse']
                                                                      : (isPartiallyRevealed
                                                                          ? ayah['verse'].toString().split(' ')[0] +
                                                                              ' ...'
                                                                          : ''))
                                                                  : (isRevealed
                                                                      ? ayah[
                                                                          'verse']
                                                                      : ''),
                                                              style: TextStyle(
                                                                color: isRevealed
                                                                    ? (_forgottenAyahs[widget.pageNumber]?.contains(ayahIndex +
                                                                                1) ??
                                                                            false
                                                                        ? Colors
                                                                            .orange
                                                                        : Colors.grey[
                                                                            600]!)
                                                                    : Colors
                                                                        .white,
                                                                fontStyle:
                                                                    FontStyle
                                                                        .italic,
                                                              ),
                                                            ),
                                                          ],
                                                        );
                                                      }

                                                      return TextSpan(
                                                        children: [
                                                          // Ayah text with dynamic reveal
                                                          TextSpan(
                                                            text: _showFirstWordOnly
                                                                ? (isFullyRevealed
                                                                    ? ayah[
                                                                        'verse']
                                                                    : (isPartiallyRevealed
                                                                        ? ayah['verse'].toString().split(' ')[0] +
                                                                            ' ...'
                                                                        : ''))
                                                                : ayah['verse'],
                                                            style: TextStyle(
                                                              fontFamily:
                                                                  _getCurrentFontFamily(), // Use the dynamic font family
                                                              fontSize:
                                                                  getQuranFontSize(),
                                                              height: 1.5,
                                                              letterSpacing: 0,
                                                              color: _showFirstWordOnly
                                                                  ? (isRevealed
                                                                      ? (_forgottenAyahs[widget.pageNumber]?.contains(ayahIndex + 1) ??
                                                                              false
                                                                          ? Colors
                                                                              .orange
                                                                          : Color(
                                                                              0xFF2B4141))
                                                                      : Colors
                                                                          .white)
                                                                  : (isRevealed
                                                                      ? (_forgottenAyahs[widget.pageNumber]?.contains(ayahIndex + 1) ??
                                                                              false
                                                                          ? Colors
                                                                              .orange
                                                                          : Color(
                                                                              0xFF2B4141))
                                                                      : Colors
                                                                          .white),
                                                            ),
                                                          ),
                                                          // Use a background color to highlight the number

                                                          TextSpan(
                                                            text:
                                                                ' ${' ﴿' + (ayah['ayah'].toString()) + '﴾ '} ',
                                                            style: TextStyle(
                                                              fontFamily:
                                                                  _getCurrentFontFamily(), // Use the dynamic font family
                                                              fontSize:
                                                                  getQuranFontSize() *
                                                                      0.8,
                                                              color: Color(
                                                                  0xFF417D7A),
                                                            ),
                                                          ),
                                                        ],
                                                      );
                                                    }).toList(),
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
                                                  // Add this new section for comments
                                                  SizedBox(height: 8),
                                                  if (widget.groupName !=
                                                      null) // Only show comments for group reading
                                                    Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment.end,
                                                      children: [
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
                                                                  fontSize: 14,
                                                                ),
                                                              ),
                                                              style: TextButton
                                                                  .styleFrom(
                                                                shape:
                                                                    RoundedRectangleBorder(
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              8),
                                                                  side: BorderSide(
                                                                      color: Color(
                                                                          0xFF417D7A),
                                                                      width: 1),
                                                                ),
                                                                padding: EdgeInsets
                                                                    .symmetric(
                                                                        horizontal:
                                                                            12,
                                                                        vertical:
                                                                            8),
                                                              ),
                                                              onPressed: () {
                                                                showDialog(
                                                                  context:
                                                                      context,
                                                                  builder:
                                                                      (context) =>
                                                                          CommentsDialog(
                                                                    pageNumber:
                                                                        widget
                                                                            .pageNumber,
                                                                    groupId: widget
                                                                        .groupName!,
                                                                    userName: widget
                                                                            .userName ??
                                                                        'Anonymous',
                                                                  ),
                                                                );
                                                              },
                                                            );
                                                          },
                                                        ),
                                                      ],
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

  // Add a method to show the text settings dialog
  void _showTextSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Text & Audio Settings'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Quran Text:'),
                    DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedQuranText,
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedQuranText = newValue;
                          });
                        }
                      },
                      items: _quranTextOptions.map<DropdownMenuItem<String>>(
                          (Map<String, String> option) {
                        return DropdownMenuItem<String>(
                          value: option['value'],
                          child: Text(
                            option['label']!,
                            style: TextStyle(
                              fontFamily: option['fontFamily'],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 20),
                    Text('Font Size: ${_quranFontSize.toStringAsFixed(1)}'),
                    Slider(
                      value: _quranFontSize,
                      min: 16.0,
                      max: 40.0,
                      divisions: 12,
                      label: _quranFontSize.toStringAsFixed(1),
                      onChanged: (double value) {
                        setState(() {
                          _quranFontSize = value;
                        });
                      },
                    ),
                    SizedBox(height: 20),
                    Text('Reciter:'),
                    DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedReciter,
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedReciter = newValue;
                          });
                        }
                      },
                      items: _reciterOptions.map<DropdownMenuItem<String>>(
                          (Map<String, String> option) {
                        return DropdownMenuItem<String>(
                          value: option['value'],
                          child: Text(option['label']!),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: Text('Apply'),
                  onPressed: () {
                    // Update the main state and reload data if text file changed
                    this.setState(() {
                      _quranFontSize = _quranFontSize;
                      if (_selectedQuranText != this._selectedQuranText) {
                        this._selectedQuranText = _selectedQuranText;
                        _loadData(); // Reload data with new text file
                      }
                      this._selectedReciter = _selectedReciter;
                    });
                    _saveTextPreferences(); // Save preferences
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Add this helper method to get the current font family
  String _getCurrentFontFamily() {
    // Find the selected option in the list
    final selectedOption = _quranTextOptions.firstWhere(
      (option) => option['value'] == _selectedQuranText,
      orElse: () =>
          {'value': _selectedQuranText, 'fontFamily': '_Uthmanic_hafs'},
    );

    // Return the font family from the selected option
    return selectedOption['fontFamily'] ?? '_Uthmanic_hafs';
  }
}

bool isRTL(AppLanguage language) {
  return language == AppLanguage.arabic || language == AppLanguage.urdu;
}
