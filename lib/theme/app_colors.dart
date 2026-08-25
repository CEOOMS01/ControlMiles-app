// Olympus Mont Systems LLC - ControlMiles
// lib/theme/app_colors.dart
//
// BUG FIX (pedido explícito, modernización de UI): antes había TRES
// paletas de azul distintas conviviendo en la app -- 0xFF2563EB
// hardcodeado en 10 archivos (login, settings, drawer, etc.), 0xFF475569
// (gris pizarra) como "accent" del Dashboard, y el color real del logo
// (extraído en pixel, no a ojo) que no coincidía con ninguno de los dos.
// Decisión: el color del logo es la única fuente de verdad de acá en
// adelante.
//
// Esta constante NO debe usarse directo en widgets para pintar UI --
// alimenta ColorScheme.fromSeed() en main.dart, y desde los widgets se
// consume vía Theme.of(context).colorScheme.primary (que sí es
// brightness-aware: se aclara solo en dark mode). Usar kBrandSeed directo
// en un widget reintroduce el mismo problema que esto viene a resolver.

import 'package:flutter/material.dart';

const Color kBrandSeed = Color(0xFF3E93CA);

// BUG FIX (pedido explícito): el azul de marca real (kBrandSeed) resalta
// demasiado en modo oscuro -- ColorScheme.fromSeed() en dark brightness
// tiende a elegir un tono más claro/vívido del seed para garantizar
// contraste contra fondos oscuros, lo cual acentúa la saturación original
// (56.9%). Esta NO es una corrección manual de primary/onPrimary por
// separado (eso rompería la relación entre roles M3 derivados, ver nota
// arriba) -- es un SEED distinto, más desaturado (56.9% → 38%, mismo
// hue/lightness, verificado con colorsys), que se le pasa entero al mismo
// ColorScheme.fromSeed() para modo oscuro. Todos los roles (onPrimary,
// primaryContainer, etc.) se derivan consistentes entre sí, solo que del
// seed atenuado. Modo claro no se toca -- no fue señalado como problema.
const Color kBrandSeedDark = Color(0xFF558EB3);
