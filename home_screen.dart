import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_user.dart';
import '../services/app_state.dart';
import '../services/data_repository.dart';
import 'broadcast_screen.dart';
import 'ledger_screen.dart';
import 'members_screen.dart';
import 'money_sms_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  final AppUser user;
  final DataRepository repo;
  final String resendApiKey;
  final String resendFromEmail;
  final VoidCallback onLoggedOut;

  const HomeScreen({
    super.key,
    required this.user,
    required this.repo,
    required this.resendApiKey,
    required this.resendFromEmail,
    required this.onLoggedOut,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final AppState _appState;

  @override
  void initState() {
    super.initState();
    _appState = AppState(
      user: widget.user,
      repo: widget.repo,
      resendApiKey: widget.resendApiKey,
      resendFromEmail: widget.resendFromEmail,
    );
    _appState.loadDevices();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppState>.value(
      value: _appState,
      child: _HomeScaffold(onLoggedOut: widget.onLoggedOut),
    );
  }
}

class _HomeScaffold extends StatefulWidget {
  final VoidCallback onLoggedOut;
  const _HomeScaffold({required this.onLoggedOut});

  @override
  State<_HomeScaffold> createState() => _HomeScaffoldState();
}

class _HomeScaffoldState extends State<_HomeScaffold> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      MoneySmsScreen(onLogout: widget.onLoggedOut),
      const _LedgerScreenWrapper(),
      const _MembersScreenWrapper(),
      BroadcastScreen(onLogout: widget.onLoggedOut),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.calculate), label: 'Money SMS'),
          NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Ledger'),
          NavigationDestination(icon: Icon(Icons.people), label: 'Wanachama'),
          NavigationDestination(icon: Icon(Icons.campaign), label: 'Tangazo'),
        ],
      ),
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'profile_fab',
        tooltip: 'Wasifu Wangu / Mipangilio',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProfileScreen(onLoggedOut: widget.onLoggedOut)),
        ),
        child: const Icon(Icons.person),
      ),
    );
  }
}

/// Wrapper ndogo zinazopata `repo` kutoka AppState (Provider) badala ya
/// kupitisha prop moja kwa moja, ili LedgerScreen/MembersScreen za awali
/// (Phase 1) ziendelee kufanya kazi bila kubadilishwa.
class _LedgerScreenWrapper extends StatelessWidget {
  const _LedgerScreenWrapper();
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return LedgerScreen(repo: state.repo);
  }
}

class _MembersScreenWrapper extends StatelessWidget {
  const _MembersScreenWrapper();
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return MembersScreen(repo: state.repo);
  }
}
