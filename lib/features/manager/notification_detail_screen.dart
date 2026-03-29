import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/config_url.dart';
import '../notifications/notifications_service.dart';
import '../notifications/notification_model.dart';
import '../chat/post_detail_screen.dart';
import '../chat/chat_service.dart';
import '../chat/chat_models.dart';

// Màn hình chi tiết thông báo cho admin
class NotificationDetailScreen extends StatefulWidget {
  final NotificationModel notification;

  const NotificationDetailScreen({super.key, required this.notification});

  @override
  State<NotificationDetailScreen> createState() => _NotificationDetailScreenState();
}

class _NotificationDetailScreenState extends State<NotificationDetailScreen> {
  final _notificationService = NotificationsService();
  final _postService = CommunityPostService();
  NotificationModel? _notification;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _notification = widget.notification;
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() => _loading = true);
    try {
      final detail = await _notificationService.getById(_notification!.id);
      if (mounted) {
        setState(() {
          _notification = detail;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải chi tiết: $e')),
        );
      }
    }
  }

  Future<void> _openPostDetail() async {
    if (_notification?.postId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không tìm thấy bài đăng liên quan')),
      );
      return;
    }

    try {
      final post = await _postService.getPost(_notification!.postId!);
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PostDetailScreen(post: post),
          ),
        );
        // Reload để cập nhật số lượng like/comment
        _loadDetail();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi mở bài đăng: $e')),
        );
      }
    }
  }

  // Hiển thị bottom sheet danh sách người like
  Future<void> _showLikesBottomSheet(BuildContext context, String postId) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => _LikesBottomSheet(
          postId: postId,
          scrollController: scrollController,
        ),
      ),
    );
  }

  // Hiển thị bottom sheet danh sách bình luận
  Future<void> _showCommentsBottomSheet(BuildContext context, String postId) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => _CommentsBottomSheet(
          postId: postId,
          scrollController: scrollController,
          onCommentDeleted: () {
            // Reload để cập nhật số lượng
            _loadDetail();
          },
          onCommentAdded: () {
            // Reload để cập nhật số lượng khi thêm comment/reply
            _loadDetail();
          },
        ),
      ),
    );
    // Reload sau khi đóng bottom sheet
    _loadDetail();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _notification == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết thông báo')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final theme = Theme.of(context);
    final notification = _notification!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết thông báo'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header với icon
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.campaign,
                    size: 32,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatType(notification.type),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Nội dung
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nội dung',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      notification.content,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Thống kê tương tác
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Thống kê tương tác',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            icon: Icons.favorite,
                            label: 'Lượt thích',
                            value: notification.likeCount.toString(),
                            color: Colors.red,
                            onTap: notification.postId != null && notification.likeCount > 0
                                ? () => _showLikesBottomSheet(context, notification.postId!)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.comment,
                            label: 'Bình luận',
                            value: notification.commentCount.toString(),
                            color: Colors.blue,
                            onTap: notification.postId != null && notification.commentCount > 0
                                ? () => _showCommentsBottomSheet(context, notification.postId!)
                                : null,
                          ),
                        ),
                      ],
                    ),
                    if (notification.postId != null) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _openPostDetail,
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('Xem bài đăng liên quan'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Thông tin thời gian
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Thông tin thời gian',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _InfoRow(
                      label: 'Ngày tạo',
                      value: DateFormat('dd/MM/yyyy HH:mm').format(notification.createdAt),
                    ),
                    if (notification.effectiveFrom != null)
                      _InfoRow(
                        label: 'Hiệu lực từ',
                        value: DateFormat('dd/MM/yyyy HH:mm').format(notification.effectiveFrom!),
                      ),
                    if (notification.effectiveTo != null)
                      _InfoRow(
                        label: 'Đến',
                        value: DateFormat('dd/MM/yyyy HH:mm').format(notification.effectiveTo!),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatType(String type) {
    switch (type.toLowerCase()) {
      case 'powercut':
        return 'Cúp điện';
      case 'watercut':
        return 'Cúp nước';
      case 'liftmaintenance':
        return 'Bảo trì thang máy';
      case 'event':
        return 'Sự kiện';
      default:
        return 'Thông báo chung';
    }
  }
}

// Widget hiển thị thống kê
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: content,
      );
    }

    return content;
  }
}

// Widget hiển thị thông tin dòng
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// Bottom sheet hiển thị danh sách người đã like
class _LikesBottomSheet extends StatefulWidget {
  final String postId;
  final ScrollController scrollController;

  const _LikesBottomSheet({
    required this.postId,
    required this.scrollController,
  });

  @override
  State<_LikesBottomSheet> createState() => _LikesBottomSheetState();
}

