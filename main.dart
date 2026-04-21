import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/auth_screen.dart';
import 'screens/chat_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://lncynkqvleklvcldeoua.supabase.co',
    anonKey: 'sb_publishable_4VmtlKMkfzPCzSH1nlS9Bw_qEREwDCh',
  );
  runApp(const OnyxIXApp());
}

final supabase = Supabase.instance.client;

class OnyxIXApp extends StatelessWidget {
  const OnyxIXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ONYX IX',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    supabase.auth.onAuthStateChange.listen((data) {
      if (!mounted) return;
      final event = data.event;
      if (event == AuthChangeEvent.signedIn) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ChatScreen()),
        );
      } else if (event == AuthChangeEvent.signedOut) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AuthScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = supabase.auth.currentSession;
    if (session != null) return const ChatScreen();
    return const AuthScreen();
  }
}
