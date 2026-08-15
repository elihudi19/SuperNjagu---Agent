import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/member.dart';
import '../services/app_state.dart';
import '../services/pushbullet_service.dart';
import '../services/text_utils.dart';

class BroadcastScreen extends StatefulWidget {
  final VoidCallback? onLogout;
  const BroadcastScreen({super.key, this.onLogout});

  @override
  State<BroadcastScreen> createState() => _BroadcastScreenState();
}

class _BroadcastScreenState extends State<BroadcastScreen> {
  List<Member> _validMembers = [];
  final Set<String> _selectedNames = {};
  final _textCtrl = TextEditingController();
  bool _loading = true;
  bool _sending = false;
  double _progress = 0;
  String? _msg;
  bool _msgOk = false;
  List<SmsFailure> _failures = [];
  bool _selectAll = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final state = context.read<AppState>();
    final res = await state.repo.fetchMembers();
    if (!res.ok) {
      setState(() {
        _loading = false;
        _msg = res.message;
        _msgOk = false;
      });
      return;
    }
    final members = res.data ?? [];
    final valid = members.where((m) {
      final smsPhone = TextUtils.cleanPhone(m.nambaSms).isNotEmpty
          ? TextUtils.cleanPhone(m.nambaSms)
          : TextUtils.cleanPhone(m.namba);
      return smsPhone.isNotEmpty;
    }).toList();
    setState(() {
      _validMembers = valid;
      _loading = false;
    });
  }

  String _smsPhoneFor(Member m) {
    final override = TextUtils.cleanPhone(m.nambaSms);
    return override.isNotEmpty ? override : TextUtils.cleanPhone(m.namba);
  }

  Future<void> _send() async {
    final state = context.read<AppState>();
    if (_textCtrl.text.trim().isEmpty) {
      setState(() {
        _msg = 'Andika ujumbe kwanza.';
        _msgOk = false;
      });
      return;
    }
    if (_selectedNames.isEmpty) {
      setState(() {
        _msg = "Chagua angalau mwanachama mmoja (au 'Chagua Wote').";
        _msgOk = false;
      });
      return;
    }
    if (state.user.pushbulletToken.isEmpty) {
      setState(() {
        _msg = 'Huna Pushbullet Token iliyowekwa kwenye wasifu wako.';
        _msgOk = false;
      });
      return;
    }
    if (state.selectedDeviceIden.isEmpty) {
      setState(() {
        _msg = 'Hakuna simu (device) iliyochaguliwa - fungua Wasifu Wangu.';
        _msgOk = false;
      });
      return;
    }

    setState(() {
      _sending = true;
      _progress = 0;
      _failures = [];
      _msg = null;
    });

    final targets = _validMembers.where((m) => _selectedNames.contains(m.jinaLaKawaida)).toList();
    final fullMessage = '[ELIAMINI FAMILY - TANGAZO]\n${_textCtrl.text.trim()}';
    final items = targets
        .map((m) => SmsSendItem(_smsPhoneFor(m), fullMessage, m.jinaLaKawaida))
        .toList();

    final (successCount, failures) = await PushbulletService.sendSmsBulk(
      items,
      state.selectedDeviceIden,
      state.user.pushbulletToken,
      maxWorkers: state.smsWorkers,
      onProgress: (p) => setState(() => _progress = p),
    );

    setState(() {
      _sending = false;
      _failures = failures;
      _msg = 'Tangazo limetumwa kwa $successCount kati ya ${items.length}.';
      _msgOk = failures.isEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📢 Broadcast SMS'),
        actions: [
          if (widget.onLogout != null)
            IconButton(icon: const Icon(Icons.logout), onPressed: widget.onLogout),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(14),
              children: [
                Text('Wanachama ${_validMembers.length} wenye namba wanapatikana kuchaguliwa.',
                    style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 10),
                CheckboxListTile(
                  title: const Text('Chagua Wote'),
                  value: _selectAll,
                  onChanged: (v) {
                    setState(() {
                      _selectAll = v ?? false;
                      _selectedNames.clear();
                      if (_selectAll) {
                        _selectedNames.addAll(_validMembers.map((m) => m.jinaLaKawaida));
                      }
                    });
                  },
                ),
                const Divider(),
                ..._validMembers.map((m) => CheckboxListTile(
                      title: Text(m.jinaLaKawaida.isEmpty ? '(Bila Jina)' : m.jinaLaKawaida),
                      subtitle: Text(TextUtils.formatPhoneForSms(_smsPhoneFor(m))),
                      value: _selectedNames.contains(m.jinaLaKawaida),
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _selectedNames.add(m.jinaLaKawaida);
                          } else {
                            _selectedNames.remove(m.jinaLaKawaida);
                            _selectAll = false;
                          }
                        });
                      },
                    )),
                const Divider(),
                const SizedBox(height: 8),
                TextField(
                  controller: _textCtrl,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Andika ujumbe wa tangazo hapa',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                if (_msg != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _msgOk ? Colors.green.shade50 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_msg!),
                  ),
                if (_sending) ...[
                  const SizedBox(height: 10),
                  LinearProgressIndicator(value: _progress),
                ],
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.campaign),
                  label: const Text('🚀 Tuma Tangazo Kwa Waliochaguliwa'),
                ),
                if (_failures.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text('❌ Zilizoshindikana:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ..._failures.map((f) => Text('${f.jina} (${f.namba}) — ${f.tatizo}')),
                ],
              ],
            ),
    );
  }
}
