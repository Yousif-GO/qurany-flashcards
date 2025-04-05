import 'dart:math';
import '../services/encoding_service.dart';

class KhatmaUtils {
  static String generateKhatmaStatus(Map<String, dynamic>? roomDetails) {
    if (roomDetails == null) return '';

    // Calculate member statistics
    final pages = roomDetails['pages'] as Map<String, dynamic>;
    Map<String, int> memberPages = {};

    pages.forEach((pageNum, pageData) {
      if (pageData['completed'] == true) {
        final member = pageData['completedBy'] as String;
        memberPages[member] = (memberPages[member] ?? 0) + 1;
      }
    });

    // Sort members by pages completed
    var sortedMembers = memberPages.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Calculate total stats
    int completedPages =
        sortedMembers.fold(0, (sum, member) => sum + member.value);
    int remainingPages = 604 - completedPages;
    double completionPercentage = (completedPages / 604) * 100;

    // Generate member rankings
    final memberRankings = sortedMembers.asMap().entries.map((entry) {
      int rank = entry.key + 1;
      String medal = rank == 1
          ? '•'
          : rank == 2
              ? '•'
              : rank == 3
                  ? '•'
                  : '•';
      return '$medal ${entry.value.key}: ${entry.value.value} pages';
    }).join('\n');

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

📊 Overall Progress:
• Completed: $completedPages pages
• Remaining: $remainingPages pages
• Progress: ${completionPercentage.toStringAsFixed(1)}%

👥 Member Contributions(JazakAllah Khair):
$memberRankings


Join us in this blessed journey!
https://quranycards.com/join?code=${Uri.encodeComponent(EncodingService.encodeToBase64('${roomDetails['groupName']}|${roomDetails['khatmaName']}'))}

✨ Using Qurany Cards Pro
• No ads
• No subscription
• No payment needed
• Just read and make dua 🤲''';
  }
}
