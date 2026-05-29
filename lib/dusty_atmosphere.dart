import 'dart:math';
import 'package:flutter/material.dart';

class DustyAtmosphere extends StatefulWidget {
  const DustyAtmosphere({super.key});

  @override
  State<DustyAtmosphere> createState() => _DustyAtmosphereState();
}

class _DustyAtmosphereState extends State<DustyAtmosphere> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Particle> _particles = [];
  final Random _rnd = Random();

  @override
  void initState() {
    super.initState();
    // OPTIMIZATION: Reduced to 45 for a stable 60FPS on Web
    for (int i = 0; i < 45; i++) {
      bool isEmber = _rnd.nextDouble() < 0.10; 
      _particles.add(Particle(
        x: _rnd.nextDouble(),
        y: _rnd.nextDouble(),
        speed: isEmber ? 0.002 + _rnd.nextDouble() * 0.003 : 0.0005 + _rnd.nextDouble() * 0.0015, 
        size: isEmber ? 1.0 + _rnd.nextDouble() * 1.5 : 1.5 + _rnd.nextDouble() * 2.5, 
        baseOpacity: isEmber ? 0.5 + _rnd.nextDouble() * 0.3 : 0.1 + _rnd.nextDouble() * 0.2,
        seed: _rnd.nextDouble() * 100, 
        color: isEmber ? const Color(0xFFFF5722) : _getRandomAshColor(), 
        isEmber: isEmber,
      ));
    }
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
  }

  Color _getRandomAshColor() {
    double val = _rnd.nextDouble();
    if (val < 0.35) return const Color(0x66AAAAAA); 
    if (val < 0.70) return const Color(0xAA222222); 
    return const Color(0x44FFFFFF); 
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.5,
          colors: [
            Color(0xFF161413), 
            Color(0xFF030303), 
          ],
        ),
      ),
      // OPTIMIZATION: RepaintBoundary stops the heavy background from repainting every frame
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            for (var p in _particles) {
              p.y -= p.speed; 
              p.x += sin((p.y * (p.isEmber ? 5 : 15)) + p.seed) * 0.0004; 

              if (p.y < 0) {
                p.y = 1.0; 
                p.x = _rnd.nextDouble(); 
              }
            }
            return CustomPaint(
              painter: _AshPainter(particles: _particles), 
              size: Size.infinite,
              isComplex: false, // OPTIMIZATION: Tells Flutter this is a cheap drawing
              willChange: true, // OPTIMIZATION: Tells Flutter to expect rapid changes
            );
          },
        ),
      ),
    );
  }
}

class Particle {
  double x, y, speed, size, baseOpacity, seed;
  Color color;
  bool isEmber;
  Particle({required this.x, required this.y, required this.speed, required this.size, required this.baseOpacity, required this.seed, required this.color, required this.isEmber});
}

class _AshPainter extends CustomPainter {
  final List<Particle> particles;
  _AshPainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    for (var p in particles) {
      final currentOpacity = p.baseOpacity * (0.6 + 0.4 * sin(p.y * pi * 4 + p.seed)); 
      
      // OPTIMIZATION: MaskFilter.blur has been completely removed to save WebGL rendering costs.
      final paint = Paint()
        ..color = p.color.withOpacity(currentOpacity.clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;
        
      final stretchHeight = p.size + (p.speed * (p.isEmber ? 1500 : 1000)); 
      
      canvas.drawOval(
        Rect.fromCenter(center: Offset(p.x * size.width, p.y * size.height), width: p.size, height: stretchHeight), 
        paint
      );
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true; 
}