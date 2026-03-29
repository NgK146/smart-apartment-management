import 'package:flutter/material.dart';
import '../../core/ui/snackbar.dart';
import 'vendor_service.dart';

class VendorTasksPage extends StatefulWidget { const VendorTasksPage({super.key}); @override State<VendorTasksPage> createState()=>_VendorTasksPageState(); }

class _VendorTasksPageState extends State<VendorTasksPage> {
  final _svc = VendorService();
  final _items = <VendorTask>[];
  bool _loading = true, _done=false; int _page=1;
  String _statusFilter = TaskStatus.inProgress; // mặc định công việc đang làm
  final _sc = ScrollController();

  @override void initState(){ super.initState(); _load(refresh:true); _sc.addListener(_onScroll); }
  void _onScroll(){ if(_sc.position.pixels > _sc.position.maxScrollExtent-120 && !_loading && !_done) _load(); }

  Future<void> _load({bool refresh=false}) async {
    setState(()=>_loading=true);
    try{
      if(refresh){ _page=1; _done=false; _items.clear(); }
      final data = await _svc.listMyTasks(status: _statusFilter, page:_page, pageSize: 20);
      setState((){ _items.addAll(data); if(data.length<20) _done=true; _page++; });
    } catch(e){ showSnack(context, 'Lỗi tải công việc: $e', error:true); }
    finally { setState(()=>_loading=false); }
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Công việc của tôi'),
        actions: [
          PopupMenuButton<String>(
            initialValue: _statusFilter,
            onSelected: (v){ setState(()=>_statusFilter=v); _load(refresh:true); },
            itemBuilder: (_) => const [
              PopupMenuItem(value: TaskStatus.new_, child: Text('Mới')),
              PopupMenuItem(value: TaskStatus.inProgress, child: Text('Đang làm')),
              PopupMenuItem(value: TaskStatus.resolved, child: Text('Đã hoàn tất')),
            ],
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: ()=>_load(refresh:true),
        child: ListView.builder(
          controller: _sc,
          itemCount: _items.length + 1,
          itemBuilder: (c,i){
            if(i==_items.length) return Padding(padding: const EdgeInsets.all(16), child: Center(child:_loading?const CircularProgressIndicator():const SizedBox.shrink()));
            final t = _items[i];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                title: Text(t.title),
                subtitle: Text('${t.category} • ${t.status}\n${t.content}', maxLines: 2, overflow: TextOverflow.ellipsis),
                isThreeLine: true,
                trailing: _TaskActions(task: t, onChanged: ()=>_load(refresh:true)),
                onTap: ()=> showModalBottomSheet(context: context, showDragHandle: true, builder: (_)=> _TaskDetail(task: t, onChanged: ()=>_load(refresh:true))),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TaskActions extends StatefulWidget {
  final VendorTask task; final VoidCallback onChanged;
  const _TaskActions({required this.task, required this.onChanged});
  @override State<_TaskActions> createState()=>_TaskActionsState();
}
class _TaskActionsState extends State<_TaskActions>{
  final _svc = VendorService(); bool _busy=false;
  @override Widget build(BuildContext context) {
    final s = widget.task.status;
    return Wrap(spacing: 8, children: [
      if (s == TaskStatus.new_) OutlinedButton(
          onPressed: _busy?null:() async {
            setState(()=>_busy=true);
            try { await _svc.setStatus(widget.task.id, TaskStatus.inProgress); widget.onChanged(); }
            catch(e){ showSnack(context, 'Nhận việc lỗi: $e', error:true); }
            finally { setState(()=>_busy=false); }
          }, child: const Text('Nhận việc')),
      if (s == TaskStatus.inProgress) FilledButton(
          onPressed: _busy?null:() async {
            setState(()=>_busy=true);
            try { await _svc.setStatus(widget.task.id, TaskStatus.resolved); widget.onChanged(); }
            catch(e){ showSnack(context, 'Cập nhật lỗi: $e', error:true); }
            finally { setState(()=>_busy=false); }
          }, child: const Text('Hoàn tất')),
    ]);
  }
}

class _TaskDetail extends StatefulWidget {
  final VendorTask task; final VoidCallback onChanged;
  const _TaskDetail({required this.task, required this.onChanged});
  @override State<_TaskDetail> createState()=>_TaskDetailState();
}
class _TaskDetailState extends State<_TaskDetail> {
  final _msg = TextEditingController(); final _svc = VendorService(); bool _sending=false;
  @override Widget build(BuildContext context) {
    final t = widget.task;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t.title, style: Theme.of(context).textTheme.titleLarge),
        Text('${t.category} • ${t.status}'),
        const Divider(),
        Text(t.content),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TextField(controller: _msg, decoration: const InputDecoration(hintText: 'Gửi ghi chú/bình luận...'))),
          IconButton(onPressed: _sending? null : () async {
            if (_msg.text.trim().isEmpty) return;
            setState(()=>_sending=true);
            try { await _svc.addComment(t.id, _msg.text.trim()); _msg.clear(); widget.onChanged(); showSnack(context, 'Đã gửi bình luận'); }
            catch(e){ showSnack(context, 'Lỗi: $e', error:true); }
            finally { setState(()=>_sending=false); }
          }, icon: const Icon(Icons.send))
        ])
      ]),
    );
  }
}
