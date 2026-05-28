import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_screen.dart';
import 'auth_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  String _selectedCategory = "Day-to-day Convo";
  final TextEditingController _goalController = TextEditingController(text: "10");
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;

  final List<String> _categories = [
    "Day-to-day Convo",
    "Paleontology",
    "Software Engineering",
    "Game Design",
    "Digital Electronics",
    "Acoustic Music",
  ];

  @override
  void dispose() {
    _goalController.dispose();
    super.dispose();
  }

  Future<void> _saveSettingsAndProceed() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception("No user logged in.");

      // Clean up the user's input to ensure it's a valid number
      int dailyGoal = int.tryParse(_goalController.text.trim()) ?? 10;
      if (dailyGoal < 1) dailyGoal = 10; // Fallback if they type nonsense

      // Upsert (Update or Insert) the profile into Supabase
      await _supabase.from('profiles').upsert({
        'id': user.id,
        'active_category': _selectedCategory,
        'daily_goal': dailyGoal,
      });

      // Blast them to the Home Screen once saved
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving profile: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    await _supabase.auth.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AuthScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: theme.colorScheme.primary),
            onPressed: _logout,
            tooltip: "Logout",
          )
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Customize Your Engine",
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Set your daily parameters to generate your unique vocabulary queue.",
                style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7), fontSize: 16),
              ),
              const SizedBox(height: 40),

              Text(
                "SELECT PRIMARY MODE",
                style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1.5),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12.0,
                runSpacing: 12.0,
                children: _categories.map((category) {
                  final isSelected = _selectedCategory == category;
                  return ChoiceChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedCategory = category);
                    },
                    backgroundColor: theme.colorScheme.surface,
                    selectedColor: theme.colorScheme.primary.withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    side: BorderSide(
                      color: isSelected ? theme.colorScheme.primary : theme.colorScheme.primary.withOpacity(0.3),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 40),

              Text(
                "DAILY WORD GOAL",
                style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1.5),
              ),
              const SizedBox(height: 10),
              
              // New Mobile-Friendly Text Input
              SizedBox(
                width: 150,
                child: TextField(
                  controller: _goalController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: theme.colorScheme.primary, fontSize: 20, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    suffixText: "words",
                    suffixStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5), fontSize: 14),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: theme.colorScheme.primary.withOpacity(0.3))),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: theme.colorScheme.primary)),
                  ),
                ),
              ),

              const SizedBox(height: 60),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveSettingsAndProceed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: _isLoading 
                    ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: theme.colorScheme.onPrimary, strokeWidth: 2))
                    : const Text("INITIALIZE QUEUE", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}