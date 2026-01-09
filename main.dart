import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'features/reading/verse_play_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'bible_love',
      theme: ThemeData(useMaterial3: true),
      home: const _AuthBootstrapper(),
      routes: {
        VersePlayPage.routeName: (_) => const VersePlayPage(),
      },
    );
  }
}

class _AuthBootstrapper extends StatefulWidget {
  const _AuthBootstrapper();

  @override
  State<_AuthBootstrapper> createState() => _AuthBootstrapperState();
}

class _AuthBootstrapperState extends State<_AuthBootstrapper> {
  late Future<void> _init;

  @override
  void initState() {
    super.initState();
    _init = _bootstrap();
  }

  Future<void> _bootstrap() async {
    await AuthService.instance.ensureAnonymousSignIn();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _init,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Auth failed'),
                    const SizedBox(height: 8),
                    Text('${snap.error}'),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => setState(() => _init = _bootstrap()),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return const VersePlayPage();
      },
    );
  }
}
