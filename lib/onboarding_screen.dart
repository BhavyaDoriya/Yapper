import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_screen.dart';
import 'auth_screen.dart';
import 'dusty_atmosphere.dart'; // THE PHYSICS ENGINE
import 'tactical_button.dart'; // THE GAME BUTTON
import 'tactical_selector.dart'; // THE GAME HUD SELECTOR

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: $e'), backgroundColor: Colors.redAccent),
        );
      }
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

    return Stack(
      children: [
        const DustyAtmosphere(), // Background physics engine

        Scaffold(
          backgroundColor: Colors.transparent, // Floating on top
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              IconButton(
                icon: Icon(Icons.logout, color: theme.colorScheme.primary.withOpacity(0.5)),
                onPressed: _logout,
                tooltip: "Logout",
              )
            ],
          ),
          body: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: 600, // THE STRAITJACKET
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "CUSTOMIZE YOUR ENGINE",
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4.0,
                          fontSize: 22,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Set your daily parameters to generate your unique vocabulary queue.",
                        style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5), fontSize: 16, letterSpacing: 1.5),
                      ),
                      const SizedBox(height: 60),

                      // Replaced ChoiceChips with Game HUD Selector
                      TacticalSelector(
                        label: 'PRIMARY MODE',
                        options: _categories,
                        currentValue: _selectedCategory,
                        onChanged: (val) => setState(() => _selectedCategory = val),
                      ),
                      
                      const SizedBox(height: 24),

                      // Inline Game Input Row (Matches Settings)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("DAILY WORD GOAL", style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontWeight: FontWeight.w600, letterSpacing: 2.0, fontSize: 12)),
                            SizedBox(
                              width: 160, 
                              child: TextField(
                                controller: _goalController,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 18),
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                  enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24, width: 1)),
                                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: theme.colorScheme.primary, width: 2)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 80),

                      // Custom Hexagon Button
                      TacticalButton(
                        label: "INITIALIZE QUEUE",
                        onTap: _saveSettingsAndProceed,
                        isLoading: _isLoading,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}