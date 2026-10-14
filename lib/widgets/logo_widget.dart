import 'package:flutter/material.dart';

/// Color de acento exacto de la plantilla.
const Color kAccent = Color(0xFFFFC000);

/// Logo reconstruido VECTORIALMENTE (no se embebe el PNG de baja resolucion).
/// Una onda tipo ECG en ambar sobre dos lineas de texto:
///   "J&H EQUIPOS MEDICOS SAS"
///   "NIT. 901.933.809-3"
/// Reutilizable en el encabezado de la app. El PDF dibuja la misma figura con
/// primitivas de package:pdf (ver pdf/report_pdf.dart).
class LogoWidget extends StatelessWidget {
  final double width;

  const LogoWidget({super.key, this.width = 220});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: width,
            height: width * 0.18,
            child: CustomPaint(painter: _EcgPainter()),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'J&H EQUIPOS MEDICOS SAS',
              style: TextStyle(
                color: kAccent,
                fontWeight: FontWeight.w800,
                fontSize: 16,
                letterSpacing: 0.5,
              ),
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'NIT. 901.933.809-3',
              style: TextStyle(
                color: kAccent,
                fontWeight: FontWeight.w700,
                fontSize: 10,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dibuja la onda ECG: linea base, pico R y valles, estilo cardiograma.
class _EcgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = kAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.height * 0.14
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;
    final midY = h * 0.55;

    // Perfil ECG normalizado (x fraccion, y fraccion desde arriba).
    final pts = <Offset>[
      Offset(0.00, 0.55),
      Offset(0.18, 0.55),
      Offset(0.26, 0.40),
      Offset(0.33, 0.70),
      Offset(0.40, 0.05), // pico R
      Offset(0.47, 0.95),
      Offset(0.54, 0.45),
      Offset(0.62, 0.55),
      Offset(0.70, 0.40),
      Offset(0.77, 0.70),
      Offset(0.84, 0.30),
      Offset(0.91, 0.55),
      Offset(1.00, 0.55),
    ];

    final path = Path();
    for (var i = 0; i < pts.length; i++) {
      final x = pts[i].dx * w;
      final y = pts[i].dy * h;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawLine(
      Offset(0, midY),
      Offset(w, midY),
      Paint()
        ..color = kAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.height * 0.06,
    );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
