import 'package:flutter/material.dart';
import '../../core/ui/snackbar.dart';
import 'security_service.dart';

class IncidentPage extends StatefulWidget { const IncidentPage({super.key}); @override State<IncidentPage> createState()=>_IncidentPageState(); }

class _IncidentPageState extends State<IncidentPage> {
  final _f = GlobalKey<FormState>();
  final _t = TextEditingController(), _c = TextEditingController();
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ghi nhận sự cố')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _f,
          child: ListView(children: [
            TextFormField(controller: _t, decoration: const InputDecoration(labelText: 'Tiêu đề'), validator: (v)=>(v==null||v.isEmpty)?'Bắt buộc':null),
            const SizedBox(height: 8),
            TextFormField(controller: _c, minLines: 3, maxLines: 6, decoration: const InputDecoration(labelText: 'Mô tả chi tiết'), validator: (v)=>(v==null||v.isEmpty)?'Bắt buộc':null),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loading? null : () async {
                if(!_f.currentState!.validate()) return;
                setState(()=>_loading=true);
                try {
                  await SecurityService().createIncident(title: _t.text.trim(), content: _c.text.trim());
                  if(!mounted) return;
                  showSnack(context, 'Đã ghi nhận sự cố');
                  Navigator.pop(context);
                } catch (e) {
                  showSnack(context, 'Lỗi: $e', error: true);
                } finally { setState(()=>_loading=false); }
              },
              icon: _loading ? const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2))
                  : const Icon(Icons.add_alert),
              label: const Text('Gửi'),
            )
          ]),
        ),
      ),
    );
  }
}
