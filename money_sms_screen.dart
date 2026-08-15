import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ledger_entry.dart';
import '../models/member.dart';
import '../services/app_state.dart';
import '../services/data_repository.dart';
import '../services/debt_calculator.dart';
import '../services/deposit_matcher.dart';
import '../services/pdf_parser_service.dart';
import '../services/pushbullet_service.dart';
import '../services/text_utils.dart';

class _SmsRow {
  final int ledgerIndex;
  final String jina;
  String phone; // inayoweza kuhaririwa
  final String message;
  _SmsRow({required this.ledgerIndex, required this.jina, required this.phone, required this.message});
}

class MoneySmsScreen extends StatefulWidget {
  final VoidCallback? onLogout;
  const MoneySmsScreen({super.key, this.onLogout});

  @override
  State<MoneySmsScreen> createState() => _MoneySmsScreenState();
}

class _MoneySmsScreenState extends State<MoneySmsScreen> {
  List<LedgerEntry> _ledger = [];
  List<Member> _members = [];
  Map<int, double> _depositAmounts = {};
  List<Deposit> _unmatched = [];
  String? _pdfName;

  bool _parsing = false;
  bool _savingLedger = false;
  bool _savingSmsNumbers = false;
  bool _sending = false;
  double _sendProgress = 0;
  String? _msg;
  bool _msgOk = false;
  List<SmsFailure> _lastFailures = [];

  List<_SmsRow> _smsRows = [];

