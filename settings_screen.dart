import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../services/github_service.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback onSaved;
  const SettingsScreen({super.key, required this.onSaved});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _tokenCtrl = TextEditingController();
  final _repoCtrl = TextEditingController();
  final _branchCtrl = TextEditingController(text: 'main');
  final _resendKeyCtrl = TextEditingController();
  final _resendFromCtrl = TextEditingController();
  bool _loading = false;
  String? _statusMsg;
  bool _statusOk = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cfg = await SettingsService.loadGithubConfig();
    _tokenCtrl.text = cfg['token'] ?? '';
    _repoCtrl.text = cfg['repo'] ?? '';
    _branchCtrl.text = cfg['branch'] ?? 'main';
    _resendKeyCtrl.text = cfg['resendApiKey'] ?? '';
    _resendFromCtrl.text = cfg['resendFromEmail'] ?? '';
    setState(() {});
  }

  Future<void> _testAndSave() async {
    setState(() {
      _loading = true;
      _statusMsg = null;
    });
    final gh = GithubService(
      token: _tokenCtrl.text.trim(),
      repo: _repoCtrl.text.trim(),
      branch: _branchCtrl.text.trim().isEmpty ? 'main' : _branchCtrl.text.trim(),
    );
    final res = await gh.testConnection();
    if (res.ok) {
      await SettingsService.setValue(SettingsService.kGithubToken, _tokenCtrl.text.trim());
      await SettingsService.setValue(SettingsService.kGithubRepo, _repoCtrl.text.trim());
      await SettingsService.setValue(SettingsService.kGithubBranch,
          _branchCtrl.text.trim().isEmpty ? 'main' : _branchCtrl.text.trim());
      await SettingsService.setValue(SettingsService.kResendApiKey, _resendKeyCtrl.text.trim());
      await SettingsService.setValue(
        SettingsService.kResendFromEmail,
        _resendFromCtrl.text.trim().isEmpty
            ? 'ELIAMINI FAMILY <onboarding@resend.dev>'
            : _resendFromCtrl.text.trim(),
      );
    }
    setState(() {
      _loading = false;
      _statusMsg = res.message;
      _statusOk = res.ok;
    });
    if (res.ok) {
      widget.onSaved();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mipangilio ya GitHub')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'ELIAMINI FAMILY inahifadhi data (wanachama, ledger, users) kwenye '
                'GitHub. Weka taarifa za repo yako ya GITHUB HAPA CHINI. Repo lazima '
                'iwe PRIVATE kwa sababu itahifadhi taarifa nyeti.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _tokenCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'GitHub Personal Access Token',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _repoCtrl,
                decoration: const InputDecoration(
                  labelText: 'GitHub Repo (mfano: jina/jina-la-repo)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _branchCtrl,
                decoration: const InputDecoration(
                  labelText: 'Branch (default: main)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Resend (hiari - kwa "Nimesahau Password" pekee)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Text(
                'Kama huna akaunti ya Resend (resend.com), acha wazi - "Nimesahau Password" '
                'haitafanya kazi lakini kila kitu kingine kitafanya kazi kawaida.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _resendKeyCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'RESEND_API_KEY (hiari)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _resendFromCtrl,
                decoration: const InputDecoration(
                  labelText: 'RESEND_FROM_EMAIL (hiari)',
                  hintText: 'ELIAMINI FAMILY <onboarding@resend.dev>',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              if (_statusMsg != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _statusOk ? Colors.green.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _statusOk ? Colors.green : Colors.red),
                  ),
                  child: Text(_statusMsg!),
                ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loading ? null : _testAndSave,
                child: _loading
                    ? const SizedBox(
                        height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Pima Muunganiko na Hifadhi'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
