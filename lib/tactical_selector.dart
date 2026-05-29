import 'package:flutter/material.dart';
import 'audio_manager.dart'; // INJECT THE AUDIO ENGINE

class TacticalSelector extends StatelessWidget {
  final String label;
  final List<String> options;
  final String currentValue;
  final ValueChanged<String> onChanged;

  const TacticalSelector({
    super.key,
    required this.label,
    required this.options,
    required this.currentValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    int currentIndex = options.indexOf(currentValue);
    if (currentIndex == -1) currentIndex = 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween, 
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
              fontWeight: FontWeight.w600,
              letterSpacing: 2.0,
              fontSize: 12,
            ),
          ),
          
          Row(
            mainAxisSize: MainAxisSize.min, 
            children: [
              GestureDetector(
                onTap: () {
                  AudioManager().playClick(); // TRIGGER THE TICK SOUND
                  if (currentIndex > 0) onChanged(options[currentIndex - 1]);
                  else onChanged(options[options.length - 1]);
                },
                child: Container(
                  padding: const EdgeInsets.all(8.0),
                  color: Colors.transparent,
                  child: Icon(Icons.chevron_left, color: theme.colorScheme.primary, size: 22),
                ),
              ),
              
              SizedBox(
                width: 160, 
                child: Text(
                  currentValue,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ),

              GestureDetector(
                onTap: () {
                  AudioManager().playClick(); // TRIGGER THE TICK SOUND
                  if (currentIndex < options.length - 1) onChanged(options[currentIndex + 1]);
                  else onChanged(options[0]);
                },
                child: Container(
                  padding: const EdgeInsets.all(8.0),
                  color: Colors.transparent,
                  child: Icon(Icons.chevron_right, color: theme.colorScheme.primary, size: 22),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}