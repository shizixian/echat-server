import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/chat_provider.dart';
import 'services/storage_service.dart';
import 'screens/login_screen.dart';
import 'screens/chat_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services
  final storage = StorageService();
  await storage.init();

  runApp(const EChatApp());
}

class EChatApp extends StatelessWidget {
  const EChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: MaterialApp(
        title: 'EChat',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          primaryColor: Colors.cyan,
          scaffoldBackgroundColor: const Color(0xFF0D0D2B),
          colorScheme: ColorScheme.dark(
            primary: Colors.cyan.shade600,
            secondary: Colors.purple.shade400,
            surface: const Color(0xFF1A1A3E),
          ),
          useMaterial3: true,
        ),
        home: const SplashScreen(),
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;

    final provider = context.read<ChatProvider>();
    await provider.init();

    if (!mounted) return;

    if (provider.isAuthenticated) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ChatListScreen()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0D0D2B),
              Color(0xFF1A1A3E),
              Color(0xFF16213E),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Colors.cyan.shade400, Colors.purple.shade500],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.cyan.shade400.withValues(alpha: 0.3),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(Icons.lock_outline, size: 48, color: Colors.white),
              ),
              const SizedBox(height: 32),
              Text(
                'EChat',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: Colors.cyan.shade300,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Secure. Private. Encrypted.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.5),
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 48),
              const CircularProgressIndicator(color: Colors.cyan),
            ],
          ),
        ),
      ),
    );
  }
}
