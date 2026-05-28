import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'onboarding_screen.dart';
import "home_screen.dart";
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _supabase = Supabase.instance.client;
  
  bool _isLoading = false;
  bool _isSignUp = false;

  @override
  void initState() {
    super.initState();
    
    // Listen for auth events and intelligently route the user
    _supabase.auth.onAuthStateChange.listen((data) async {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;
      
      if ((event == AuthChangeEvent.signedIn || event == AuthChangeEvent.initialSession) && session != null) {
        // 1. Check if the user already has a configured profile
        try {
          final profile = await _supabase.from('profiles').select('active_category').eq('id', session.user.id).maybeSingle();
          
          if (mounted) {
            // If they have an active category, they've done onboarding before. Go to Dashboard.
            if (profile != null && profile['active_category'] != null) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const HomeScreen()),
              );
            } else {
              // Brand new user! Send to Onboarding.
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const OnboardingScreen()),
              );
            }
          }
        } catch (e) {
          // Fallback to onboarding if the check fails
          if (mounted) {
            Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const OnboardingScreen()));
          }
        }
      }
    });
  }
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

Future<void> _emailAuth() async {
    setState(() => _isLoading = true);
    try {
      if (_isSignUp) {
        // Registering a new account with Email Confirmation ON
        await _supabase.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          emailRedirectTo: 'vocabapp://callback', // <-- ADD THIS EXACT LINE
        );
        
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false, // Forces them to click the button
            builder: (context) => AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
              ),
              title: Text(
                'VERIFY YOUR IDENTITY', 
                style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, letterSpacing: 1.5)
              ),
              content: Text(
                'We just sent a secure link to ${_emailController.text.trim()}.\n\nPlease click the link in that email to initialize your instance.',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog
                    setState(() {
                      _isSignUp = false;
                      _passwordController.clear();
                    });
                  },
                  child: Text('UNDERSTOOD', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }
      } else {
        // Logging in with existing, confirmed account
        await _supabase.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }
    } on AuthException catch (e) {
      String errorMessage = e.message;
      if (e.message.contains('Invalid login credentials')) {
        errorMessage = 'Invalid credentials, or email not verified yet. Please check your inbox!';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      // Catch the Phantom "Failed to fetch" error
      if (e.toString().contains('Failed to fetch')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Connecting to memory bank...'), 
              backgroundColor: Theme.of(context).colorScheme.primary, 
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('An unexpected network error occurred.'), backgroundColor: Colors.redAccent),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
 Future<void> _googleSignIn() async {
    try {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'vocabapp://callback', // <-- CHANGED THIS LINE
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to launch Google Sign-In'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'DAILY VOCAB',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _isSignUp ? 'Initialize your database' : 'Access your memory bank',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6)),
                ),
                const SizedBox(height: 40),

                // Email Input
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  decoration: InputDecoration(
                    labelText: 'Email',
                    labelStyle: TextStyle(color: theme.colorScheme.primary.withOpacity(0.7)),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: theme.colorScheme.primary.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: theme.colorScheme.primary),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surface,
                  ),
                ),
                const SizedBox(height: 20),

                // Password Input
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: TextStyle(color: theme.colorScheme.primary.withOpacity(0.7)),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: theme.colorScheme.primary.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: theme.colorScheme.primary),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surface,
                  ),
                ),
                const SizedBox(height: 30),

                // Email Login/Signup Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _emailAuth,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: _isLoading
                      ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: theme.colorScheme.onPrimary, strokeWidth: 2))
                      : Text(
                          _isSignUp ? 'REGISTER ENGINE' : 'ENGAGE',
                          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2),
                        ),
                ),
                
                // Toggle between Login and Signup modes
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isSignUp = !_isSignUp;
                    });
                  },
                  child: Text(
                    _isSignUp ? 'Already have an instance? Log in' : 'Need an instance? Register',
                    style: TextStyle(color: theme.colorScheme.primary),
                  ),
                ),

                const SizedBox(height: 20),
                
                // The sleek "OR" divider
                Row(
                  children: [
                    Expanded(child: Divider(color: theme.colorScheme.primary.withOpacity(0.3))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text("OR", style: TextStyle(color: theme.colorScheme.primary.withOpacity(0.5), fontWeight: FontWeight.bold)),
                    ),
                    Expanded(child: Divider(color: theme.colorScheme.primary.withOpacity(0.3))),
                  ],
                ),
                const SizedBox(height: 30),

                // Native Google Sign-In Button
                OutlinedButton.icon(
                  onPressed: _googleSignIn,
                  icon: Icon(Icons.account_circle, color: theme.colorScheme.primary, size: 24),
                  label: const Text(
                    'CONTINUE WITH GOOGLE',
                    style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.onSurface,
                    backgroundColor: theme.colorScheme.surface,
                    side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.5), width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}