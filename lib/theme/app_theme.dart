// Tema visual global, colores y estilos comunes de la aplicacion.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TecneroTheme {
  // Colores principales Tecnero
  static const Color azulOscuro = Color(0xFF0C2D5E);
  static const Color azulMedio = Color(0xFF185FA5);
  static const Color naranja = Color(0xFFE05A1B);
  static const Color naranjaClaro = Color(0xFFF4874A);
  static const Color grisClaro = Color(0xFFF5F6FA);
  static const Color grisBorde = Color(0xFFE2E5ED);
  static const Color textoPrimario = Color(0xFF1A1E2E);
  static const Color textoSecundario = Color(0xFF6B7280);

  // Estados
  static const Color pendiente = Color(0xFFF59E0B);
  static const Color aprobado = Color(0xFF10B981);
  static const Color entregado = Color(0xFF3B82F6);
  static const Color rechazado = Color(0xFFEF4444);

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: azulOscuro,
          primary: azulOscuro,
          secondary: naranja,
          surface: Colors.white,
        ),
        textTheme: GoogleFonts.plusJakartaSansTextTheme().copyWith(
          displayLarge: GoogleFonts.plusJakartaSans(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: textoPrimario,
          ),
          headlineMedium: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: textoPrimario,
          ),
          titleLarge: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textoPrimario,
          ),
          bodyLarge: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: textoPrimario,
          ),
          bodyMedium: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: textoSecundario,
          ),
        ),
        scaffoldBackgroundColor: grisClaro,
        appBarTheme: AppBarTheme(
          backgroundColor: azulOscuro,
          foregroundColor: Colors.white,
          elevation: 0,
          titleTextStyle: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: grisBorde, width: 1),
          ),
          margin: const EdgeInsets.only(bottom: 12),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: naranja,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: grisBorde),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: grisBorde),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: azulOscuro, width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          labelStyle:
              GoogleFonts.plusJakartaSans(fontSize: 13, color: textoSecundario),
        ),
      );
}

// Badges de estado
class EstadoBadge extends StatelessWidget {
  final String estado;

  const EstadoBadge({super.key, required this.estado});

  @override
  Widget build(BuildContext context) {
    final config = _config();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: config['bg'],
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        estado.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: config['text'],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Map<String, Color> _config() {
    switch (estado.toLowerCase()) {
      case 'pendiente':
        return {
          'bg': Color(0xFFFEF3C7),
          'text': Color(0xFF92400E),
        };
      case 'aprobada':
        return {
          'bg': Color(0xFFD1FAE5),
          'text': Color(0xFF065F46),
        };
      case 'entregada':
        return {
          'bg': Color(0xFFDBEAFE),
          'text': Color(0xFF1E40AF),
        };
      case 'rechazada':
        return {
          'bg': Color(0xFFFEE2E2),
          'text': Color(0xFF991B1B),
        };
      default:
        return {
          'bg': Color(0xFFF3F4F6),
          'text': Color(0xFF374151),
        };
    }
  }
}
