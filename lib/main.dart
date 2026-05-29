import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme/app_theme.dart';
import 'auth_screen.dart'; 
import 'audio_manager.dart'; // <-- 1. IMPORT THE AUDIO ENGINE

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // <-- 2. IGNITE THE AUDIO ENGINE ON BOOT
  AudioManager().startBgm(); 

  runApp(const VocabApp());
}

class VocabApp extends StatelessWidget {
  const VocabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Vocab Builder',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme, 
      home: const AuthScreen(), 
    );
  }
}