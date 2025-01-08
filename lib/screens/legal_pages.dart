import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class TermsOfServicePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Terms of Service'),
        backgroundColor: Color(0xFF417D7A),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Terms of Service',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              'Last updated: ${DateTime.now().toString().split(' ')[0]}',
              style: TextStyle(color: Colors.grey),
            ),
            SizedBox(height: 24),
            _buildSection(
              'Welcome to Qurany Flashcards Pro',
              'By accessing our app, you agree to these terms. Please read them carefully.',
            ),
            _buildSection(
              'Usage License',
              'We grant you a personal, non-exclusive, non-transferable license to use the app for Quran study purposes.',
            ),
            _buildSection(
              'User Conduct',
              'Users agree to:\n'
                  '• Use the app for its intended purpose\n'
                  '• Not misuse or abuse group features\n'
                  '• Respect other users\n'
                  '• Not use the app for unauthorized purposes',
            ),
            _buildSection(
              'Content',
              'Qurany Flashcards Pro is an open source project.',
            ),
            InkWell(
              onTap: () => launchUrl(
                Uri.parse('https://github.com/Yousif-GO/qurany-flashcards'),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Learn more on GitHub',
                  style: TextStyle(
                    color: Color(0xFF417D7A),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
            _buildSection(
              'Changes to Terms',
              'We reserve the right to modify these terms at any time. Continued use constitutes acceptance of changes.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(content),
          SizedBox(height: 16),
        ],
      ),
    );
  }
}

class PrivacyPolicyPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Privacy Policy'),
        backgroundColor: Color(0xFF417D7A),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Privacy Policy',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              'Last updated: ${DateTime.now().toString().split(' ')[0]}',
              style: TextStyle(color: Colors.grey),
            ),
            SizedBox(height: 24),
            _buildSection(
              'Information We Don\'t Collect',
              '• Personal identification information\n'
                  '• Email addresses\n'
                  '• Phone numbers\n'
                  '• Payment information',
            ),
            _buildSection(
              'Information We Do Collect',
              '• Group names (for Khatma features)\n'
                  '• Display names (chosen by users)\n'
                  '• Reading progress data\n'
                  '• App usage preferences',
            ),
            _buildSection(
              'How We Use Information',
              'We use the minimal information collected solely to:\n'
                  '• Enable group reading features\n'
                  '• Save your reading progress\n'
                  '• Improve app functionality',
            ),
            _buildSection(
              'Data Storage',
              'All data is stored using Firebase services. We do not share or sell any user data.',
            ),
            _buildSection(
              'Your Rights',
              'You can:\n'
                  '• Use the app without providing personal information\n'
                  '• Delete your reading progress\n'
                  '• Leave group readings at any time',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(content),
          SizedBox(height: 16),
        ],
      ),
    );
  }
}