  Future<void> _pickAndParse() async {
    setState(() {
      _msg = null;
      _parsing = true;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
      if (result == null || result.files.single.bytes == null) {
        setState(() => _parsing = false);
        return;
      }
      final Uint8List bytes = result.files.single.bytes!;
      _pdfName = result.files.single.name;

      final deposits = PdfParserService.parseVodacomPdf(bytes);

      final state = context.read<AppState>();
      final ledgerRes = await state.repo.fetchLedger();
      final membersRes = await state.repo.fetchMembers();
      if (!ledgerRes.ok || !membersRes.ok) {
        setState(() {
          _parsing = false;
          _msg = !ledgerRes.ok ? ledgerRes.message : membersRes.message;
          _msgOk = false;
        });
        return;
      }
      final members = membersRes.data ?? [];
      var ledger = DataRepository.ensureLedgerHasAllMembers(ledgerRes.data ?? [], members);

      final match = DepositMatcher.matchByPhoneOnly(deposits, ledger);
      final depositAmounts = <int, double>{};

      for (final entry in match.depositAmounts.entries) {
        if (entry.value > 0) {
          ledger[entry.key].mchangoJumla += entry.value;
          depositAmounts[entry.key] = entry.value;
        }
      }

      for (final dep in match.unmatched) {
        if (dep.name.isEmpty && dep.phone.isEmpty) continue;
        final newEntry = LedgerEntry(
          jinaLaKawaida: _titleCase(dep.name),
          jinaLaUsajili: '',
          namba: dep.phone,
          jinsia: 'ME',
          kianzioHali: 'INAHITAJIKA',
          mchangoJumla: dep.amount,
        );
        ledger.add(newEntry);
        depositAmounts[ledger.length - 1] = dep.amount;
      }

      setState(() {
        _ledger = ledger;
        _members = members;
        _depositAmounts = depositAmounts;
        _unmatched = match.unmatched;
        _parsing = false;
      });
      _rebuildSmsRows();
    } catch (e) {
      setState(() {
        _parsing = false;
        _msg = 'Imeshindikana kusoma PDF: $e';
        _msgOk = false;
      });
    }
  }

  String _titleCase(String s) {
    if (s.trim().isEmpty) return s;
    return s.trim().split(' ').map((w) {
      if (w.isEmpty) return w;
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    }).join(' ');
  }

  void _rebuildSmsRows() {
    final state = context.read<AppState>();
    final idadiYaMiezi = state.idadiYaMiezi;

    final overrideMap = <String, String>{};
    for (final m in _members) {
      final override = TextUtils.cleanPhone(m.nambaSms);
      if (override.isEmpty) continue;
      final jk = TextUtils.normName(m.jinaLaKawaida);
      final ju = TextUtils.normName(m.jinaLaUsajili);
      if (jk.isNotEmpty) overrideMap[jk] = override;
      if (ju.isNotEmpty) overrideMap[ju] = override;
    }

    final rows = <_SmsRow>[];
    for (var idx = 0; idx < _ledger.length; idx++) {
      final l = _ledger[idx];
      final jina = l.jinaLaKawaida.isNotEmpty
          ? l.jinaLaKawaida
          : (l.jinaLaUsajili.isNotEmpty ? l.jinaLaUsajili : 'Mwanachama');
      final depositRun = _depositAmounts[idx] ?? 0.0;
      final status = DebtCalculator.computeMemberStatus(
        mchangoJumla: l.mchangoJumla,
        kianzioHali: l.kianzioHali,
        gender: l.jinsia,
        idadiYaMiezi: idadiYaMiezi,
      );
      final smsText = DebtCalculator.buildSmsText(jina, depositRun, idadiYaMiezi, status);
      final smsPhone = overrideMap[TextUtils.normName(jina)] ?? TextUtils.cleanPhone(l.namba);
      if (smsPhone.isNotEmpty) {
        rows.add(_SmsRow(
          ledgerIndex: idx,
          jina: jina,
          phone: TextUtils.formatPhoneForSms(smsPhone),
          message: smsText,
        ));
      }
    }
    setState(() => _smsRows = rows);
  }

  Future<void> _saveLedger() async {
    setState(() {
      _savingLedger = true;
      _msg = null;
    });
    final state = context.read<AppState>();
    final res = await state.repo.saveLedger(
      _ledger,
      'Sasisha ledger baada ya PDF - ${_pdfName ?? ""}',
    );
    setState(() {
      _savingLedger = false;
      _msg = res.message;
      _msgOk = res.ok;
    });
  }

  Future<void> _saveSmsNumbers() async {
    setState(() {
      _savingSmsNumbers = true;
      _msg = null;
    });
    final state = context.read<AppState>();
    final freshRes = await state.repo.fetchMembers();
    if (!freshRes.ok) {
      setState(() {
        _savingSmsNumbers = false;
        _msg = freshRes.message;
        _msgOk = false;
      });
      return;
    }
    final freshMembers = freshRes.data ?? [];
    final savedNames = <String>[];
    final missingNames = <String>[];

    for (final row in _smsRows) {
      final jinaKey = TextUtils.normName(row.jina);
      final newPhone = TextUtils.cleanPhone(row.phone);
      if (newPhone.isEmpty) continue;
      final idx = freshMembers.indexWhere((m) =>
          TextUtils.normName(m.jinaLaKawaida) == jinaKey ||
          TextUtils.normName(m.jinaLaUsajili) == jinaKey);
      if (idx != -1) {
        freshMembers[idx] = freshMembers[idx].copyWith(nambaSms: newPhone);
        savedNames.add(row.jina);
      } else {
        missingNames.add(row.jina);
      }
    }

    if (savedNames.isNotEmpty) {
      final res = await state.repo.saveMembers(freshMembers, 'Sasisha Namba za SMS kutoka Money SMS');
      setState(() {
        _savingSmsNumbers = false;
        _msgOk = res.ok;
        _msg = res.ok
            ? 'Namba za SMS za ${savedNames.length} zimehifadhiwa GitHub.'
                '${missingNames.isNotEmpty ? " ⚠️ Hazipo Backend: ${missingNames.join(', ')}" : ""}'
            : res.message;
      });
    } else {
      setState(() {
        _savingSmsNumbers = false;
        _msg = missingNames.isNotEmpty
            ? '⚠️ Majina hayapo kwenye Backend: ${missingNames.join(', ')}'
            : 'Hakuna namba za kuhifadhi.';
        _msgOk = false;
      });
    }
  }

  Future<void> _sendSmsNow() async {
    final state = context.read<AppState>();
    if (state.user.pushbulletToken.isEmpty) {
      setState(() {
        _msg = 'Huna Pushbullet Token iliyowekwa kwenye wasifu wako.';
        _msgOk = false;
      });
      return;
    }
    if (state.selectedDeviceIden.isEmpty) {
      setState(() {
        _msg = 'Hakuna simu (device) iliyochaguliwa - fungua Wasifu Wangu kuchagua.';
        _msgOk = false;
      });
      return;
    }
    setState(() {
      _sending = true;
      _sendProgress = 0;
      _lastFailures = [];
      _msg = null;
    });

    final items = _smsRows
        .map((r) => SmsSendItem(r.phone, '[ELIAMINI FAMILY]\n${r.message}', r.jina))
        .toList();

    final (successCount, failures) = await PushbulletService.sendSmsBulk(
      items,
      state.selectedDeviceIden,
      state.user.pushbulletToken,
      maxWorkers: state.smsWorkers,
      onProgress: (p) => setState(() => _sendProgress = p),
    );

    setState(() {
      _sending = false;
      _lastFailures = failures;
      _msg = 'SMS $successCount kati ya ${items.length} zimetumwa.';
      _msgOk = failures.isEmpty;
    });
  }

  void _editEntry(int ledgerIndex) async {
    final l = _ledger[ledgerIndex];
    final result = await showDialog<LedgerEntry>(
      context: context,
      builder: (ctx) => _QuickLedgerEditDialog(entry: l),
    );
    if (result != null) {
      setState(() => _ledger[ledgerIndex] = result);
      _rebuildSmsRows();
    }
  }

  void _deleteEntry(int ledgerIndex) {
    setState(() {
      _ledger.removeAt(ledgerIndex);
      _depositAmounts.remove(ledgerIndex);
    });
    _rebuildSmsRows();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('🧮 Money SMS'),
        actions: [
          if (widget.onLogout != null)
            IconButton(icon: const Icon(Icons.logout), onPressed: widget.onLogout),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (_ledger.isNotEmpty) _rebuildSmsRows();
        },
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            Text(
              'Deni la Michango linalotarajiwa = Kiwango cha Mwezi × ${state.idadiYaMiezi} miezi '
              '(badilisha kwenye Wasifu Wangu). Kianzio linahesabiwa kando.',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _parsing ? null : _pickAndParse,
              icon: _parsing
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.upload_file),
              label: Text(_pdfName == null
                  ? 'Pakia Vodacom Statement (PDF)'
                  : 'Badilisha PDF (sasa: $_pdfName)'),
            ),
            if (_msg != null) ...[
              const SizedBox(height: 10),
              _msgBox(_msg!, _msgOk),
            ],
            if (_unmatched.isNotEmpty) ...[
              const SizedBox(height: 10),
              _msgBox(
                '⚠️ Deposit ${_unmatched.length} hazikuoanishwa na mwanachama yeyote aliyepo '
                '(namba haifanani) - zimeongezwa kama WAPYA kwenye Ledger hapa chini kwa ukaguzi.',
                false,
              ),
            ],
            if (_ledger.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text('📋 Ledger — Hariri Kabla ya Kuhifadhi',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              ..._ledger.asMap().entries.map((e) {
                final idx = e.key;
                final l = e.value;
                final jina = l.jinaLaKawaida.isNotEmpty ? l.jinaLaKawaida : l.jinaLaUsajili;
                final deposit = _depositAmounts[idx] ?? 0.0;
                return Card(
                  child: ListTile(
                    title: Text(jina.isEmpty ? '(Bila Jina)' : jina),
                    subtitle: Text(
                      'Mchango Jumla: TZS ${l.mchangoJumla.toStringAsFixed(0)}'
                      '${deposit > 0 ? "  (+${deposit.toStringAsFixed(0)} PDF hii)" : ""}\n'
                      'Namba: ${l.namba}  •  ${l.jinsia}  •  ${l.kianzioHali}',
                    ),
                    isThreeLine: true,
                    onTap: () => _editEntry(idx),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteEntry(idx),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _savingLedger ? null : _saveLedger,
                icon: _savingLedger
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.cloud_upload),
                label: const Text('Hifadhi Ledger na Pandisha GitHub'),
              ),
              const SizedBox(height: 24),
              const Text('📲 SMS Zitakazotumwa',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Text(
                'Namba hapa chini zinaweza kuhaririwa. "Hifadhi Namba za SMS" itazisave '
                'Backend ili Broadcast itumie namba hizohizo.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 8),
              ..._smsRows.asMap().entries.map((e) {
                final i = e.key;
                final row = e.value;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(row.jina, style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        TextFormField(
                          initialValue: row.phone,
                          decoration: const InputDecoration(labelText: 'Namba ya Simu (SMS)', isDense: true),
                          onChanged: (v) => _smsRows[i].phone = v,
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(row.message),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 10),
              if (_smsRows.isEmpty)
                const Text('Hakuna SMS za kutuma kwa sasa.'),
              if (_sending) ...[
                const SizedBox(height: 10),
                LinearProgressIndicator(value: _sendProgress),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _savingSmsNumbers || _smsRows.isEmpty ? null : _saveSmsNumbers,
                      icon: _savingSmsNumbers
                          ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.save),
                      label: const Text('Hifadhi Namba za SMS'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _sending || _smsRows.isEmpty ? null : _sendSmsNow,
                      icon: _sending
                          ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send),
                      label: const Text('Tuma SMS Sasa'),
                    ),
                  ),
                ],
              ),
              if (_lastFailures.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text('❌ Zilizoshindikana:', style: TextStyle(fontWeight: FontWeight.bold)),
                ..._lastFailures.map((f) => Text('${f.jina} (${f.namba}) — ${f.tatizo}')),
              ],
            ] else if (!_parsing) ...[
              const SizedBox(height: 30),
              const Center(child: Text('Tafadhali pakia Vodacom Statement (PDF) kuanza.')),
            ],
          ],
        ),
      ),
    );
  }

