import 'package:flutter/material.dart';
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
                          child: ListTile(
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
                                          ? () => _commentsService.toggleUpvote(
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
                                    onPressed: () => _deleteComment(comment.id),
                                  )
                                : null,
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
                  child: Row(
                    children: [
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute}';
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;

    await _commentsService.addComment(
      text: _commentController.text.trim(),
      userName: widget.userName,
      pageNumber: widget.pageNumber,
      groupId: widget.groupId,
    );

    _commentController.clear();
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
    super.dispose();
  }
}
