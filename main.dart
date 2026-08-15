import 'package:flutter/material.dart';
import 'models/app_user.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/settings_screen.dart';
import 'services/auth_service.dart';
import 'services/data_repository.dart';
import 'services/github_service.dart';
import 'services/settings_service.dart';

void main() {
  runApp(const EliaminiFamilyApp());
}

class EliaminiFamilyApp extends StatelessWidget {
  const EliaminiFamilyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ELIAMINI FAMILY',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const _RootGate(),
    );
  }
}

/// Huamua ni skrini gani ionekane kwanza: Settings (kama hakuna GITHUB_TOKEN),
/// Login (kama hakuna session halali), au Home (kama session ipo/ni halali) —
/// sawa na mantiki ya remember-me (query params) kwenye Streamlit.
class _RootGate extends StatefulWidget {
  const _RootGate();

  @override
  State<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<_RootGate> {
  bool _loading = true;
  bool _needsSettings = false;
  AppUser? _user;
  DataRepository? _repo;
  String _sessionSecret = '';
  String _resendApiKey = '';
  String _resendFromEmail = '';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final cfg = await SettingsService.loadGithubConfig();
    if ((cfg['token'] ?? '').isEmpty || (cfg['repo'] ?? '').isEmpty) {
      setState(() {
        _needsSettings = true;
        _loading = false;
      });
      return;
    }

    final github = GithubService(token: cfg['token']!, repo: cfg['repo']!, branch: cfg['branch']!);
    final repo = DataRepository(
      github: github,
      membersPath: cfg['membersPath']!,
      ledgerPath: cfg['ledgerPath']!,
      usersPath: cfg['usersPath']!,
    );
    _sessionSecret = cfg['sessionSecret']!;
    _resendApiKey = cfg['resendApiKey'] ?? '';
    _resendFromEmail = cfg['resendFromEmail'] ?? '';

    // Angalia remember-me token iliyohifadhiwa kwa usalama kwenye simu.
    final sessionUser = await SettingsService.getValue(SettingsService.kSessionUser);
    final sessionToken = await SettingsService.getValue(SettingsService.kSessionToken);

    AppUser? restoredUser;
    if (sessionUser.isNotEmpty &&
        kAuthorizedNames.contains(sessionUser) &&
        AuthService.verifySessionToken(sessionUser, sessionToken, _sessionSecret)) {
      final usersRes = await repo.fetchUsers();
      if (usersRes.ok) {
        final match = (usersRes.data ?? []).where((u) => u.jina == sessionUser).toList();
        if (match.isNotEmpty) restoredUser = match.first;
      }
    }

    setState(() {
      _repo = repo;
      _user = restoredUser;
      _needsSettings = false;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_needsSettings) {
      return SettingsScreen(onSaved: () {
        setState(() => _loading = true);
        _bootstrap();
      });
    }

    if (_user != null && _repo != null) {
      return HomeScreen(
        user: _user!,
        repo: _repo!,
        resendApiKey: _resendApiKey,
        resendFromEmail: _resendFromEmail,
        onLoggedOut: () => setState(() => _user = null),
      );
    }

    return LoginScreen(
      repo: _repo!,
      sessionSecret: _sessionSecret,
      resendApiKey: _resendApiKey,
      resendFromEmail: _resendFromEmail,
      onLoggedIn: (user) => setState(() => _user = user),
      onOpenSettings: () => setState(() => _needsSettings = true),
    );
  }
}