  Widget _msgBox(String msg, bool ok) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: ok ? Colors.green.shade50 : Colors.orange.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ok ? Colors.green : Colors.orange),
        ),
        child: Text(msg),
      );
}

class _QuickLedgerEditDialog extends StatefulWidget {
  final LedgerEntry entry;
  const _QuickLedgerEditDialog({required this.entry});

  @override
  State<_QuickLedgerEditDialog> createState() => _QuickLedgerEditDialogState();
}

class _QuickLedgerEditDialogState extends State<_QuickLedgerEditDialog> {
  late final TextEditingController _jina;
  late final TextEditingController _namba;
  late final TextEditingController _mchango;
  late String _jinsia;
  late String _kianzio;

  @override
  void initState() {
    super.initState();
    _jina = TextEditingController(text: widget.entry.jinaLaKawaida);
    _namba = TextEditingController(text: widget.entry.namba);
    _mchango = TextEditingController(text: widget.entry.mchangoJumla.toStringAsFixed(0));
    _jinsia = widget.entry.jinsia.isEmpty ? 'ME' : widget.entry.jinsia;
    _kianzio = widget.entry.kianzioHali.isEmpty ? 'INAHITAJIKA' : widget.entry.kianzioHali;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Hariri Mwanachama'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _jina, decoration: const InputDecoration(labelText: 'Jina la Kawaida')),
            TextField(controller: _namba, decoration: const InputDecoration(labelText: 'Namba ya Simu')),
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
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Ghairi')),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(
              context,
              LedgerEntry(
                jinaLaKawaida: _jina.text,
                jinaLaUsajili: widget.entry.jinaLaUsajili,
                namba: _namba.text,
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
