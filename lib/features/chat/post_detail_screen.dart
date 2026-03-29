import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../config/config_url.dart';
import '../auth/auth_provider.dart';
import 'chat_models.dart';
import 'chat_service.dart';
import 'create_post_screen.dart';

class PostDetailScreen extends StatefulWidget {
  final CommunityPost post;

  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final _postService = CommunityPostService();
  final _commentController = TextEditingController();
  final _scrollController = ScrollController();

  CommunityPost? _post;
  List<PostComment> _comments = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _sendingComment = false;
  int _currentPage = 1;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _loadPostDetail();
    _loadComments();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.8 &&
        !_loadingMore &&
        _hasMore) {
      _loadMoreComments();
    }
  }

  Future<void> _loadPostDetail() async {
    try {
      final post = await _postService.getPost(_post!.id);
      if (mounted) {
        setState(() => _post = post);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải bài đăng: $e')),
        );
      }
    }
  }

  Future<void> _loadComments() async {
    if (_loading) setState(() => _loading = true);
    try {
      final comments = await _postService.fetchComments(
        postId: _post!.id,
        page: 1,
      );
      if (mounted) {
        setState(() {
          _comments = comments;
          _currentPage = 1;
          _hasMore = comments.length >= 50;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải bình luận: $e')),
        );
      }
    }
  }

  Future<void> _loadMoreComments() async {
    if (!_hasMore || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final comments = await _postService.fetchComments(
        postId: _post!.id,
        page: _currentPage + 1,
      );
      if (mounted) {
        setState(() {
          _comments.addAll(comments);
          _currentPage++;
          _hasMore = comments.length >= 50;
          _loadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingMore = false);
      }
    }
  }

  Future<void> _sendComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    setState(() => _sendingComment = true);
    _commentController.clear();
    try {
      final comment = await _postService.createComment(
        postId: _post!.id,
        content: content,
      );
      if (mounted) {
        setState(() {
          _comments.insert(0, comment);
          _post = _post?.copyWith(commentCount: (_post?.commentCount ?? 0) + 1);
        });
      }
    } catch (e) {
      if (mounted) {
        _commentController.text = content;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi gửi bình luận: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingComment = false);
    }
  }

  Future<void> _toggleLike() async {
    if (_post == null) return;
    final wasLiked = _post!.isLiked;
    setState(() {
      _post = _post!.copyWith(
        isLiked: !wasLiked,
        likeCount: wasLiked ? _post!.likeCount - 1 : _post!.likeCount + 1,
      );
    });
    try {
      final updated = await _postService.toggleLike(_post!.id);
      if (mounted) {
        setState(() => _post = updated);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _post = _post!.copyWith(
            isLiked: wasLiked,
            likeCount: wasLiked ? _post!.likeCount + 1 : _post!.likeCount - 1,
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_post == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final auth = context.watch<AuthState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết bài đăng'),
        actions: [
          if (_post!.canEdit || _post!.canDelete)
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'edit') {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreatePostScreen(
                        type: _post!.type,
                        post: _post,
                      ),
                    ),
                  );
                  if (result == true) {
                    _loadPostDetail();
                  }
                } else if (value == 'delete') {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Xác nhận'),
                      content: const Text('Bạn có chắc muốn xóa bài đăng này?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('Hủy'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          child: const Text('Xóa', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    try {
                      await _postService.deletePost(_post!.id);
                      if (mounted) {
                        Navigator.pop(context, true);
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Lỗi xóa bài: $e')),
                        );
                      }
                    }
                  }
                }
              },
              itemBuilder: (_) => [
                if (_post!.canEdit)
                  const PopupMenuItem(value: 'edit', child: Text('Sửa')),
                if (_post!.canDelete)
                  const PopupMenuItem(value: 'delete', child: Text('Xóa')),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                // Post content
                _PostCard(
                  post: _post!,
                  onLike: _toggleLike,
                  showFullContent: true,
                  onTap: null,
                ),
                const Divider(height: 32),
                // Comments section
                Text(
                  'Bình luận (${_post!.commentCount})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                if (_loading && _comments.isEmpty)
                  const Center(child: CircularProgressIndicator())
                else if (_comments.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(Icons.comment_outlined,
                              size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'Chưa có bình luận nào',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ..._comments.map((comment) => _CommentCard(
                        comment: comment,
                        currentUserId: auth.userId,
                        onDelete: () async {
                          try {
                            await _postService.deleteComment(
                              postId: _post!.id,
                              commentId: comment.id,
                            );
                            if (mounted) {
                              setState(() {
                                _comments.removeWhere((c) => c.id == comment.id);
                                _post = _post!.copyWith(
                                    commentCount: _post!.commentCount - 1);
                              });
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Lỗi xóa bình luận: $e')),
                              );
                            }
                          }
                        },
                      )),
                if (_loadingMore)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
          // Comment input
          SafeArea(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: InputDecoration(
                        hintText: 'Viết bình luận...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendComment(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _sendingComment ? null : _sendComment,
                    icon: _sendingComment
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Extension để copyWith cho CommunityPost
extension CommunityPostExtension on CommunityPost {
  CommunityPost copyWith({
    String? id,
    PostType? type,
    String? title,
    String? content,
    String? createdById,
    String? createdByName,
    String? createdByAvatarUrl,
    String? apartmentCode,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? imageUrls,
    int? likeCount,
    int? commentCount,
    bool? isLiked,
    SuggestionStatus? suggestionStatus,
    bool? canEdit,
    bool? canDelete,
  }) {
    return CommunityPost(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      content: content ?? this.content,
      createdById: createdById ?? this.createdById,
      createdByName: createdByName ?? this.createdByName,
      createdByAvatarUrl: createdByAvatarUrl ?? this.createdByAvatarUrl,
      apartmentCode: apartmentCode ?? this.apartmentCode,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      imageUrls: imageUrls ?? this.imageUrls,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      isLiked: isLiked ?? this.isLiked,
      suggestionStatus: suggestionStatus ?? this.suggestionStatus,
      canEdit: canEdit ?? this.canEdit,
      canDelete: canDelete ?? this.canDelete,
    );
  }
}

class _PostCard extends StatelessWidget {
  final CommunityPost post;
  final VoidCallback? onLike;
  final bool showFullContent;
  final VoidCallback? onTap;

  const _PostCard({
    required this.post,
    this.onLike,
    this.showFullContent = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeAgo = _getTimeAgo(post.createdAt);

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Avatar + Name + Time
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: post.createdByAvatarUrl != null
                        ? NetworkImage(AppConfig.resolve(post.createdByAvatarUrl!))
                        : null,
                    child: post.createdByAvatarUrl == null
                        ? Text(post.createdByName[0].toUpperCase())
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.createdByName,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (post.apartmentCode != null)
                          Text(
                            post.apartmentCode!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    timeAgo,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Title
              Text(
                post.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              // Content
              Text(
                post.content,
                style: theme.textTheme.bodyMedium,
                maxLines: showFullContent ? null : 3,
                overflow: showFullContent ? null : TextOverflow.ellipsis,
              ),
              // Images
              if (post.imageUrls.isNotEmpty) ...[
                const SizedBox(height: 12),
                _ImageGrid(images: post.imageUrls),
              ],
              // Suggestion status badge
              if (post.type == PostType.suggestion &&
                  post.suggestionStatus != null) ...[
                const SizedBox(height: 12),
                Chip(
                  label: Text(
                    suggestionStatusToDisplay(post.suggestionStatus!),
                  ),
                  backgroundColor: _getStatusColor(post.suggestionStatus!)
                      .withOpacity(0.1),
                  labelStyle: TextStyle(
                    color: _getStatusColor(post.suggestionStatus!),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              // Actions: Like + Comment
              Row(
                children: [
                  TextButton.icon(
                    onPressed: onLike,
                    icon: Icon(
                      post.isLiked ? Icons.favorite : Icons.favorite_border,
                      color: post.isLiked ? Colors.red : null,
                    ),
                    label: Text('${post.likeCount}'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.comment_outlined),
                    label: Text('${post.commentCount}'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inDays > 7) {
      return DateFormat('dd/MM/yyyy').format(dateTime);
    } else if (diff.inDays > 0) {
      return '${diff.inDays} ngày trước';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} giờ trước';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes} phút trước';
    } else {
      return 'Vừa xong';
    }
  }

  Color _getStatusColor(SuggestionStatus status) {
    switch (status) {
      case SuggestionStatus.newSuggestion:
        return Colors.blue;
      case SuggestionStatus.inProgress:
        return Colors.orange;
      case SuggestionStatus.completed:
        return Colors.green;
      case SuggestionStatus.rejected:
        return Colors.red;
    }
  }
}

class _ImageGrid extends StatelessWidget {
  final List<String> images;

  const _ImageGrid({required this.images});

  @override
  Widget build(BuildContext context) {
    if (images.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          AppConfig.resolve(images[0]),
          width: double.infinity,
          height: 200,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            height: 200,
            color: Colors.grey[300],
            child: const Icon(Icons.broken_image),
          ),
        ),
      );
    } else if (images.length == 2) {
      return Row(
        children: images.map((url) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  AppConfig.resolve(url),
                  height: 150,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 150,
                    color: Colors.grey[300],
                    child: const Icon(Icons.broken_image),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      );
    } else {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
        ),
        itemCount: images.length > 9 ? 9 : images.length,
        itemBuilder: (context, index) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              AppConfig.resolve(images[index]),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.grey[300],
                child: const Icon(Icons.broken_image),
              ),
            ),
          );
        },
      );
    }
  }
}

class _CommentCard extends StatelessWidget {
  final PostComment comment;
  final String? currentUserId;
  final VoidCallback onDelete;

  const _CommentCard({
    required this.comment,
    this.currentUserId,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeAgo = _getTimeAgo(comment.createdAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundImage: comment.createdByAvatarUrl != null
                ? NetworkImage(AppConfig.resolve(comment.createdByAvatarUrl!))
                : null,
            child: comment.createdByAvatarUrl == null
                ? Text(comment.createdByName[0].toUpperCase())
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        comment.createdByName,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        comment.content,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      timeAgo,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    if (comment.canDelete) ...[
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title: const Text('Xác nhận'),
                              content: const Text('Xóa bình luận này?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogContext, false),
                                  child: const Text('Hủy'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogContext, true),
                                  child: const Text('Xóa',
                                      style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) onDelete();
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Xóa',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inDays > 7) {
      return DateFormat('dd/MM/yyyy').format(dateTime);
    } else if (diff.inDays > 0) {
      return '${diff.inDays} ngày trước';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} giờ trước';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes} phút trước';
    } else {
      return 'Vừa xong';
    }
  }
}

