// Olympus Mont Systems LLC - ControlMiles
// lib/theme/cm_colors.dart
//
// Warm palette (2026-10-09, owner's request: "a more alive app, web style").
// The app used Tailwind "slate" grays on white (#F8FAFC, #1E293B, #64748B...),
// which read cold and dated next to the website. Researched competitors:
// Gridwise and Samsara moved to warm stone/off-white backgrounds with a warm
// near-black ink and ONE strong accent; MileIQ adds cream sections. The
// ControlMiles website already uses that recipe (landing.css: cream
// #FAF6EE, ink #211C14, blue #2C6C99 / #3E93CA, amber #BD5B26), so the app
// now follows the website.
//
// Every former slate value was swapped 1:1 for its warm equivalent across
// lib/ (same lightness, warm hue), so existing light/dark branches keep their
// contrast. New code should use these names instead of raw hex.

import 'package:flutter/material.dart';

class CmColors {
  CmColors._();

  // Brand (website)
  static const blue = Color(0xFF2C6C99); // primary actions
  static const blueBright = Color(0xFF3E93CA); // logo blue, highlights
  static const amber = Color(0xFFBD5B26); // "live" things: active trip, today's routes

  // Light
  static const cream = Color(0xFFFAF6EE); // page background (was slate-50)
  static const creamDeep = Color(0xFFF3ECDF); // subtle fills (was slate-100)
  static const sand = Color(0xFFE3D9C4); // borders / dividers (was slate-200)
  static const sandDeep = Color(0xFFCFC3A8); // stronger borders (was slate-300)
  static const inkMuted = Color(0xFFA39A86); // hints (was slate-400)
  static const inkDim = Color(0xFF6B6250); // secondary text (was slate-500)
  static const inkSoft = Color(0xFF574F40); // (was slate-600)
  static const inkStrong = Color(0xFF3D352A); // (was slate-700)
  static const ink = Color(0xFF2E281F); // primary text, borders in dark (was slate-800)

  // Dark
  static const night = Color(0xFF12100C); // page background (was slate-950)
  static const nightCard = Color(0xFF1C1812); // cards, app bars (was slate-900)
  static const nightInk = Color(0xFF211C14); // header blocks (website ink)
}