class _LikesBottomSheetState extends State<_LikesBottomSheet> {
  final _postService = CommunityPostService();
  List<PostLikeUser> _likes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLikes();
  }

  Future<void> _loadLikes() async {
    setState(() => _loading = true);
    try {
      final likes = await _postService.getLikes(postId: widget.postId);
      if (mounted) {
        setState(() {
          _likes = likes;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải danh sách: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.favorite, color: Colors.red),
                const SizedBox(width: 8),
                Text(
                  'Người đã thích (${_likes.length})',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Content
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _likes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.favorite_border,
                                size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'Chưa có ai thích',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: widget.scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _likes.length,
                        itemBuilder: (context, index) {
                          final user = _likes[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: user.avatarUrl != null
                                  ? NetworkImage(AppConfig.resolve(user.avatarUrl!))
                                  : null,
                              child: user.avatarUrl == null
                                  ? Text(user.fullName[0].toUpperCase())
                                  : null,
                            ),
                            title: Text(
                              user.fullName,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            subtitle: Text(user.userName),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// Bottom sheet hiển thị danh sách bình luận
class _CommentsBottomSheet extends StatefulWidget {
  final String postId;
  final ScrollController scrollController;
  final VoidCallback onCommentDeleted;
  final VoidCallback onCommentAdded;

  const _CommentsBottomSheet({
    required this.postId,
    required this.scrollController,
    required this.onCommentDeleted,
    required this.onCommentAdded,
  });

  @override
  State<_CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<_CommentsBottomSheet> {
  final _postService = CommunityPostService();
  final _replyController = TextEditingController();
  List<PostComment> _comments = [];
  Map<String, List<PostComment>> _replies = {}; // Map commentId -> replies
  Map<String, bool> _showReplies = {}; // Map commentId -> show/hide replies
  String? _replyingToCommentId;
  bool _loading = true;
  bool _sendingReply = false;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _loading = true);
    try {
      final comments = await _postService.fetchComments(
        postId: widget.postId,
        page: 1,
      );
      if (mounted) {
        setState(() {
          _comments = comments;
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

  Future<void> _deleteComment(PostComment comment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xác nhận'),
        content: const Text('Bạn có chắc muốn xóa bình luận này?'),
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
        await _postService.deleteComment(
          postId: widget.postId,
          commentId: comment.id,
        );
        if (mounted) {
          setState(() {
            _comments.removeWhere((c) => c.id == comment.id);
          });
          widget.onCommentDeleted();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã xóa bình luận')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi xóa bình luận: $e')),
          );
        }
      }
    }
  }

  Future<void> _toggleLike(PostComment comment, int index) async {
    try {
      final result = await _postService.toggleCommentLike(
        postId: widget.postId,
        commentId: comment.id,
      );
      if (mounted) {
        setState(() {
          _comments[index] = PostComment(
            id: comment.id,
            postId: comment.postId,
            parentCommentId: comment.parentCommentId,
            content: comment.content,
            createdById: comment.createdById,
            createdByName: comment.createdByName,
            createdByAvatarUrl: comment.createdByAvatarUrl,
            createdAt: comment.createdAt,
            updatedAt: comment.updatedAt,
            isHidden: comment.isHidden,
            likeCount: result['likeCount'] as int,
            replyCount: comment.replyCount,
            isLiked: result['isLiked'] as bool,
            canEdit: comment.canEdit,
            canDelete: comment.canDelete,
          );
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi like bình luận: $e')),
        );
      }
    }
  }

  Future<void> _hideComment(PostComment comment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xác nhận'),
        content: const Text('Bạn có chắc muốn ẩn bình luận này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Ẩn', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _postService.hideComment(
          postId: widget.postId,
          commentId: comment.id,
        );
        if (mounted) {
          setState(() {
            _comments.removeWhere((c) => c.id == comment.id);
          });
          widget.onCommentDeleted();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã ẩn bình luận')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi ẩn bình luận: $e')),
          );
        }
      }
    }
  }

  Future<void> _loadReplies(String commentId) async {
    if (_replies.containsKey(commentId)) return; // Đã load rồi

    try {
      final replies = await _postService.getReplies(
        postId: widget.postId,
        commentId: commentId,
      );
      if (mounted) {
        setState(() {
          _replies[commentId] = replies;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải reply: $e')),
        );
      }
    }
  }

  Future<void> _sendReply(String commentId) async {
    final content = _replyController.text.trim();
    if (content.isEmpty) return;

    setState(() => _sendingReply = true);
    try {
      await _postService.createComment(
        postId: widget.postId,
        content: content,
        parentCommentId: commentId,
      );
      _replyController.clear();
      setState(() {
        _replyingToCommentId = null;
        // Reload replies
        _replies.remove(commentId);
        _loadReplies(commentId);
        // Reload comments để cập nhật replyCount
        _loadComments();
      });
      // Thông báo đã thêm comment để cập nhật số lượng
      widget.onCommentAdded();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi gửi reply: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingReply = false);
    }
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.comment, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Bình luận (${_comments.length})',
                  style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Content
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _comments.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
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
                      )
                    : ListView.builder(
                        controller: widget.scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          final comment = _comments[index];
                          final showReplies = _showReplies[comment.id] ?? false;
                          final replies = _replies[comment.id] ?? [];

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header: Avatar + Name + Time
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundImage:
                                            comment.createdByAvatarUrl != null
                                                ? NetworkImage(AppConfig.resolve(
                                                    comment.createdByAvatarUrl!))
                                                : null,
                                        child: comment.createdByAvatarUrl == null
                                            ? Text(comment.createdByName[0]
                                                .toUpperCase())
                                            : null,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              comment.createdByName,
                                              style: theme.textTheme.labelMedium
                                                  ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              _getTimeAgo(comment.createdAt),
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Admin actions menu
                                      PopupMenuButton<String>(
                                        onSelected: (value) {
                                          if (value == 'delete') {
                                            _deleteComment(comment);
                                          } else if (value == 'hide') {
                                            _hideComment(comment);
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          if (comment.canDelete)
                                            const PopupMenuItem(
                                              value: 'delete',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.delete,
                                                      size: 20,
                                                      color: Colors.red),
                                                  SizedBox(width: 8),
                                                  Text('Xóa',
                                                      style: TextStyle(
                                                          color: Colors.red)),
                                                ],
                                              ),
                                            ),
                                          const PopupMenuItem(
                                            value: 'hide',
                                            child: Row(
                                              children: [
                                                Icon(Icons.visibility_off,
                                                    size: 20,
                                                    color: Colors.orange),
                                                SizedBox(width: 8),
                                                Text('Ẩn',
                                                    style: TextStyle(
                                                        color: Colors.orange)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  // Content
                                  Text(
                                    comment.content,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                  const SizedBox(height: 12),
                                  // Actions: Like, Reply, View Replies
                                  Row(
                                    children: [
                                      // Like button
                                      InkWell(
                                        onTap: () => _toggleLike(comment, index),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              comment.isLiked
                                                  ? Icons.favorite
                                                  : Icons.favorite_border,
                                              size: 18,
                                              color: comment.isLiked
                                                  ? Colors.red
                                                  : Colors.grey[600],
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${comment.likeCount}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Reply button
                                      InkWell(
                                        onTap: () {
                                          setState(() {
                                            _replyingToCommentId = comment.id;
                                          });
                                        },
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.reply,
                                              size: 18,
                                              color: Colors.blue,
                                            ),
                                            const SizedBox(width: 4),
                                            const Text(
                                              'Trả lời',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.blue,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Spacer(),
                                      // View replies button
                                      if (comment.replyCount > 0)
                                        InkWell(
                                          onTap: () {
                                            setState(() {
                                              _showReplies[comment.id] =
                                                  !showReplies;
                                            });
                                            if (!showReplies) {
                                              _loadReplies(comment.id);
                                            }
                                          },
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                showReplies
                                                    ? Icons.expand_less
                                                    : Icons.expand_more,
                                                size: 18,
                                                color: Colors.grey[600],
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${comment.replyCount} phản hồi',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  // Reply input (hiển thị khi đang reply comment này)
                                  if (_replyingToCommentId == comment.id) ...[
                                    const SizedBox(height: 12),
                                    const Divider(),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.reply, size: 16, color: Colors.blue),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: TextField(
                                            controller: _replyController,
                                            decoration: InputDecoration(
                                              hintText: 'Viết phản hồi...',
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              contentPadding: const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 8,
                                              ),
                                            ),
                                            maxLines: 2,
                                            textInputAction: TextInputAction.send,
                                            onSubmitted: (_) => _sendReply(comment.id),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: _sendingReply
                                              ? const SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child: CircularProgressIndicator(strokeWidth: 2),
                                                )
                                              : const Icon(Icons.send, color: Colors.blue),
                                          onPressed: _sendingReply
                                              ? null
                                              : () => _sendReply(comment.id),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.close, size: 20),
                                          onPressed: () {
                                            setState(() {
                                              _replyingToCommentId = null;
                                              _replyController.clear();
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                  // Replies section
                                  if (showReplies && replies.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    const Divider(),
                                    const SizedBox(height: 8),
                                    ...replies.map((reply) => Padding(
                                          padding: const EdgeInsets.only(
                                              left: 16, bottom: 8),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              CircleAvatar(
                                                radius: 12,
                                                backgroundImage: reply
                                                            .createdByAvatarUrl !=
                                                        null
                                                    ? NetworkImage(AppConfig
                                                        .resolve(reply
                                                            .createdByAvatarUrl!))
                                                    : null,
                                                child: reply.createdByAvatarUrl ==
                                                        null
                                                    ? Text(reply.createdByName[0]
                                                        .toUpperCase(),
                                                        style: const TextStyle(
                                                            fontSize: 10))
                                                    : null,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      reply.createdByName,
                                                      style: theme.textTheme
                                                          .labelSmall
                                                          ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    Text(
                                                      reply.content,
                                                      style: theme.textTheme
                                                          .bodySmall,
                                                    ),
                                                    Text(
                                                      _getTimeAgo(reply.createdAt),
                                                      style: theme.textTheme
                                                          .bodySmall
                                                          ?.copyWith(
                                                        color: Colors.grey[600],
                                                        fontSize: 10,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        )),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

