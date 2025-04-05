import 'package:flutter/material.dart';
import 'dart:io';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../models/comment.dart';
import '../services/comments_service.dart';

class CommentsDialog extends StatefulWidget {
  final int pageNumber;
  final String groupId;
  final String userName;

  const CommentsDialog({
    Key? key,
    required this.pageNumber,
    required this.groupId,
    required this.userName,
  }) : super(key: key);

  @override
  State<CommentsDialog> createState() => _CommentsDialogState();
}

class _CommentsDialogState extends State<CommentsDialog> {
  final _commentController = TextEditingController();
  final _commentsService = CommentsService();

  // Audio recording related variables
  final _audioRecorder = Record();
  final _audioPlayer = AudioPlayer();
  bool _isRecording = false;
  bool _hasRecording = false;
  String? _recordingPath;
  Comment? _playingComment;

  @override
  void initState() {
    super.initState();
    _initializeRecorder();
  }

  Future<void> _initializeRecorder() async {
    final status = await _audioRecorder.hasPermission();
    if (!status) {
      // Handle permission denied
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Microphone permission is required to record audio')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text('Comments for Page ${widget.pageNumber}'),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: StreamBuilder<List<Comment>>(
                  stream: _commentsService.getCommentsStream(
                    pageNumber: widget.pageNumber,
                    groupId: widget.groupId,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text('Error: ${snapshot.error}'),
                      );
                    }

                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    final comments = snapshot.data!;

                    if (comments.isEmpty) {
                      return const Center(
                        child: Text('No comments yet'),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        final comment = comments[index];
                        return Card(
                          margin: EdgeInsets.only(bottom: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ListTile(
                                title: Text(
                                  comment.text,
                                  textDirection: isArabic(comment.text)
                                      ? TextDirection.rtl
                                      : TextDirection.ltr,
                                  textAlign: isArabic(comment.text)
                                      ? TextAlign.right
                                      : TextAlign.left,
                                ),
                                subtitle: Text(
                                  '${comment.userName} - ${_formatDate(comment.timestamp)}',
                                  style: TextStyle(fontSize: 12),
                                ),
                                leading: SizedBox(
                                  width: 40,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        height: 24,
                                        child: IconButton(
                                          icon: Icon(
                                            Icons.arrow_upward,
                                            color: comment.upvotedBy
                                                    .contains(widget.userName)
                                                ? Theme.of(context).primaryColor
                                                : Colors.grey,
                                            size: 16,
                                          ),
                                          constraints: BoxConstraints(
                                            minWidth: 20,
                                            minHeight: 20,
                                          ),
                                          padding: EdgeInsets.zero,
                                          onPressed: comment.userName !=
                                                  widget.userName
                                              ? () =>
                                                  _commentsService.toggleUpvote(
                                                      widget.groupId,
                                                      comment.id,
                                                      widget.userName)
                                              : null,
                                        ),
                                      ),
                                      SizedBox(
                                        height: 16,
                                        child: Text(
                                          '${comment.upvotes}',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                trailing: comment.userName == widget.userName
                                    ? IconButton(
                                        icon: Icon(Icons.delete, size: 16),
                                        constraints: BoxConstraints(
                                          minWidth: 20,
                                          minHeight: 20,
                                        ),
                                        padding: EdgeInsets.zero,
                                        onPressed: () =>
                                            _deleteComment(comment.id),
                                      )
                                    : null,
                              ),

                              // Audio player if comment has audio
                              if (comment.audioUrl != null)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16.0, vertical: 8.0),
                                  child: Row(
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          _playingComment?.id == comment.id
                                              ? Icons.stop
                                              : Icons.play_arrow,
                                          size: 24,
                                        ),
                                        onPressed: () {
                                          if (_playingComment?.id ==
                                              comment.id) {
                                            _stopPlayback();
                                          } else {
                                            _playAudio(comment);
                                          }
                                        },
                                      ),
                                      Expanded(
                                        child: Text(
                                          'Audio comment',
                                          style: TextStyle(
                                            fontStyle: FontStyle.italic,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              Container(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      // Recording status indicator
                      if (_isRecording || _hasRecording)
                        Container(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          width: double.infinity,
                          child: Row(
                            children: [
                              Icon(
                                _isRecording ? Icons.mic : Icons.mic_none,
                                color: _isRecording ? Colors.red : Colors.grey,
                              ),
                              SizedBox(width: 8),
                              Text(
                                _isRecording
                                    ? 'Recording audio...'
                                    : 'Audio recorded',
                                style: TextStyle(
                                  color: _isRecording
                                      ? Colors.red
                                      : Colors.grey.shade700,
                                ),
                              ),
                              Spacer(),
                              if (_hasRecording && !_isRecording)
                                IconButton(
                                  icon: Icon(Icons.delete, color: Colors.red),
                                  onPressed: _discardRecording,
                                ),
                            ],
                          ),
                        ),
                      Row(
                        children: [
                          // Audio recording button
                          IconButton(
                            icon: Icon(
                              _isRecording ? Icons.stop : Icons.mic,
                              color: _isRecording ? Colors.red : null,
                            ),
                            onPressed:
                                _isRecording ? _stopRecording : _startRecording,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _commentController,
                              decoration: InputDecoration(
                                hintText: 'Add a comment...',
                                border: OutlineInputBorder(),
                                filled: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                              ),
                              maxLines: null,
                              textInputAction: TextInputAction.newline,
                            ),
                          ),
                          SizedBox(width: 8),
                          IconButton(
                            icon: Icon(Icons.send),
                            onPressed: _addComment,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        // Create a temporary file for recording
        final directory = await getTemporaryDirectory();
        _recordingPath =
            '${directory.path}/comment_recording_${DateTime.now().millisecondsSinceEpoch}.m4a';

        // Configure recorder
        await _audioRecorder.start(
          path: _recordingPath!,
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          samplingRate: 44100,
        );

        setState(() {
          _isRecording = true;
          _hasRecording = false;
        });
      }
    } catch (e) {
      print('Error starting recording: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start recording')),
      );
    }
  }

  Future<void> _stopRecording() async {
    try {
      await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _hasRecording = true;
      });
    } catch (e) {
      print('Error stopping recording: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to stop recording')),
      );
    }
  }

  void _discardRecording() {
    setState(() {
      _hasRecording = false;
      _recordingPath = null;
    });
  }

  Future<void> _playAudio(Comment comment) async {
    if (_playingComment != null) {
      await _stopPlayback();
    }

    try {
      await _audioPlayer.play(UrlSource(comment.audioUrl!));
      setState(() {
        _playingComment = comment;
      });

      // Listen for completion to update UI
      _audioPlayer.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() {
            _playingComment = null;
          });
        }
      });
    } catch (e) {
      print('Error playing audio: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to play audio')),
      );
    }
  }

  Future<void> _stopPlayback() async {
    await _audioPlayer.stop();
    setState(() {
      _playingComment = null;
    });
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute}';
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty && !_hasRecording) return;

    try {
      File? audioFile;
      if (_hasRecording && _recordingPath != null) {
        audioFile = File(_recordingPath!);
      }

      await _commentsService.addComment(
        text: _commentController.text.trim().isEmpty
            ? "Audio comment"
            : _commentController.text.trim(),
        userName: widget.userName,
        pageNumber: widget.pageNumber,
        groupId: widget.groupId,
        audioFile: audioFile,
      );

      _commentController.clear();
      setState(() {
        _hasRecording = false;
        _recordingPath = null;
      });
    } catch (e) {
      print('Error adding comment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add comment')),
      );
    }
  }

  Future<void> _deleteComment(String commentId) async {
    await _commentsService.deleteComment(widget.groupId, commentId);
  }

  bool isArabic(String text) {
    return RegExp(r'[\u0600-\u06FF]').hasMatch(text);
  }

  @override
  void dispose() {
    _commentController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }
}
