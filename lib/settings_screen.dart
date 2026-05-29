import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_screen.dart'; 
import 'tactical_selector.dart'; 
import 'dusty_atmosphere.dart';
import 'tactical_button.dart';
import 'audio_manager.dart'; // REQUIRED FOR SOUNDS
import 'credits_screen.dart'; // REQUIRED FOR NAVIGATION

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _supabase = Supabase.instance.client;
  
  final _apiKeyController = TextEditingController();
  final _goalController = TextEditingController();
  String _selectedProvider = 'Groq (Default)';
  String _activeCategory = "Day-to-day Convo";
  
  bool _isLoading = true;
  bool _isSaving = false;

  final List<String> _providers = ['Groq (Default)', 'OpenAI', 'Custom'];
  final List<String> _categories = ["Day-to-day Convo", "Paleontology", "Software Engineering", "Game Design", "Digital Electronics", "Acoustic Music"];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      final profile = await _supabase.from('profiles').select().eq('id', user.id).maybeSingle();
      if (profile != null) {
        setState(() {
          _goalController.text = (profile['daily_goal'] ?? 10).toString();
          _apiKeyController.text = profile['custom_api_key'] ?? '';
          _activeCategory = profile['active_category'] ?? "Day-to-day Convo";
          _selectedProvider = profile['ai_provider'] ?? 'Groq (Default)'; 
        });
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveSettings() async {
    AudioManager().playThump(); // TRIGGER GEAR SOUND
    setState(() => _isSaving = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        int newGoal = int.tryParse(_goalController.text.trim()) ?? 10;
        await _supabase.from('profiles').update({
          'daily_goal': newGoal,
          'custom_api_key': _apiKeyController.text.trim().isEmpty ? null : _apiKeyController.text.trim(),
          'active_category': _activeCategory,
          'ai_provider': _selectedProvider, 
        }).eq('id', user.id);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CONFIGURATION SECURED')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        bool isTypingMatch = false;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFF111114),
              shape: Border.all(color: Colors.redAccent.withOpacity(0.5), width: 1),
              title: const Text('DELETE ACCOUNT?', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, letterSpacing: 2.0)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('This will permanently erase your memory bank, settings, and authentication record. This cannot be undone.', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                  const SizedBox(height: 20),
                  TextField(
                    onChanged: (val) {
                      setStateDialog(() => isTypingMatch = val.trim() == 'DELETE');
                    },
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, letterSpacing: 2.0),
                    decoration: InputDecoration(
                      hintText: 'Type DELETE to confirm',
                      hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
                      enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.redAccent)),
                      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.redAccent, width: 2)),
                    ),
                  )
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('CANCEL', style: TextStyle(color: Theme.of(context).colorScheme.primary, letterSpacing: 1.5)),
                ),
                TextButton(
                  onPressed: isTypingMatch ? () => Navigator.pop(context, true) : null,
                  child: Text('ERASE', style: TextStyle(color: isTypingMatch ? Colors.redAccent : Colors.redAccent.withOpacity(0.3), fontWeight: FontWeight.bold, letterSpacing: 2.0)),
                ),
              ],
            );
          }
        );
      },
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await _supabase.rpc('delete_user');
      await _supabase.auth.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const AuthScreen()),
          (route) => false, 
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) return Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: theme.colorScheme.primary)));

    return Stack(
      children: [
        const DustyAtmosphere(), 

        Scaffold(
          backgroundColor: Colors.transparent, 
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text('SYSTEM CONFIG'),
          ),
          body: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: 600, 
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("APP PREFERENCES", style: TextStyle(color: theme.colorScheme.primary.withOpacity(0.4), fontWeight: FontWeight.bold, letterSpacing: 3.0, fontSize: 11)),
                      const SizedBox(height: 20),
                      
                      TacticalSelector(
                        label: 'PRIMARY FOCUS',
                        options: _categories,
                        currentValue: _activeCategory,
                        onChanged: (val) => setState(() => _activeCategory = val),
                      ),
                      const SizedBox(height: 8),

                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("DAILY WORD GOAL", style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontWeight: FontWeight.bold, letterSpacing: 2.0, fontSize: 13)),
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
                      const SizedBox(height: 60),

                      Text("AI ENGINE CONFIGURATION", style: TextStyle(color: theme.colorScheme.primary.withOpacity(0.4), fontWeight: FontWeight.bold, letterSpacing: 3.0, fontSize: 11)),
                      const SizedBox(height: 20),

                      TacticalSelector(
                        label: 'AI PROVIDER',
                        options: _providers,
                        currentValue: _selectedProvider,
                        onChanged: (val) => setState(() => _selectedProvider = val),
                      ),
                      const SizedBox(height: 8),

                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("CUSTOM API KEY", style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontWeight: FontWeight.bold, letterSpacing: 2.0, fontSize: 13)),
                            SizedBox(
                              width: 160, 
                              child: TextField(
                                controller: _apiKeyController,
                                obscureText: true,
                                textAlign: TextAlign.center,
                                style: const TextStyle(letterSpacing: 2, fontSize: 18),
                                decoration: InputDecoration(
                                  hintText: 'sk-...',
                                  hintStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.2)),
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
                      
                      const SizedBox(height: 60),

                      TacticalButton(
                        label: "INITIALIZE CHANGES",
                        onTap: _isSaving ? null : _saveSettings,
                        isLoading: _isSaving,
                      ),

                      const SizedBox(height: 60),

                      Text("SYSTEM DATA", style: TextStyle(color: theme.colorScheme.primary.withOpacity(0.4), fontWeight: FontWeight.bold, letterSpacing: 3.0, fontSize: 11)),
                      const SizedBox(height: 20),

                      InkWell(
                        onTap: () {
                          AudioManager().playClick();
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const CreditsScreen()));
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: theme.colorScheme.primary.withOpacity(0.3), width: 1)),
                          ),
                          child: Text("VIEW ENGINE CREDITS", style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.8), letterSpacing: 2.0, fontWeight: FontWeight.bold)),
                        ),
                      ),

                      const SizedBox(height: 60),

                      Text("DANGER ZONE", style: TextStyle(color: Colors.redAccent.withOpacity(0.6), fontWeight: FontWeight.bold, letterSpacing: 3.0, fontSize: 11)),
                      const SizedBox(height: 20),
                      
                      TacticalButton(
                        label: "DELETE ACCOUNT",
                        onTap: _isLoading ? null : _deleteAccount,
                        isDanger: true,
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