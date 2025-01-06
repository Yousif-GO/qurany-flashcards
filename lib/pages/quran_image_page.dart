import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../services/comments_service.dart';
import '../models/comment.dart';
import '../widgets/comments_dialog.dart';

class QuranImagePage extends StatefulWidget {
  final int pageNumber;

  final String? groupName;
  final String? khatmaName;
  final String? userName;
  final bool isGroupReading;
  const QuranImagePage({
    Key? key,
    required this.pageNumber,
    this.groupName,
    this.khatmaName,
    this.userName,
    required this.isGroupReading,
  }) : super(key: key);

  @override
  State<QuranImagePage> createState() => _QuranImagePageState();
}

class _QuranImagePageState extends State<QuranImagePage> {
  bool _isLoading = false;

  Future<void> _navigateToNextPage() async {
    int nextPage = widget.pageNumber == 604 ? 1 : widget.pageNumber + 1;

    if (widget.isGroupReading &&
        widget.groupName != null &&
        widget.khatmaName != null &&
        widget.userName != null) {
      setState(() => _isLoading = true);

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
        setState(() => _isLoading = false);
      }
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => QuranImagePage(
          pageNumber: nextPage,
          groupName: widget.groupName,
          khatmaName: widget.khatmaName,
          userName: widget.userName,
          isGroupReading: widget.isGroupReading,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formattedPage = widget.pageNumber.toString().padLeft(3, '0');
    final assetPath = 'assets/Quran_images/$formattedPage.jpg';

    return Scaffold(
      appBar: AppBar(
        title: Text('Page ${widget.pageNumber}'),
        actions: [
          if (widget.groupName != null)
            StreamBuilder<List<Comment>>(
              stream: CommentsService().getCommentsStream(
                pageNumber: widget.pageNumber,
                groupId: widget.groupName!,
              ),
              builder: (context, snapshot) {
                final commentCount = snapshot.data?.length ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: TextButton.icon(
                    icon: Icon(
                      Icons.comment_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                    label: Text(
                      'Thoughts : تدبر ($commentCount)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.white, width: 1),
                      ),
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => CommentsDialog(
                          pageNumber: widget.pageNumber,
                          groupId: widget.groupName!,
                          userName: widget.userName ?? 'Anonymous',
                        ),
                      );
                    },
                  ),
                );
              },
            ),
        ],
      ),
      body: GestureDetector(
        onTap: _navigateToNextPage,
        child: Center(
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Image.asset(
              assetPath,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                print('Error loading image: $error');
                print('Asset path attempted: $assetPath');
                return Text('Failed to load page ${widget.pageNumber}');
              },
            ),
          ),
        ),
      ),
    );
  }
}
