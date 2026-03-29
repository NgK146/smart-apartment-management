import 'package:flutter/material.dart';
import '../../core/ui/snackbar.dart';
import 'security_service.dart';

class SecurityComplaintsPage extends StatefulWidget {
  const SecurityComplaintsPage({super.key});
  @override
  State<SecurityComplaintsPage> createState() => _SecurityComplaintsPageState();
}

class _SecurityComplaintsPageState extends State<SecurityComplaintsPage> {
  final _svc = SecurityService();
  final _items = <ComplaintItem>[];
  bool _loading = true, _done = false;
  int _page = 1;
  String _filterStatus = ComplaintStatus.new_;
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _load(refresh: true);
    _controller.addListener(() {
      if (_controller.position.pixels > _controller.position.maxScrollExtent - 120 && !_loading && !_done) {
        _load();
      }
    });
  }

  Future<void> _load({bool refresh = false}) async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      if (refresh) { _page = 1; _done = false; _items.clear(); }
      final data = await _svc.listComplaints(
        status: _filterStatus,
        category: 'Security',
        // Có thể bỏ assignedToMe để xem toàn bộ hàng chờ
        page: _page, pageSize: 20,
      );
      if (!mounted) return; // Check before setState after async
      setState(() {
        _items.addAll(data);
        if (data.length < 20) _done = true;
        _page++;
      });
    } catch (e) {
      if (!mounted) return; // Check before showSnack
      showSnack(context, 'Lỗi tải phản ánh: $e', error: true);
    } finally {
      if (!mounted) return; // Check before final setState
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Xử lý phản ánh'),
        actions: [
          PopupMenuButton<String>(
            initialValue: _filterStatus,
            onSelected: (v) { setState(()=>_filterStatus = v); _load(refresh:true); },
            itemBuilder: (_) => const [
              PopupMenuItem(value: ComplaintStatus.new_, child: Text('Mới')),
              PopupMenuItem(value: ComplaintStatus.inProgress, child: Text('Đang xử lý')),
              PopupMenuItem(value: ComplaintStatus.resolved, child: Text('Đã xử lý')),
              PopupMenuItem(value: ComplaintStatus.rejected, child: Text('Từ chối')),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(children: const [Icon(Icons.filter_list), SizedBox(width: 8), Text('Lọc')]),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(refresh: true),
        child: ListView.builder(
          controller: _controller,
          itemCount: _items.length + 1,
          itemBuilder: (c, i) {
            if (i == _items.length) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Center(child: _loading ? const CircularProgressIndicator() : const SizedBox.shrink()),
              );
            }
            final m = _items[i];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                leading: const Icon(Icons.report),
                title: Text(m.title),
                subtitle: Text('${m.category} • ${m.status}\n${m.content}', maxLines: 2, overflow: TextOverflow.ellipsis),
                isThreeLine: true,
                trailing: _ActionButtons(item: m, onChanged: () => _load(refresh: true)),
                onTap: () => showModalBottomSheet(
                  context: context,
                  showDragHandle: true,
                  builder: (_) => _ComplaintDetail(item: m, onChanged: () => _load(refresh: true)),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ActionButtons extends StatefulWidget {
  final ComplaintItem item;
  final VoidCallback onChanged;
  const _ActionButtons({required this.item, required this.onChanged});

  @override
  State<_ActionButtons> createState() => _ActionButtonsState();
}

class _ActionButtonsState extends State<_ActionButtons> {
  final _svc = SecurityService();
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.item.status;
    return Wrap(spacing: 8, children: [
      if (s == ComplaintStatus.new_) OutlinedButton(
          onPressed: _busy ? null : () async {
            setState(()=>_busy=true);
            try { await _svc.assignToMe(widget.item.id); await _svc.setStatus(widget.item.id, ComplaintStatus.inProgress); widget.onChanged(); }
            catch(e){ showSnack(context, 'Nhận việc lỗi: $e', error: true); }
            finally { setState(()=>_busy=false); }
          }, child: const Text('Nhận việc')),
      if (s == ComplaintStatus.inProgress) FilledButton(
          onPressed: _busy ? null : () async {
            setState(()=>_busy=true);
            try { await _svc.setStatus(widget.item.id, ComplaintStatus.resolved); widget.onChanged(); }
            catch(e){ showSnack(context, 'Cập nhật lỗi: $e', error: true); }
            finally { setState(()=>_busy=false); }
          }, child: const Text('Hoàn tất')),
    ]);
  }
}

class _ComplaintDetail extends StatefulWidget {
  final ComplaintItem item; final VoidCallback onChanged;
  const _ComplaintDetail({required this.item, required this.onChanged});
  @override State<_ComplaintDetail> createState()=>_ComplaintDetailState();
}

class _ComplaintDetailState extends State<_ComplaintDetail> {
  final _msg = TextEditingController();
  final _svc = SecurityService();
  bool _sending = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.item;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(m.title, style: Theme.of(context).textTheme.titleLarge),
        Text('${m.category} • ${m.status}'),
        const Divider(),
        Text(m.content),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TextField(controller: _msg, decoration: const InputDecoration(hintText: 'Nhập bình luận...'))),
          IconButton(onPressed: _sending?null:() async {
            if (_msg.text.trim().isEmpty) return;
            setState(()=>_sending=true);
            try { await _svc.addComment(m.id, _msg.text.trim()); _msg.clear(); widget.onChanged(); showSnack(context, 'Đã gửi bình luận'); }
            catch(e){ showSnack(context, 'Lỗi: $e', error: true); }
            finally { setState(()=>_sending=false); }
          }, icon: const Icon(Icons.send))
        ]),
        const SizedBox(height: 8),
      ]),
    );
  }
}

