/**
 * SAARTHI Flutter App - Neon Colors
 * Neon color palette for modern UI
 */

import 'package:flutter/material.dart';

class NeonColors {
  // Neon Pink
  static const Color neonPink = Color(0xFFFF00FF);
  static const Color neonPinkLight = Color(0xFFFF6BFF);
  static const Color neonPinkDark = Color(0xFFCC00CC);
  
  // Neon Cyan/Blue
  static const Color neonCyan = Color(0xFF00FFFF);
  static const Color neonCyanLight = Color(0xFF4ECDC4);
  static const Color neonCyanDark = Color(0xFF00CCCC);
  
  // Neon Green
  static const Color neonGreen = Color(0xFF00FF00);
  static const Color neonGreenLight = Color(0xFF95E1D3);
  static const Color neonGreenDark = Color(0xFF00CC00);
  
  // Neon Yellow
  static const Color neonYellow = Color(0xFFFFFF00);
  static const Color neonYellowLight = Color(0xFFFFF44F);
  
  // Neon Orange
  static const Color neonOrange = Color(0xFFFF6600);
  
  // Neon Purple
  static const Color neonPurple = Color(0xFF9900FF);
  
  // Text with neon glow effect
  static TextStyle neonText({
    required double fontSize,
    FontWeight fontWeight = FontWeight.bold,
    Color color = neonPink,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      shadows: [
        Shadow(
          color: color.withOpacity(0.8),
          blurRadius: 10,
          offset: const Offset(0, 0),
        ),
        Shadow(
          color: color.withOpacity(0.6),
          blurRadius: 20,
          offset: const Offset(0, 0),
        ),
        Shadow(
          color: color.withOpacity(0.4),
          blurRadius: 30,
          offset: const Offset(0, 0),
        ),
      ],
    );
  }
  
  // Light neon colors for dark backgrounds
  static const Color lightNeonPink = Color(0xFFFF6B9D);
  static const Color lightNeonCyan = Color(0xFF4ECDC4);
  static const Color lightNeonGreen = Color(0xFF95E1D3);
  static const Color lightNeonPurple = Color(0xFFB794F6);
  
  // Gradient text shader with light neon colors
  static Shader neonGradientShader(Rect bounds) {
    return const LinearGradient(
      colors: [
        lightNeonPink,  // Light Pink
        lightNeonCyan,  // Light Cyan
        lightNeonGreen,  // Light Green
      ],
    ).createShader(bounds);
  }
  
  // Light gradient shader for better visibility on dark background
  static Shader lightNeonGradientShader(Rect bounds) {
    return const LinearGradient(
      colors: [
        lightNeonPink,
        lightNeonCyan,
        lightNeonPurple,
      ],
    ).createShader(bounds);
  }
}

