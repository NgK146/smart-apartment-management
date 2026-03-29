import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../config/config_url.dart';
import '../auth/auth_provider.dart';
import '../chat/chat_models.dart';
import '../chat/chat_service.dart';
import '../chat/create_post_screen.dart';
import '../chat/post_detail_screen.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage>
    with SingleTickerProviderStateMixin {
  final _postService = CommunityPostService();
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  late TabController _tabController;
  PostType _currentType = PostType.news;

  List<CommunityPost> _posts = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _currentPage = 1;
  bool _hasMore = true;
  String? _searchQuery;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadPosts();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      setState(() {
        _currentType = _tabController.index == 0
            ? PostType.news
            : _tabController.index == 1
                ? PostType.discussion
                : PostType.suggestion;
        _currentPage = 1;
        _hasMore = true;
        _posts.clear();
        _loading = true;
      });
      _loadPosts();
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.8 &&
        !_loadingMore &&
        _hasMore &&
        !_loading) {
      _loadMorePosts();
    }
  }

  Future<void> _loadPosts({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _currentPage = 1;
        _hasMore = true;
        _posts.clear();
      });
    } else if (!_loading) {
      return;
    }

    try {
      final posts = await _postService.fetchPosts(
        type: _currentType,
        page: 1,
        pageSize: 20,
        search: _searchQuery,
      );
      if (mounted) {
        setState(() {
          _posts = posts;
          _currentPage = 1;
          _hasMore = posts.length >= 20;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        print('Lỗi _loadPosts: $e');
        print('Type: $_currentType');
        setState(() {
          _error = e.toString();
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải bài đăng: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _loadMorePosts() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final posts = await _postService.fetchPosts(
        type: _currentType,
        page: _currentPage + 1,
        pageSize: 20,
        search: _searchQuery,
      );
      if (mounted) {
        setState(() {
          _posts.addAll(posts);
          _currentPage++;
          _hasMore = posts.length >= 20;
          _loadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingMore = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải thêm: $e')),
        );
      }
    }
  }

  Future<void> _onRefresh() async {
    await _loadPosts(refresh: true);
  }

  void _onSearch(String query) {
    setState(() {
      _searchQuery = query.isEmpty ? null : query;
      _currentPage = 1;
      _hasMore = true;
      _posts.clear();
      _loading = true;
    });
    _loadPosts();
  }

  Future<void> _createPost() async {
    final auth = context.read<AuthState>();

    // Kiểm tra quyền: Chỉ admin/BQT được đăng TIN TỨC
    if (_currentType == PostType.news && !auth.isManagerLike) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chỉ Ban Quản Trị mới được đăng tin tức'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreatePostScreen(type: _currentType),
      ),
    );
    if (result == true && mounted) {
      _onRefresh();
    }
  }

  Future<void> _openPostDetail(CommunityPost post) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostDetailScreen(post: post),
      ),
    );
    if (result == true && mounted) {
      _onRefresh();
    }
  }

  Future<void> _toggleLike(CommunityPost post, int index) async {
    final wasLiked = post.isLiked;
    setState(() {
      _posts[index] = post.copyWith(
        isLiked: !wasLiked,
        likeCount: wasLiked ? post.likeCount - 1 : post.likeCount + 1,
      );
    });
    try {
      final updated = await _postService.toggleLike(post.id);
      if (mounted) {
        setState(() {
          _posts[index] = updated;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _posts[index] = post;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();

    return Scaffold(
      body: NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            pinned: true,
            expandedHeight: 120,
            title: const Text(
              'Bảng tin cư dân',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            iconTheme: const IconThemeData(color: Colors.white),
            actionsIconTheme: const IconThemeData(color: Colors.white),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                } else {
                  Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
                }
              },
              tooltip: 'Quay lại',
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.search, color: Colors.white),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Tìm kiếm'),
                      content: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'Nhập từ khóa...',
                          border: OutlineInputBorder(),
                        ),
                        autofocus: true,
                        onSubmitted: (value) {
                          _onSearch(value);
                          Navigator.pop(dialogContext);
                        },
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            _searchController.clear();
                            _onSearch('');
                            Navigator.pop(dialogContext);
                          },
                          child: const Text('Hủy'),
                        ),
                        TextButton(
                          onPressed: () {
                            _onSearch(_searchController.text);
                            Navigator.pop(dialogContext);
                          },
                          child: const Text('Tìm'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.secondary
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            bottom: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.normal,
                fontSize: 14,
              ),
              tabs: const [
                Tab(text: 'TIN TỨC'),
                Tab(text: 'THẢO LUẬN'),
                Tab(text: 'KIẾN NGHỊ'),
              ],
            ),
          )
        ],
        body: _buildBody(auth),
      ),
      floatingActionButton: _buildFAB(auth),
    );
  }

  Widget _buildBody(AuthState auth) {
    if (_loading && _posts.isEmpty) {
      return _buildLoadingState();
    }

    if (_error != null && _posts.isEmpty) {
      return _buildErrorState();
    }

    if (_posts.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: TabBarView(
        controller: _tabController,
        children: [
          _buildPostList(),
          _buildPostList(),
          _buildPostList(),
        ],
      ),
    );
  }

  Widget _buildPostList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _posts.length + (_loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _posts.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }
        final post = _posts[index];
        return _PostCard(
          post: post,
          onTap: () => _openPostDetail(post),
          onLike: () => _toggleLike(post, index),
          onEdit: post.canEdit
              ? () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreatePostScreen(
                        type: post.type,
                        post: post,
                      ),
                    ),
                  );
                  if (result == true && mounted) {
                    _onRefresh();
                  }
                }
              : null,
          onDelete: post.canDelete
              ? () async {
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
                          child: const Text('Xóa',
                              style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    try {
                      await _postService.deletePost(post.id);
                      if (mounted) {
                        setState(() {
                          _posts.removeAt(index);
                        });
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
              : null,
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (_, __) => _SkeletonPostCard(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Không thể tải bảng tin',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Vui lòng kiểm tra kết nối mạng và thử lại',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _error = null;
                  _loading = true;
                });
                _loadPosts();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    String title, message, icon;
    switch (_currentType) {
      case PostType.news:
        title = 'Chưa có tin tức nào';
        message = 'Ban Quản Trị chưa đăng tin tức nào.';
        icon = '📢';
        break;
      case PostType.discussion:
        title = 'Chưa có thảo luận nào';
        message = 'Hãy là người đầu tiên chia sẻ thông tin với cộng đồng.';
        icon = '💬';
        break;
      case PostType.suggestion:
        title = 'Chưa có kiến nghị nào';
        message = 'Bạn có kiến nghị gì muốn gửi lên Ban Quản Trị?';
        icon = '📝';
        break;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              icon,
              style: const TextStyle(fontSize: 64),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildFAB(AuthState auth) {
    // Chỉ hiển thị FAB cho THẢO LUẬN và KIẾN NGHỊ
    // TIN TỨC chỉ admin mới được đăng (đã check trong _createPost)
    if (_currentType == PostType.news && !auth.isManagerLike) {
      return null;
    }
    return FloatingActionButton(
      heroTag: 'notifications-fab-${_currentType.name}',
      onPressed: _createPost,
      child: const Icon(Icons.add),
      tooltip: 'Tạo bài đăng',
    );
  }
}

// Import các widget components từ chat_page.dart
class _PostCard extends StatelessWidget {
  final CommunityPost post;
  final VoidCallback? onTap;
  final VoidCallback? onLike;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _PostCard({
    required this.post,
    this.onTap,
    this.onLike,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeAgo = _getTimeAgo(post.createdAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Avatar + Name + Time + Menu
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
                  if (onEdit != null || onDelete != null)
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit' && onEdit != null) {
                          onEdit!();
                        } else if (value == 'delete' && onDelete != null) {
                          onDelete!();
                        }
                      },
                      itemBuilder: (context) => [
                        if (onEdit != null)
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 20),
                                SizedBox(width: 8),
                                Text('Sửa'),
                              ],
                            ),
                          ),
                        if (onDelete != null)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, size: 20, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Xóa', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                      ],
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
              // Content preview
              Text(
                post.content,
                style: theme.textTheme.bodyMedium,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              // Images preview
              if (post.imageUrls.isNotEmpty) ...[
                const SizedBox(height: 12),
                _ImagePreview(images: post.imageUrls),
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

class _ImagePreview extends StatelessWidget {
  final List<String> images;

  const _ImagePreview({required this.images});

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 150,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: images.length > 3 ? 3 : images.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.only(right: index < 2 ? 8 : 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  Image.network(
                    AppConfig.resolve(images[index]),
                    width: 150,
                    height: 150,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 150,
                      height: 150,
                      color: Colors.grey[300],
                      child: const Icon(Icons.broken_image),
                    ),
                  ),
                  if (index == 2 && images.length > 3)
                    Container(
                      width: 150,
                      height: 150,
                      color: Colors.black54,
                      alignment: Alignment.center,
                      child: Text(
                        '+${images.length - 3}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SkeletonPostCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(radius: 20, backgroundColor: Colors.grey[300]),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 16,
                        width: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 12,
                        width: 80,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              height: 20,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 16,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 16,
              width: 200,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
