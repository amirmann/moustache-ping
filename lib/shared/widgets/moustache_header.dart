import 'package:flutter/material.dart';

class MoustacheHeader extends StatelessWidget implements PreferredSizeWidget {
  const MoustacheHeader({super.key, required this.title});

  final String title;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _MoustacheIcon(),
          const SizedBox(width: 8),
          Text(title),
        ],
      ),
    );
  }
}

class _MoustacheIcon extends StatelessWidget {
  const _MoustacheIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(32, 18),
      painter: _MoustachePainter(color: Theme.of(context).colorScheme.primary),
    );
  }
}

class _MoustachePainter extends CustomPainter {
  _MoustachePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final w = size.width;
    final h = size.height;

    // Left curl
    path.moveTo(w * 0.5, h * 0.45);
    path.cubicTo(w * 0.38, h * 0.1, w * 0.05, h * 0.0, w * 0.0, h * 0.3);
    path.cubicTo(w * 0.0, h * 0.7, w * 0.18, h * 1.0, w * 0.28, h * 0.8);
    path.cubicTo(w * 0.38, h * 0.6, w * 0.45, h * 0.55, w * 0.5, h * 0.55);

    // Right curl (mirror)
    path.moveTo(w * 0.5, h * 0.45);
    path.cubicTo(w * 0.62, h * 0.1, w * 0.95, h * 0.0, w * 1.0, h * 0.3);
    path.cubicTo(w * 1.0, h * 0.7, w * 0.82, h * 1.0, w * 0.72, h * 0.8);
    path.cubicTo(w * 0.62, h * 0.6, w * 0.55, h * 0.55, w * 0.5, h * 0.55);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_MoustachePainter old) => old.color != color;
}
