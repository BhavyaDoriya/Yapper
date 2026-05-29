import 'package:flutter/material.dart';

class TacticalPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final String trailingText;
  final IconData? icon;
  final Widget? bottomWidget;

  const TacticalPanel({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailingText = '',
    this.icon,
    this.bottomWidget,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary.withOpacity(0.08), Colors.transparent],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        border: Border(
          left: BorderSide(color: theme.colorScheme.primary.withOpacity(0.8), width: 4), // Glowing edge
          top: BorderSide(color: theme.colorScheme.primary.withOpacity(0.1), width: 1), // Wireframe
          bottom: BorderSide(color: theme.colorScheme.primary.withOpacity(0.1), width: 1), // Wireframe
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER ROW
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: theme.colorScheme.primary, size: 24),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3.0,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (trailingText.isNotEmpty)
                  Text(
                    trailingText,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2.0,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            
            // BODY TEXT
            Text(
              subtitle,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
                fontSize: 16,
              ),
            ),
            
            // OPTIONAL ACTION (Like the 'Queue Completed' text)
            if (bottomWidget != null) ...[
              const SizedBox(height: 24),
              bottomWidget!,
            ]
          ],
        ),
      ),
    );
  }
}