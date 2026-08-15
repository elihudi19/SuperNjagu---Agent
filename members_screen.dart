import 'package:flutter/material.dart';
import '../models/member.dart';
import '../services/data_repository.dart';

class MembersScreen extends StatefulWidget {
  final DataRepository repo;
  final VoidCallback? onLogout;
  final String? loggedInAs;
  const MembersScreen({super.key, required this.repo, this.onLogout, this.loggedInAs});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  List<Member> _members = [];
  bool _loading = true;
  bool _saving = false;
  String? _msg;
  bool _msgOk = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await widget.repo.fetchMembers();
    setState(() {
      _loading = false;
      if (res.ok) {
        _members = res.data ?? [];
      } else {
        _msg = res.message;
        _msgOk = false;
      }
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _msg = null;
    });
    final res = await widget.repo.saveMembers(_members, 'Sasisha members.csv kupitia app');
    setState(() {
      _saving = false;
      _msg = res.message;
      _msgOk = res.ok;
    });
  }

  void _editMember(int index) async {
    final m = _members[index];
    final result = await showDialog<Member>(
      context: context,
      builder: (ctx) => _MemberEditDialog(member: m),
    );
    if (result != null) {
      setState(() => _members[index] = result);
    }
  }

  void _addMember() async {
    final result = await showDialog<Member>(
      context: context,
      builder: (ctx) => _MemberEditDialog(member: Member(na: '${_members.length + 1}')),
    );
    if (result != null) {
      setState(() => _members.add(result));
    }
  }

  void _deleteMember(int index) {
    setState(() => _members.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    final missingPhone = _members.where((m) => m.namba.trim().isEmpty).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('👥 Registration — Backend ya Wanachama'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loading ? null : _load),
          if (widget.onLogout != null)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Umeingia kama ${widget.loggedInAs ?? ''} — Toka',
              onPressed: widget.onLogout,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addMember,
        child: const Icon(Icons.person_add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_msg != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    color: _msgOk ? Colors.green.shade50 : Colors.red.shade50,
                    child: Text(_msg!),
                  ),
                if (missingPhone > 0)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    color: Colors.orange.shade50,
                    child: Text('⚠️ Wanachama $missingPhone hawana namba ya simu.'),
                  ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: _saving
                              ? const SizedBox(
                                  height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.cloud_upload),
                          label: const Text('Pandisha GitHub'),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _members.length,
                    itemBuilder: (ctx, i) {
                      final m = _members[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        child: ListTile(
                          title: Text(m.jinaLaKawaida.isEmpty ? '(Bila Jina)' : m.jinaLaKawaida),
                          subtitle: Text(
                              'Usajili: ${m.jinaLaUsajili}\nSimu: ${m.namba}  •  Jinsia: ${m.jinsia}'),
                          isThreeLine: true,
                          onTap: () => _editMember(i),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteMember(i),
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

class _MemberEditDialog extends StatefulWidget {
  final Member member;
  const _MemberEditDialog({required this.member});

  @override
  State<_MemberEditDialog> createState() => _MemberEditDialogState();
}

class _MemberEditDialogState extends State<_MemberEditDialog> {
  late final TextEditingController _kawaida;
  late final TextEditingController _usajili;
  late final TextEditingController _simu;
  late final TextEditingController _smsOverride;
  late String _jinsia;

  @override
  void initState() {
    super.initState();
    _kawaida = TextEditingController(text: widget.member.jinaLaKawaida);
    _usajili = TextEditingController(text: widget.member.jinaLaUsajili);
    _simu = TextEditingController(text: widget.member.namba);
    _smsOverride = TextEditingController(text: widget.member.nambaSms);
    _jinsia = widget.member.jinsia.isEmpty ? 'ME' : widget.member.jinsia;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Taarifa za Mwanachama'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _kawaida, decoration: const InputDecoration(labelText: 'Jina la Kawaida')),
            TextField(controller: _usajili, decoration: const InputDecoration(labelText: 'Jina la Usajili (M-Koba)')),
            TextField(controller: _simu, decoration: const InputDecoration(labelText: 'Namba ya Simu'), keyboardType: TextInputType.phone),
            TextField(controller: _smsOverride, decoration: const InputDecoration(labelText: 'Namba ya SMS (override, si lazima)'), keyboardType: TextInputType.phone),
            DropdownButtonFormField<String>(
              value: _jinsia,
              decoration: const InputDecoration(labelText: 'Jinsia'),
              items: const [
                DropdownMenuItem(value: 'ME', child: Text('ME')),
                DropdownMenuItem(value: 'KE', child: Text('KE')),
              ],
              onChanged: (v) => setState(() => _jinsia = v ?? 'ME'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Ghairi')),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(
              context,
              widget.member.copyWith(
                jinaLaKawaida: _kawaida.text,
                jinaLaUsajili: _usajili.text,
                namba: _simu.text,
                nambaSms: _smsOverride.text,
                jinsia: _jinsia,
              ),
            );
          },
          child: const Text('Hifadhi'),
        ),
      ],
    );
  }
}
