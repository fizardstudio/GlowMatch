import 'package:flutter/material.dart';

class MakeupPreset {
  final String name;
  final String description;
  final String icon;
  final Color lipstickColor;
  final double lipstickOpacity;
  final String lipstickFinishing; // 'matte' / 'glossy'
  final Color blushColor;
  final double blushOpacity;
  final Color foundationColor;
  final double foundationOpacity;
  final bool showGlassSkin;
  final Color eyeshadowColor;
  final double eyeshadowOpacity;
  final bool hasEyeliner;
  final String lightingPreset;

  const MakeupPreset({
    required this.name,
    required this.description,
    required this.icon,
    required this.lipstickColor,
    required this.lipstickOpacity,
    required this.lipstickFinishing,
    required this.blushColor,
    required this.blushOpacity,
    required this.foundationColor,
    required this.foundationOpacity,
    required this.showGlassSkin,
    required this.eyeshadowColor,
    required this.eyeshadowOpacity,
    required this.hasEyeliner,
    required this.lightingPreset,
  });

  static List<MakeupPreset> get presets => [
    const MakeupPreset(
      name: 'Custom',
      description: 'Gaya bebas bawaan.',
      icon: '✨',
      lipstickColor: Colors.transparent,
      lipstickOpacity: 0.0,
      lipstickFinishing: 'matte',
      blushColor: Colors.transparent,
      blushOpacity: 0.0,
      foundationColor: Colors.transparent,
      foundationOpacity: 0.0,
      showGlassSkin: false,
      eyeshadowColor: Colors.transparent,
      eyeshadowOpacity: 0.0,
      hasEyeliner: false,
      lightingPreset: 'Studio',
    ),
    const MakeupPreset(
      name: 'Korean Dewy',
      description: 'Kulit bercahaya basah, rona peach tipis, bibir merah ceri mengkilap.',
      icon: '🌸',
      lipstickColor: Color(0xFFFF4081), // Cherry pink
      lipstickOpacity: 0.50,
      lipstickFinishing: 'glossy',
      blushColor: Color(0xFFFFAB91), // Soft peach
      blushOpacity: 0.45,
      foundationColor: Color(0xFFFBE9E7), // Light porcelain
      foundationOpacity: 0.40,
      showGlassSkin: true,
      eyeshadowColor: Color(0xFFFFCC80), // Champagne shimmer
      eyeshadowOpacity: 0.40,
      hasEyeliner: false,
      lightingPreset: 'Soft Glow',
    ),
    const MakeupPreset(
      name: 'Sunset Peach',
      description: 'Warna jingga senja hangat yang eksotis dan segar.',
      icon: '🍊',
      lipstickColor: Color(0xFFFF7043), // Terracotta/Coral
      lipstickOpacity: 0.65,
      lipstickFinishing: 'matte',
      blushColor: Color(0xFFFFB74D), // Coral orange
      blushOpacity: 0.55,
      foundationColor: Color(0xFFFFF3E0), // Warm beige
      foundationOpacity: 0.50,
      showGlassSkin: false,
      eyeshadowColor: Color(0xFFFFA726), // Bronze gold
      eyeshadowOpacity: 0.55,
      hasEyeliner: true,
      lightingPreset: 'Sunset Warmth',
    ),
    const MakeupPreset(
      name: 'Classic Glam',
      description: 'Bibir merah tua berani, dahi bersih matte, eyeliner tebal bersayap.',
      icon: '💋',
      lipstickColor: Color(0xFFD50000), // Bold crimson red
      lipstickOpacity: 0.85,
      lipstickFinishing: 'matte',
      blushColor: Color(0xFFF48FB1), // Rose pink
      blushOpacity: 0.35,
      foundationColor: Color(0xFFECEFF1), // Matte neutral
      foundationOpacity: 0.60,
      showGlassSkin: false,
      eyeshadowColor: Color(0xFFB0BEC5), // Nude taupe
      eyeshadowOpacity: 0.40,
      hasEyeliner: true,
      lightingPreset: 'Studio',
    ),
    const MakeupPreset(
      name: 'Cyber Neon',
      description: 'Bibir ungu elektrik glossy, rona pipi magenta cerah di bawah cahaya neon.',
      icon: '⚡',
      lipstickColor: Color(0xFFD500F9), // Purple neon
      lipstickOpacity: 0.70,
      lipstickFinishing: 'glossy',
      blushColor: Color(0xFFF50057), // Hot pink
      blushOpacity: 0.60,
      foundationColor: Color(0xFFFAFAFA), // Bright porcelain
      foundationOpacity: 0.45,
      showGlassSkin: true,
      eyeshadowColor: Color(0xFF00E5FF), // Cyber cyan
      eyeshadowOpacity: 0.65,
      hasEyeliner: true,
      lightingPreset: 'Cyber Neon',
    ),
  ];
}
