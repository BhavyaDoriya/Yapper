import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_screen.dart';
import 'study_screen.dart'; // Imports your new engine
import 'settings_screen.dart';
import 'test_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _supabase = Supabase.instance.client;
  
  String activeCategory = "Day-to-day Convo";
  int dailyGoal = 10;
  int wordsClearedToday = 0;
  int remainingWords = 10;
  bool isLoading = true;
  bool isFinishedToday = false;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final profile = await _supabase.from('profiles').select().eq('id', user.id).maybeSingle();
        if (profile != null) {
          
          String today = DateTime.now().toIso8601String().split('T')[0];
          
          setState(() {
            activeCategory = profile['active_category'] ?? "Day-to-day Convo";
            dailyGoal = profile['daily_goal'] ?? 10;
            
            // If it's a brand new day, reset the tracker to 0
            if (profile['last_completed_date'] != today) {
              wordsClearedToday = 0;
              // Silently reset the database in the background
              _supabase.from('profiles').update({
                'words_cleared_today': 0, 
                'last_completed_date': today
              }).eq('id', user.id);
            } else {
              wordsClearedToday = profile['words_cleared_today'] ?? 0;
            }

            // Calculate exact remaining words based on goal changes
            remainingWords = dailyGoal - wordsClearedToday;
            if (remainingWords <= 0) {
              remainingWords = 0;
              isFinishedToday = true;
            } else {
              isFinishedToday = false;
            }
          });
        }
      }
    } catch (e) {
      print("Dashboard fetch error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _logout() async {
    await _supabase.auth.signOut();
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AuthScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('DASHBOARD', style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold)),
        actions: [IconButton(onPressed: _logout, icon: Icon(Icons.logout, color: theme.colorScheme.primary))],
      ),
      body: isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header text removed for a cleaner look
                  
                  Card(
                    color: theme.colorScheme.surface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.3))),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Icon(Icons.psychology, size: 40, color: Colors.amber), 
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                                child: Text("Goal: $dailyGoal words", style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                              )
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(activeCategory.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 16)),
                          const SizedBox(height: 8),
                          Text(
                            isFinishedToday ? "You have reached your daily parameters." : "Your daily batch is ready for extraction.", 
                            style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6))
                          ),
                          const SizedBox(height: 24),
                          
                          // THE SMART BUTTON
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: isFinishedToday ? null : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => StudyScreen(
                                    batchSize: remainingWords, 
                                    wordsAlreadyCleared: wordsClearedToday,
                                    activeCategory: activeCategory
                                  )),
                                ).then((_) {
                                  setState(() => isLoading = true);
                                  _loadDashboardData(); 
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isFinishedToday ? theme.colorScheme.surface : theme.colorScheme.primary,
                                foregroundColor: theme.colorScheme.onPrimary,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              ),
                              child: Text(
                                isFinishedToday ? "QUEUE COMPLETED" : "INITIALIZE ($remainingWords LEFT)", 
                                style: TextStyle(
                                  fontWeight: FontWeight.bold, 
                                  letterSpacing: 1.5,
                                  color: isFinishedToday ? theme.colorScheme.primary : theme.colorScheme.onPrimary
                                )
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: theme.colorScheme.surface,
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: theme.colorScheme.onSurface.withOpacity(0.5),
        currentIndex: 0, 
        onTap: (index) {
          if (index == 1) {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const TestScreen()));
          } else if (index == 2) {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen())).then((_) {
              setState(() => isLoading = true);
              _loadDashboardData(); 
            });
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Hub'),
          BottomNavigationBarItem(icon: Icon(Icons.military_tech), label: 'Test Arena'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}