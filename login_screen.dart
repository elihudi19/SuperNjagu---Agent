import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/data_repository.dart';
import '../services/resend_service.dart';
import '../services/settings_service.dart';

enum _AuthMode { login, register, forgot }

class LoginScreen extends StatefulWidget {
  final DataRepository repo;
  final String sessionSecret;
  final String resendApiKey;
  final String resendFromEmail;
  final void Function(AppUser user) onLoggedIn;
  final VoidCallback onOpenSettings;

  const LoginScreen({
    super.key,
    required this.repo,
    required this.sessionSecret,
    required this.resendApiKey,
    required this.resendFromEmail,
    required this.onLoggedIn,
    required this.onOpenSettings,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  _AuthMode _mode = _AuthMode.login;
  String _selectedName = kAuthorizedNames.first;
  final _pwCtrl = TextEditingController();
  final _pw2Ctrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _pbTokenCtrl = TextEditingController();

  bool _loading = false;
  String? _error;

  // "Nimesahau Password" - hatua (steps)
  int _forgotStep = 1;
  final _forgotEmailCtrl = TextEditingController();
  final _forgotCodeCtrl = TextEditingController();
  final _forgotPw1Ctrl = TextEditingController();
  final _forgotPw2Ctrl = TextEditingController();
  String? _forgotCode;
  DateTime? _forgotExpiry;
  String? _forgotStoredEmail;

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await widget.repo.fetchUsers();
    if (!res.ok) {
      setState(() {
        _loading = false;
        _error = res.message;
      });
      return;
    }
    final users = res.data ?? [];
    final match = users.where((u) => u.jina == _selectedName).toList();
    if (match.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Jina hili halijasajiliwa bado. Tumia "Jisajili Mara ya Kwanza".';
      });
      return;
    }
    final user = match.first;
    final ok = AuthService.verifyPassword(_pwCtrl.text, user.passwordHash, user.salt);
    if (!ok) {
      setState(() {
        _loading = false;
        _error = 'Password si sahihi.';
      });
      return;
    }
    // Hifadhi remember-me token
    final token = AuthService.generateSessionToken(user.jina, widget.sessionSecret);
    await SettingsService.setValue(SettingsService.kSessionUser, user.jina);
    await SettingsService.setValue(SettingsService.kSessionToken, token);
    setState(() => _loading = false);
    widget.onLoggedIn(user);
  }

  Future<void> _register() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    if (!_emailCtrl.text.contains('@')) {
      setState(() {
        _loading = false;
        _error = 'Weka barua pepe sahihi.';
      });
      return;
    }
    if (_pwCtrl.text.length < 6) {
      setState(() {
        _loading = false;
        _error = 'Password iwe angalau herufi/namba 6.';
      });
      return;
    }
    if (_pwCtrl.text != _pw2Ctrl.text) {
      setState(() {
        _loading = false;
        _error = 'Password hazifanani.';
      });
      return;
    }
    if (_pbTokenCtrl.text.trim().isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Weka Pushbullet Token yako.';
      });
      return;
    }

    final usersRes = await widget.repo.fetchUsers();
    if (!usersRes.ok) {
      setState(() {
        _loading = false;
        _error = usersRes.message;
      });
      return;
    }
    final users = usersRes.data ?? [];
    if (users.any((u) => u.jina == _selectedName)) {
      setState(() {
        _loading = false;
        _error = 'Jina hili tayari limesajiliwa. Tumia "Ingia (Login)".';
      });
      return;
    }

    final (hash, salt) = AuthService.hashPassword(_pwCtrl.text);
    final newUser = AppUser(
      jina: _selectedName,
      email: _emailCtrl.text.trim(),
      passwordHash: hash,
      salt: salt,
      pushbulletToken: _pbTokenCtrl.text.trim(),
      pushbulletDevice: '',
    );
    final updated = [...users, newUser];
    final pushRes = await widget.repo.saveUsers(updated, 'Usajili mpya: $_selectedName');
    setState(() => _loading = false);
    if (pushRes.ok) {
      setState(() {
        _mode = _AuthMode.login;
        _error = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Umesajiliwa kikamilifu! Sasa ingia.')),
        );
      }
    } else {
      setState(() => _error = 'Usajili umeshindikana: ${pushRes.message}');
    }
  }

  Future<void> _sendResetCode() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final usersRes = await widget.repo.fetchUsers();
    if (!usersRes.ok) {
      setState(() {
        _loading = false;
        _error = usersRes.message;
      });
      return;
    }
    final users = usersRes.data ?? [];
    final match = users.where((u) => u.jina == _selectedName).toList();
    if (match.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Jina hili halijasajiliwa bado.';
      });
      return;
    }
    _forgotStoredEmail = match.first.email;
    if (_forgotEmailCtrl.text.trim().toLowerCase() != (_forgotStoredEmail ?? '').trim().toLowerCase()) {
      setState(() {
        _loading = false;
        _error = 'Barua pepe hailingani na iliyosajiliwa.';
      });
      return;
    }
    if (widget.resendApiKey.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'RESEND_API_KEY haijawekwa kwenye Mipangilio - muulize admin aweke ili '
            'nambari ya kurejesha itumwe barua pepe.';
      });
      return;
    }
    final code = AuthService.randomSixDigitCode();
    final (ok, info) = await ResendService.sendEmailCode(
      apiKey: widget.resendApiKey,
      fromEmail: widget.resendFromEmail,
      toEmail: _forgotStoredEmail!,
      code: code,
    );
    setState(() {
      _loading = false;
      if (ok) {
        _forgotCode = code;
        _forgotExpiry = DateTime.now().add(const Duration(minutes: 10));
        _forgotStep = 2;
      } else {
        _error = info;
      }
    });
  }

  Future<void> _confirmReset() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    if (_forgotExpiry == null || DateTime.now().isAfter(_forgotExpiry!)) {
      setState(() {
        _loading = false;
        _error = 'Muda wa nambari umeisha. Anza tena.';
        _forgotStep = 1;
      });
      return;
    }
    if (_forgotCodeCtrl.text.trim() != _forgotCode) {
      setState(() {
        _loading = false;
        _error = 'Nambari si sahihi.';
      });
      return;
    }
    if (_forgotPw1Ctrl.text.length < 6 || _forgotPw1Ctrl.text != _forgotPw2Ctrl.text) {
      setState(() {
        _loading = false;
        _error = 'Password hazifanani au ni fupi mno (angalau herufi 6).';
      });
      return;
    }
    final usersRes = await widget.repo.fetchUsers();
    if (!usersRes.ok) {
      setState(() {
        _loading = false;
        _error = usersRes.message;
      });
      return;
    }
    final users = usersRes.data ?? [];
    final idx = users.indexWhere((u) => u.jina == _selectedName);
    if (idx == -1) {
      setState(() {
        _loading = false;
        _error = 'Jina hili halijasajiliwa bado.';
      });
      return;
    }
    final (hash, salt) = AuthService.hashPassword(_forgotPw1Ctrl.text);
    users[idx] = AppUser(
      jina: users[idx].jina,
      email: users[idx].email,
      passwordHash: hash,
      salt: salt,
      pushbulletToken: users[idx].pushbulletToken,
      pushbulletDevice: users[idx].pushbulletDevice,
    );
    final pushRes = await widget.repo.saveUsers(users, 'Reset password: $_selectedName');
    setState(() {
      _loading = false;
      _forgotStep = 1;
    });
    if (pushRes.ok) {
      setState(() {
        _mode = _AuthMode.login;
        _error = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password imebadilishwa. Sasa ingia.')),
        );
      }
    } else {
      setState(() => _error = 'Imebadilishwa lakini imeshindikana kupandisha GitHub: ${pushRes.message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ELIAMINI FAMILY'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: widget.onOpenSettings,
            tooltip: 'Mipangilio ya GitHub',
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.account_balance_wallet, size: 56, color: Colors.deepPurple),
                const SizedBox(height: 8),
                const Text(
                  'Mfumo wa M-Koba',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Text(
                  'Ni Viongozi watatu pekee wanaoruhusiwa.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 20),
                SegmentedButton<_AuthMode>(
                  segments: const [
                    ButtonSegment(value: _AuthMode.login, label: Text('Ingia')),
                    ButtonSegment(value: _AuthMode.register, label: Text('Jisajili')),
                    ButtonSegment(value: _AuthMode.forgot, label: Text('Nimesahau')),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (s) => setState(() {
                    _mode = s.first;
                    _error = null;
                    _forgotStep = 1;
                  }),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: _selectedName,
                  decoration: const InputDecoration(labelText: 'Jina Lako', border: OutlineInputBorder()),
                  items: kAuthorizedNames
                      .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedName = v ?? _selectedName),
                ),
                const SizedBox(height: 12),
                if (_mode == _AuthMode.register) ...[
                  TextField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(labelText: 'Barua Pepe Yako', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_mode == _AuthMode.login || _mode == _AuthMode.register) ...[
                  TextField(
                    controller: _pwCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                  ),
                ],
                if (_mode == _AuthMode.register) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pw2Ctrl,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Rudia Password', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pbTokenCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Pushbullet Access Token Yako',
                      helperText: 'Pata kwenye pushbullet.com/#settings/account',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                if (_mode == _AuthMode.forgot && _forgotStep == 1) ...[
                  TextField(
                    controller: _forgotEmailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Thibitisha Barua Pepe Uliyojisajili Nayo',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                if (_mode == _AuthMode.forgot && _forgotStep == 2) ...[
                  Text(
                    'Nambari imetumwa kwenye barua pepe ya $_selectedName. Ina muda wa dakika 10.',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _forgotCodeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Weka Nambari Uliyopokea Barua Pepe',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _forgotPw1Ctrl,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password Mpya', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _forgotPw2Ctrl,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Rudia Password Mpya', border: OutlineInputBorder()),
                  ),
                ],
                const SizedBox(height: 20),
                if (_error != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red),
                    ),
                    child: Text(_error!, style: const TextStyle(color: Colors.red)),
                  ),
                if (_mode == _AuthMode.forgot) ...[
                  ElevatedButton(
                    onPressed: _loading
                        ? null
                        : () => _forgotStep == 1 ? _sendResetCode() : _confirmReset(),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: _loading
                        ? const SizedBox(
                            height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_forgotStep == 1 ? 'Tuma Nambari ya Kurejesha' : 'Rejesha Password'),
                  ),
                  if (_forgotStep == 2) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _loading ? null : () => setState(() => _forgotStep = 1),
                      child: const Text('Ghairi'),
                    ),
                  ],
                ] else
                  ElevatedButton(
                    onPressed: _loading
                        ? null
                        : () => _mode == _AuthMode.login ? _login() : _register(),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: _loading
                        ? const SizedBox(
                            height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_mode == _AuthMode.login ? 'Ingia' : 'Jisajili'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
