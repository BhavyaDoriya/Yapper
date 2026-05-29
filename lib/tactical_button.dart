import 'package:flutter/material.dart';
import 'audio_manager.dart'; // INJECT THE AUDIO ENGINE

class TacticalButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool isDanger;
  final bool isLoading;

  const TacticalButton({
    super.key,
    required this.label,
    required this.onTap,
    this.isDanger = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color accentColor = isDanger ? Colors.redAccent : theme.colorScheme.primary;

    return GestureDetector(
      onTap: isLoading ? null : () {
        AudioManager().playThump(); // TRIGGER THE HEAVY GEAR SOUND
        if (onTap != null) onTap!();
      },
      child: SizedBox(
        width: double.infinity,
        height: 55, 
        child: CustomPaint(
          painter: _HexagonButtonPainter(color: accentColor),
          child: Center(
            child: isLoading
                ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: accentColor))
                : Text(
                    label,
                    style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3.0,
                      fontSize: 13,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _HexagonButtonPainter extends CustomPainter {
  final Color color;
  _HexagonButtonPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    const double pointWidth = 15.0; 

    path.moveTo(pointWidth, 0); 
    path.lineTo(size.width - pointWidth, 0); 
    path.lineTo(size.width, size.height / 2); 
    path.lineTo(size.width - pointWidth, size.height); 
    path.lineTo(pointWidth, size.height); 
    path.lineTo(0, size.height / 2); 
    path.close();

    final fillPaint = Paint()
      ..color = color.withOpacity(0.08)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = color.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}