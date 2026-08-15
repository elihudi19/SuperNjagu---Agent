import 'package:flutter/material.dart';
import '../models/ledger_entry.dart';
import '../services/data_repository.dart';
import '../services/debt_calculator.dart';

class LedgerScreen extends StatefulWidget {
  final DataRepository repo;
  final VoidCallback? onLogout;
  final String? loggedInAs;
  const LedgerScreen({super.key, required this.repo, this.onLogout, this.loggedInAs});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  List<LedgerEntry> _ledger = [];
  bool _loading = true;
  bool _saving = false;
  String? _msg;
  bool _msgOk = false;
  int _idadiYaMiezi = 8;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final ledgerRes = await widget.repo.fetchLedger();
    final membersRes = await widget.repo.fetchMembers();
    setState(() {
      _loading = false;
      if (ledgerRes.ok && membersRes.ok) {
        _ledger = DataRepository.ensureLedgerHasAllMembers(
            ledgerRes.data ?? [], membersRes.data ?? []);
      } else {
        _msg = !ledgerRes.ok ? ledgerRes.message : membersRes.message;
        _msgOk = false;
      }
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _msg = null;
    });
    final res = await widget.repo.saveLedger(_ledger, 'Sasisha ledger kupitia app');
    setState(() {
      _saving = false;
      _msg = res.message;
      _msgOk = res.ok;
    });
  }

  void _editEntry(int index) async {
    final l = _ledger[index];
    final result = await showDialog<LedgerEntry>(
      context: context,
      builder: (ctx) => _LedgerEditDialog(entry: l),
    );
    if (result != null) setState(() => _ledger[index] = result);
  }

  void _deleteEntry(int index) => setState(() => _ledger.removeAt(index));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🧮 Ledger — Deni la Wanachama'),
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: Row(
                    children: [
                      const Text('Idadi ya Miezi:'),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Slider(
                          value: _idadiYaMiezi.toDouble(),
                          min: 1,
                          max: 24,
                          divisions: 23,
                          label: '$_idadiYaMiezi',
                          onChanged: (v) => setState(() => _idadiYaMiezi = v.round()),
                        ),
                      ),
                      Text('$_idadiYaMiezi'),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
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
                const SizedBox(height: 6),
                Expanded(
                  child: ListView.builder(
                    itemCount: _ledger.length,
                    itemBuilder: (ctx, i) {
                      final l = _ledger[i];
                      final status = DebtCalculator.computeMemberStatus(
                        mchangoJumla: l.mchangoJumla,
                        kianzioHali: l.kianzioHali,
                        gender: l.jinsia,
                        idadiYaMiezi: _idadiYaMiezi,
                      );
                      final jina = l.jinaLaKawaida.isNotEmpty ? l.jinaLaKawaida : l.jinaLaUsajili;
                      final deniColor = status.jumlaDeni > 0
                          ? Colors.red
                          : (status.ziada > 0 ? Colors.green : Colors.grey);
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        child: ListTile(
                          title: Text(jina.isEmpty ? '(Bila Jina)' : jina),
                          subtitle: Text(
                            'Mchango Jumla: TZS ${l.mchangoJumla.toStringAsFixed(0)}\n'
                            'Kianzio: ${l.kianzioHali}  •  Jinsia: ${l.jinsia}',
                          ),
                          isThreeLine: true,
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                status.jumlaDeni > 0
                                    ? 'Deni: ${status.jumlaDeni.toStringAsFixed(0)}'
                                    : (status.ziada > 0
                                        ? 'Ziada: ${status.ziada.toStringAsFixed(0)}'
                                        : 'Hakuna Deni'),
                                style: TextStyle(color: deniColor, fontWeight: FontWeight.bold),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                onPressed: () => _deleteEntry(i),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                          onTap: () => _editEntry(i),
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

class _LedgerEditDialog extends StatefulWidget {
  final LedgerEntry entry;
  const _LedgerEditDialog({required this.entry});

  @override
  State<_LedgerEditDialog> createState() => _LedgerEditDialogState();
}

class _LedgerEditDialogState extends State<_LedgerEditDialog> {
  late final TextEditingController _mchango;
  late String _jinsia;
  late String _kianzio;

  @override
  void initState() {
    super.initState();
    _mchango = TextEditingController(text: widget.entry.mchangoJumla.toStringAsFixed(0));
    _jinsia = widget.entry.jinsia.isEmpty ? 'ME' : widget.entry.jinsia;
    _kianzio = widget.entry.kianzioHali.isEmpty ? 'INAHITAJIKA' : widget.entry.kianzioHali;
  }

  @override
  Widget build(BuildContext context) {
    final jina = widget.entry.jinaLaKawaida.isNotEmpty
        ? widget.entry.jinaLaKawaida
        : widget.entry.jinaLaUsajili;
    return AlertDialog(
      title: Text(jina.isEmpty ? 'Mwanachama' : jina),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _mchango,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Mchango Jumla (TZS)'),
          ),
          DropdownButtonFormField<String>(
            value: _jinsia,
            decoration: const InputDecoration(labelText: 'Jinsia'),
            items: const [
              DropdownMenuItem(value: 'ME', child: Text('ME')),
              DropdownMenuItem(value: 'KE', child: Text('KE')),
            ],
            onChanged: (v) => setState(() => _jinsia = v ?? 'ME'),
          ),
          DropdownButtonFormField<String>(
            value: _kianzio,
            decoration: const InputDecoration(labelText: 'Kianzio Hali'),
            items: const [
              DropdownMenuItem(value: 'INAHITAJIKA', child: Text('INAHITAJIKA')),
              DropdownMenuItem(value: 'HAHUSIKI', child: Text('HAHUSIKI')),
            ],
            onChanged: (v) => setState(() => _kianzio = v ?? 'INAHITAJIKA'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Ghairi')),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(
              context,
              LedgerEntry(
                jinaLaKawaida: widget.entry.jinaLaKawaida,
                jinaLaUsajili: widget.entry.jinaLaUsajili,
                namba: widget.entry.namba,
                jinsia: _jinsia,
                kianzioHali: _kianzio,
                mchangoJumla: double.tryParse(_mchango.text) ?? widget.entry.mchangoJumla,
              ),
            );
          },
          child: const Text('Hifadhi'),
        ),
      ],
    );
  }
}
