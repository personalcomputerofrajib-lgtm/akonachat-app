import 'package:flutter/material.dart';

class CustomChatBubble extends StatelessWidget {
  final Widget child;
  final bool isMe;
  final Gradient? gradient;
  final Color? color;
  final double borderRadius;
  final bool showTail;

  const CustomChatBubble({
    Key? key,
    required this.child,
    required this.isMe,
    this.gradient,
    this.color,
    this.borderRadius = 20,
    this.showTail = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: BubblePainter(
        isMe: isMe,
        color: color ?? (isMe ? Colors.blue : Colors.grey[300]!),
        gradient: gradient,
        borderRadius: borderRadius,
        showTail: showTail,
      ),
      child: Container(
        padding: EdgeInsets.fromLTRB(
          isMe ? 14 : 22, 
          12, 
          isMe ? 22 : 14, 
          12
        ),
        child: child,
      ),
    );
  }
}

class BubblePainter extends CustomPainter {
  final bool isMe;
  final Color color;
  final Gradient? gradient;
  final double borderRadius;
  final bool showTail;

  BubblePainter({
    required this.isMe,
    required this.color,
    this.gradient,
    this.borderRadius = 20,
    this.showTail = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    if (gradient != null) {
      paint.shader = gradient!.createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    }

    final path = Path();
    if (isMe) {
      // Bubble for Me (Sender)
      path.addRRect(RRect.fromLTRBAndCorners(
        0, 0, size.width - 8, size.height,
        topLeft: Radius.circular(borderRadius),
        topRight: Radius.circular(borderRadius),
        bottomLeft: Radius.circular(borderRadius),
        bottomRight: const Radius.circular(0),
      ));
      if (showTail) {
        path.moveTo(size.width - 8, size.height - 15);
        path.lineTo(size.width, size.height);
        path.lineTo(size.width - 15, size.height);
        path.close();
      }
    } else {
      // Bubble for Other (Recipient)
      path.addRRect(RRect.fromLTRBAndCorners(
        8, 0, size.width, size.height,
        topLeft: Radius.circular(borderRadius),
        topRight: Radius.circular(borderRadius),
        bottomLeft: const Radius.circular(0),
        bottomRight: Radius.circular(borderRadius),
      ));
      if (showTail) {
        path.moveTo(8, size.height - 15);
        path.lineTo(0, size.height);
        path.lineTo(15, size.height);
        path.close();
      }
    }

    canvas.drawPath(path, paint);
    
    // Optional Glow/Shadow
    canvas.drawShadow(path, color.withOpacity(0.3), 4, true);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
