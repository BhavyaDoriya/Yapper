import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_screen.dart'; // Required for kicking the user out after deletion

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
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings updated successfully')));
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

  // --- THE ERASURE PROTOCOL ---
  Future<void> _deleteAccount() async {
    // 1. Strict Confirmation Check
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        bool isTypingMatch = false;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: Colors.redAccent),
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'DELETE ACCOUNT?', 
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, letterSpacing: 1.5)
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This will permanently erase your memory bank, settings, and authentication record. This cannot be undone.', 
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface)
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    onChanged: (val) {
                      setStateDialog(() => isTypingMatch = val.trim() == 'DELETE');
                    },
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: 'Type DELETE to confirm',
                      hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.redAccent.withOpacity(0.3))),
                      focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.redAccent)),
                    ),
                  )
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('CANCEL', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                ),
                ElevatedButton(
                  onPressed: isTypingMatch ? () => Navigator.pop(context, true) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.redAccent.withOpacity(0.3),
                  ),
                  child: const Text('ERASE', style: TextStyle(fontWeight: FontWeight.bold)),
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
      // 2. Trigger Backend Deletion
      await _supabase.rpc('delete_user');
      
      // 3. Clear Local Session
      await _supabase.auth.signOut();

      // 4. Force App Reroute
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const AuthScreen()),
          (route) => false, // Annihilates the entire navigation history stack
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

    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('SETTINGS', style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- APP PREFERENCES ---
              Text("APP PREFERENCES", style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 12)),
              const SizedBox(height: 16),
              
              DropdownButtonFormField<String>(
                value: _activeCategory,
                decoration: InputDecoration(
                  labelText: 'Primary Focus',
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                ),
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (val) => setState(() => _activeCategory = val!),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _goalController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Daily Word Goal',
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
              const SizedBox(height: 40),

              // --- AI ENGINE CONFIGURATION ---
              Text("AI ENGINE CONFIGURATION", style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 12)),
              const SizedBox(height: 8),
              Text("Bring your own API key to bypass default limits.", style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 12)),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _selectedProvider,
                decoration: InputDecoration(
                  labelText: 'AI Provider',
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                ),
                items: _providers.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                onChanged: (val) => setState(() => _selectedProvider = val!),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _apiKeyController,
                obscureText: true, 
                decoration: InputDecoration(
                  labelText: 'Custom API Key',
                  hintText: 'sk-...',
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
              
              const SizedBox(height: 40),

              // --- SAVE BUTTON ---
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveSettings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: _isSaving
                      ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.onPrimary))
                      : Text("SAVE CONFIGURATION", style: TextStyle(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                ),
              ),

              const SizedBox(height: 50),

              // --- DANGER ZONE ---
              const Divider(color: Colors.white24),
              const SizedBox(height: 20),
              const Text("DANGER ZONE", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 12)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isLoading ? null : _deleteAccount,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: const Text("DELETE ACCOUNT", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}