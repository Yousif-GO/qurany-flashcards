import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import '../services/firebase_service.dart';
import 'quran_room_view_screen.dart';
import '../main.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert' show utf8, base64Url;
import 'dart:math';

class QuranRoomScreen extends StatefulWidget {
  final AppLanguage selectedLanguage;
  final Map<String, String>? initialValues;
  final bool isGroupReading;
  final bool startInCreateMode;

  const QuranRoomScreen({
    Key? key,
    required this.selectedLanguage,
    this.initialValues,
    this.isGroupReading = false,
    this.startInCreateMode = false,
  }) : super(key: key);

  @override
  _QuranRoomScreenState createState() => _QuranRoomScreenState();
}

class _QuranRoomScreenState extends State<QuranRoomScreen> {
  final _firebaseService = FirebaseService();
  final _formKey = GlobalKey<FormState>();
  final _groupNameController = TextEditingController();
  final _khatmaNameController = TextEditingController();
  final _userNameController = TextEditingController();
  bool _isCreating = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadLastRoomDetails();

    if (kIsWeb) {
      // Automatically check URL when page loads
      _handlePastedUrl();
    }

    if (widget.initialValues != null) {
      _groupNameController.text = widget.initialValues!['group'] ?? '';
      _khatmaNameController.text = widget.initialValues!['khatma'] ?? '';
      _userNameController.text = widget.initialValues!['userName'] ?? '';
      _isCreating = true;
    } else {
      _isCreating = widget.startInCreateMode;
    }
  }

  Future<void> _loadLastRoomDetails() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _groupNameController.text = prefs.getString('lastGroupName') ?? '';
      _khatmaNameController.text = prefs.getString('lastKhatmaName') ?? '';
      _userNameController.text = prefs.getString('lastUserName') ?? '';
    });
  }

  Future<void> _saveRoomDetails() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastGroupName', _groupNameController.text);
    await prefs.setString('lastKhatmaName', _khatmaNameController.text);
    await prefs.setString('lastUserName', _userNameController.text);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Text(_isCreating ? 'Create Khatma' : 'Join Khatma'),
            centerTitle: true,
            actions: [
              TextButton.icon(
                icon: Icon(Icons.menu_book, color: Colors.white),
                label: Text('Read Solo', style: TextStyle(color: Colors.white)),
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => SimpleList(
                      selectedLanguage: widget.selectedLanguage,
                      isGroupReading: false,
                    ),
                  ),
                ),
              ),
              TextButton.icon(
                icon: Icon(Icons.paste, color: Colors.white),
                label:
                    Text('Fill Details', style: TextStyle(color: Colors.white)),
                onPressed: _handlePastedUrl,
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                _buildForm(),
                Divider(height: 32),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      Text(
                        "Don't see your group?",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () =>
                            setState(() => _isCreating = !_isCreating),
                        child: Text(
                            _isCreating ? 'Join Instead' : 'Create New Group'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: Size(double.infinity, 48),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_isLoading)
          Container(
            color: Colors.black54,
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isLoading = true);

    try {
      await _saveRoomDetails();
      if (_isCreating) {
        final exists = await _firebaseService.checkRoomExists(
            _groupNameController.text, _khatmaNameController.text);
        if (exists) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Room already exists')),
          );
          return;
        }

        await _firebaseService.createRoom(
          groupName: _groupNameController.text,
          khatmaName: _khatmaNameController.text,
          userName: _userNameController.text,
        );

        // Show share dialog immediately after creation
        _showShareDialog();
      } else {
        // Join existing room logic
        final exists = await _firebaseService.checkRoomExists(
            _groupNameController.text, _khatmaNameController.text);
        if (!exists) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Room does not exist')),
          );
          return;
        }

        await _firebaseService.joinRoom(
          groupName: _groupNameController.text,
          khatmaName: _khatmaNameController.text,
          userName: _userNameController.text,
          selectedPages: [],
        );

        _onRoomCreated();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onRoomCreated() {
    // After successfully creating/joining a room, navigate to SimpleList
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Qurany Cards Pro'),
            centerTitle: true,
          ),
          body: Center(
            child: SimpleList(
              selectedLanguage: widget.selectedLanguage,
              isGroupReading: true,
              groupName: _groupNameController.text,
              khatmaName: _khatmaNameController.text,
              userName: _userNameController.text,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleCreateRoom() async {
    // Function to check if text contains only Latin characters
    bool isLatinScript(String text) {
      return RegExp(r'^[a-zA-Z0-9\s]+$').hasMatch(text);
    }

    // Standardize by only trimming whitespace and replacing multiple spaces
    final standardizedGroup = _groupNameController.text.trim();
    final standardizedKhatma = _khatmaNameController.text.trim();

    // Replace multiple spaces with single space
    final finalGroup = standardizedGroup.replaceAll(RegExp(r'\s+'), ' ');
    final finalKhatma = standardizedKhatma.replaceAll(RegExp(r'\s+'), ' ');

    // Update controllers with standardized text
    _groupNameController.text = finalGroup;
    _khatmaNameController.text = finalKhatma;

    final exists =
        await _firebaseService.checkRoomExists(finalGroup, finalKhatma);
    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Room already exists')),
      );
      return;
    }

    await _firebaseService.createRoom(
      groupName: finalGroup,
      khatmaName: finalKhatma,
      userName: _userNameController.text.trim(),
    );

    _showShareDialog(); // Show dialog first
    // Remove _onRoomCreated() from here - it's now called from dialog
  }

  String _encodeToBase64(String text) {
    final bytes = utf8.encode(text);
    return base64Url.encode(bytes);
  }

  String _decodeFromBase64(String encoded) {
    final bytes = base64Url.decode(encoded);
    return utf8.decode(bytes);
  }

  void _showShareDialog() {
    // Encode both names into base64
    final encodedData = _encodeToBase64(
        '${_groupNameController.text}|${_khatmaNameController.text}');

    final roomInfo = '''🕌 Join our Quran Khatma!

Group: ${_groupNameController.text}
Khatma: ${_khatmaNameController.text}

Join directly:
https://qurany-flashcards.web.app/join?code=$encodedData

Or manually:
1. Open https://qurany-flashcards.web.app
2. Click the 📚 icon in the top right corner
3. Click "Read with Others"
4. Click "Join Instead"
5. Enter these details:
   - Group Name: ${_groupNameController.text}
   - Khatma Name: ${_khatmaNameController.text}

Let's complete this Khatma together! 🤲

📱 Using Qurany Cards Pro you can:
• Read Quran with word-by-word translation
• Listen to beautiful recitations
• Track your progress
• Read together with friends and family

Please join, it's totally free!
✓ No ads
✓ No subscription
✓ No payment
✓ No email required
Just read and make dua 🤲''';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Share Khatma'),
        content: Container(
          width: double.maxFinite,
          height: MediaQuery.of(context).size.height * 0.6, // Fixed height
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                // Use Expanded instead of Flexible
                child: SingleChildScrollView(
                  child: SelectableText(
                    roomInfo,
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
              Divider(height: 24),
              Wrap(
                // Use Wrap instead of Row
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton.icon(
                    icon: Icon(Icons.copy),
                    label: Text('Copy'),
                    onPressed: () => _copyToClipboard(roomInfo),
                  ),
                  if (!kIsWeb && Platform.isAndroid)
                    ElevatedButton.icon(
                      icon: Image.asset(
                        'assets/images/w.png',
                        height: 24,
                        width: 24,
                      ),
                      label: Text('WhatsApp'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF25D366),
                      ),
                      onPressed: () => _shareToWhatsApp(roomInfo),
                    ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _onRoomCreated();
            },
            child: Text('Start Reading'),
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied to clipboard!')),
    );
  }

  void _shareToWhatsApp(String text) {
    final whatsappUrl = 'https://wa.me/?text=${Uri.encodeComponent(text)}';
    launchUrl(Uri.parse(whatsappUrl));
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      validator: (value) {
        if (value?.isEmpty ?? true) {
          return 'Please enter $label';
        }
        return null;
      },
      onSaved: (value) {
        controller.text = value ?? '';
      },
    );
  }

  Widget _buildForm() {
    return Padding(
      padding: EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTextField(
              label: 'Group Name',
              controller: _groupNameController,
            ),
            SizedBox(height: 16),
            _buildTextField(
              label: 'Khatma Name',
              controller: _khatmaNameController,
            ),
            SizedBox(height: 16),
            _buildTextField(
              label: 'Your Name',
              controller: _userNameController,
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _handleSubmit,
              child: Text(_isCreating ? 'Create Room' : 'Join Room'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _khatmaNameController.dispose();
    _userNameController.dispose();
    super.dispose();
  }

  // Add this method to parse URLs
  void _handlePastedUrl() async {
    if (!kIsWeb) return;

    setState(() => _isLoading = true);

    try {
      await Future.delayed(Duration(milliseconds: 100));

      final uri = Uri.base;
      print('Current URL: ${uri.toString()}');

      if (uri.path == '/join') {
        final code = uri.queryParameters['code'];
        print('Received code: $code');

        if (code != null) {
          try {
            final decodedData = _decodeFromBase64(code);
            final parts = decodedData.split('|');

            if (parts.length == 2) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                setState(() {
                  _groupNameController.text = parts[0];
                  _khatmaNameController.text = parts[1];
                  _isCreating = false;
                  _isLoading = false;
                });
              });
            }
          } catch (e) {
            print('Error decoding data: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Invalid room code')),
            );
          }
        }
      }
    } catch (e) {
      print('Error parsing URL: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid room link: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _generateKhatmaStatus(Map<String, dynamic>? roomDetails) {
    if (roomDetails == null) return '';

    // Calculate completed pages
    int completedPages = 0;
    final pages = roomDetails['pages'] as Map<String, dynamic>;
    pages.forEach((key, value) {
      if (value['completed'] == true) completedPages++;
    });

    // Calculate remaining pages
    int remainingPages = 604 - completedPages;
    double completionPercentage = (completedPages / 604) * 100;

    // Get random motivational quote
    final quotes = [
      "Every page brings us closer to completion! 📖",
      "Together we can complete this blessed journey! 🤲",
      "Keep going, every word counts! ✨",
      "The best of deeds are the consistent ones! 🌟",
      "Let's make this Khatma a success story! 💫"
    ];
    final randomQuote = quotes[Random().nextInt(quotes.length)];

    return '''🕌 Khatma Progress Update

Group: ${roomDetails['groupName']}
Khatma: ${roomDetails['khatmaName']}

📊 Progress:
• Completed: $completedPages pages
• Remaining: $remainingPages pages
• Progress: ${completionPercentage.toStringAsFixed(1)}%

👥 Members:
${(roomDetails['members'] as List).map((member) => "• $member").join("\n")}

💭 $randomQuote

Join us in this blessed journey!
https://qurany-flashcards.web.app/join?group=${Uri.encodeComponent(roomDetails['groupName'])}&khatma=${Uri.encodeComponent(roomDetails['khatmaName'])}

✨ Using Qurany Cards Pro
• No ads
• No subscription
• No payment needed
• Just read and make dua 🤲''';
  }
}
