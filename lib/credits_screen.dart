import 'package:flutter/material.dart';
import 'dusty_atmosphere.dart';
import 'tactical_panel.dart';

class CreditsScreen extends StatelessWidget {
  const CreditsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        const DustyAtmosphere(),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(title: const Text("ENGINE CREDITS", style: TextStyle(letterSpacing: 3))),
          body: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: 600,
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      TacticalPanel(
                        title: "DEVELOPER",
                        subtitle: "Bhavya Doriya",
                      ),
                      TacticalPanel(
                        title: "ARCHITECTURE",
                        subtitle: "Flutter Engine | Supabase Security | Groq AI Proxy",
                      ),
                      TacticalPanel(
                        title: "VERSION",
                        subtitle: "1.0.0 (Stable Release)",
                        trailingText: "© 2026",
                      ),
                      const SizedBox(height: 40),
                      Text(
                        "THIS INTERFACE AND BACKEND ARCHITECTURE ARE THE INTELLECTUAL PROPERTY OF THE DEVELOPER. UNAUTHORIZED REPLICATION IS PROHIBITED.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: theme.colorScheme.primary.withOpacity(0.4), fontSize: 10, letterSpacing: 1.5),
                      )
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