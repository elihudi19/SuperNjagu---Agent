import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_user.dart';
import '../services/app_state.dart';
import '../services/github_service.dart';
import '../services/pushbullet_service.dart';
import '../services/settings_service.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback? onLoggedOut;
  const ProfileScreen({super.key, this.onLoggedOut});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _tokenCtrl = TextEditingController();
  bool _savingToken = false;
  String? _tokenMsg;
  bool _tokenOk = false;

  bool _testingPb = false;
  String? _pbMsg;
  bool _pbOk = false;

  bool _testingGh = false;
  String? _ghMsg;
  bool _ghOk = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _tokenCtrl.text = state.user.pushbulletToken;
    if (state.devices.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => state.loadDevices());
    }
  }

  Future<void> _saveToken(AppState state) async {
    if (_tokenCtrl.text.trim().isEmpty) {
      setState(() {
        _tokenMsg = 'Weka token kwanza.';
        _tokenOk = false;
      });
      return;
    }
    setState(() {
      _savingToken = true;
      _tokenMsg = null;
    });
    final usersRes = await state.repo.fetchUsers();
    if (!usersRes.ok) {
      setState(() {
        _savingToken = false;
        _tokenMsg = usersRes.message;
        _tokenOk = false;
      });
      return;
    }
    final users = usersRes.data ?? [];
    final idx = users.indexWhere((u) => u.jina == state.user.jina);
    if (idx == -1) {
      setState(() {
        _savingToken = false;
        _tokenMsg = 'Wasifu wako haukupatikana kwenye users.csv.';
        _tokenOk = false;
      });
      return;
    }
    final updatedUser = AppUser(
      jina: users[idx].jina,
      email: users[idx].email,
      passwordHash: users[idx].passwordHash,
      salt: users[idx].salt,
      pushbulletToken: _tokenCtrl.text.trim(),
      pushbulletDevice: users[idx].pushbulletDevice,
    );
    users[idx] = updatedUser;
    final pushRes = await state.repo.saveUsers(users, 'Sasisha token: ${state.user.jina}');
    setState(() {
      _savingToken = false;
      _tokenMsg = pushRes.message;
      _tokenOk = pushRes.ok;
    });
    if (pushRes.ok) {
      state.updateUser(updatedUser);
      await state.loadDevices();
    }
  }

  Future<void> _testPushbullet(AppState state) async {
    setState(() {
      _testingPb = true;
      _pbMsg = null;
    });
    final (ok, info) = await PushbulletService.testConnection(state.user.pushbulletToken);
    setState(() {
      _testingPb = false;
      _pbMsg = info;
      _pbOk = ok;
    });
  }

  Future<void> _testGithub(AppState state) async {
    setState(() {
      _testingGh = true;
      _ghMsg = null;
    });
    final res = await (state.repo.github as GithubService).testConnection();
    setState(() {
      _testingGh = false;
      _ghMsg = res.message;
      _ghOk = res.ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('👤 Wasifu Wangu / Mipangilio'),
        actions: [
          if (widget.onLoggedOut != null)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Toka (Logout)',
              onPressed: () async {
                await SettingsService.clearSession();
                if (context.mounted) Navigator.pop(context);
                widget.onLoggedOut?.call();
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Umeingia kama: ${state.user.jina}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Text('Barua pepe: ${state.user.email}', style: const TextStyle(color: Colors.grey)),
          const Divider(height: 32),

          const Text('⚙️ Pushbullet Token Yangu', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _tokenCtrl,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Pushbullet Access Token',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          if (_tokenMsg != null)
            _msgBox(_tokenMsg!, _tokenOk),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _savingToken ? null : () => _saveToken(state),
                  child: _savingToken
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('💾 Hifadhi Token Mpya'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _testingPb ? null : () => _testPushbullet(state),
                  child: _testingPb
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('🔎 Pima Muunganiko'),
                ),
              ),
            ],
          ),
          if (_pbMsg != null) ...[const SizedBox(height: 8), _msgBox(_pbMsg!, _pbOk)],

          const Divider(height: 32),
          const Text('📱 Simu ya Kutuma SMS', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (state.loadingDevices)
            const Center(child: CircularProgressIndicator())
          else if (state.smsCapableDevices.isEmpty)
            const Text('Hakuna simu yenye uwezo wa SMS iliyounganishwa kwenye Pushbullet yako.',
                style: TextStyle(color: Colors.orange))
          else
            DropdownButtonFormField<String>(
              value: state.smsCapableDevices.any((d) => d.iden == state.selectedDeviceIden)
                  ? state.selectedDeviceIden
                  : state.smsCapableDevices.first.iden,
              decoration: const InputDecoration(labelText: 'Chagua Simu', border: OutlineInputBorder()),
              items: state.smsCapableDevices
                  .map((d) => DropdownMenuItem(value: d.iden, child: Text(d.nickname)))
                  .toList(),
              onChanged: (v) => state.setSelectedDevice(v ?? ''),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => state.loadDevices(),
            icon: const Icon(Icons.refresh),
            label: const Text('Sasisha Orodha ya Simu'),
          ),

          const Divider(height: 32),
          const Text('⚡ Kasi ya Kutuma SMS (sambamba)', style: TextStyle(fontWeight: FontWeight.bold)),
          Slider(
            value: state.smsWorkers.toDouble(),
            min: 5,
            max: 50,
            divisions: 9,
            label: '${state.smsWorkers}',
            onChanged: (v) => state.setSmsWorkers(v.round()),
          ),

          const Divider(height: 32),
          const Text('🧮 Idadi ya Miezi Yanayokokotolewa', style: TextStyle(fontWeight: FontWeight.bold)),
          Slider(
            value: state.idadiYaMiezi.toDouble(),
            min: 1,
            max: 24,
            divisions: 23,
            label: '${state.idadiYaMiezi}',
            onChanged: (v) => state.setIdadiYaMiezi(v.round()),
          ),
          const Text(
            'ME = TZS 5,000/mwezi, KE = TZS 2,500/mwezi. Kianzio (TZS 18,000) '
            'linahesabiwa kando na kujumlishwa JUMLA DENI.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),

          const Divider(height: 32),
          const Text('🔎 Utambuzi wa GitHub', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _testingGh ? null : () => _testGithub(state),
            child: _testingGh
                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Angalia Muunganiko wa GitHub'),
          ),
          if (_ghMsg != null) ...[const SizedBox(height: 8), _msgBox(_ghMsg!, _ghOk)],
        ],
      ),
    );
  }

  Widget _msgBox(String msg, bool ok) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: ok ? Colors.green.shade50 : Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ok ? Colors.green : Colors.red),
        ),
        child: Text(msg),
      );
}
