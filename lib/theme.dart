import 'package:flutter/material.dart';

/// Farben wie bei GenoRadar (Entwurf „A · Radar“).
class Farben {
  static const grund = Color(0xFF0A0E13);
  static const leiste = Color(0xFF0C1117);
  static const flaeche = Color(0xFF111821);
  static const flaecheTief = Color(0xFF0F151D);
  static const flaecheHoch = Color(0xFF17212C);
  static const radarGrund = Color(0xFF0B1218);
  static const linie = Color(0xFF1C2631);
  static const linieHell = Color(0xFF24303C);
  static const radarRing = Color(0xFF1F3A30);

  static const text = Color(0xFFE6EBF0);
  static const textGedaempft = Color(0xFF8E9BA8);
  static const textMittel = Color(0xFFA7B3BF);
  static const textHell = Color(0xFFC9D3DC);

  static const akzent = Color(0xFF3DDC97);
  static const akzentHell = Color(0xFF7BEBB8);
  static const aufAkzent = Color(0xFF06281A);
  static const akzentFlaeche = Color(0xFF123826);
  static const akzentRand = Color(0xFF2B5A45);

  static const warn = Color(0xFFF2B66D);
  static const warnHell = Color(0xFFF2C48A);
  static const warnFlaeche = Color(0xFF13110B);
  static const warnRand = Color(0xFF3A3020);
  static const warnTag = Color(0xFF3A2C16);

  static const info = Color(0xFF8FB8FF);
  static const fehler = Color(0xFFFF8F7A);
  static const fehlerFlaeche = Color(0xFF1E1212);
  static const ruhig = Color(0xFF5E7387);
}

class Schrift {
  static const titel = 'SpaceGrotesk';
  static const text = 'Manrope';

  static TextStyle h1([double groesse = 28]) => TextStyle(
      fontFamily: titel, fontWeight: FontWeight.w700, fontSize: groesse, height: 1.12, letterSpacing: -0.5,
      color: Farben.text);
  static TextStyle h2([double groesse = 18, Color farbe = Farben.text]) =>
      TextStyle(fontFamily: titel, fontWeight: FontWeight.w600, fontSize: groesse, height: 1.25, color: farbe);
  static TextStyle zahl([double groesse = 22, Color farbe = Farben.text]) =>
      TextStyle(fontFamily: titel, fontWeight: FontWeight.w700, fontSize: groesse, height: 1.05, color: farbe);
  static TextStyle body([double groesse = 14, Color farbe = Farben.text, FontWeight gewicht = FontWeight.w500]) =>
      TextStyle(fontFamily: text, fontWeight: gewicht, fontSize: groesse, height: 1.45, color: farbe);
  static TextStyle klein([Color farbe = Farben.textGedaempft, double groesse = 12.5]) =>
      TextStyle(fontFamily: text, fontWeight: FontWeight.w500, fontSize: groesse, height: 1.35, color: farbe);
  static TextStyle etikett([Color farbe = Farben.textGedaempft]) => TextStyle(
      fontFamily: text, fontWeight: FontWeight.w700, fontSize: 11.5, letterSpacing: 0.9, color: farbe);
}

ThemeData baueTheme() {
  final basis = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    fontFamily: Schrift.text,
    scaffoldBackgroundColor: Farben.grund,
    colorScheme: const ColorScheme.dark(
      primary: Farben.akzent,
      onPrimary: Farben.aufAkzent,
      secondary: Farben.info,
      surface: Farben.flaeche,
      onSurface: Farben.text,
      error: Farben.fehler,
    ),
  );
  return basis.copyWith(
    textTheme: basis.textTheme.apply(bodyColor: Farben.text, displayColor: Farben.text, fontFamily: Schrift.text),
    dividerColor: Farben.linie,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Farben.flaeche,
      hintStyle: Schrift.body(15, Farben.textGedaempft),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Farben.linieHell)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Farben.linieHell)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Farben.akzent, width: 1.5)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Farben.flaecheHoch,
      contentTextStyle: Schrift.body(14),
      behavior: SnackBarBehavior.floating,
      actionTextColor: Farben.akzent,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Farben.flaecheTief,
      showDragHandle: true,
      dragHandleColor: Farben.linieHell,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (z) => z.contains(WidgetState.selected) ? Farben.aufAkzent : Farben.textGedaempft),
      trackColor: WidgetStateProperty.resolveWith(
          (z) => z.contains(WidgetState.selected) ? Farben.akzent : Farben.flaecheHoch),
    ),
  );
}
