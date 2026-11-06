import 'package:flutter/material.dart';

import 'collections_api.dart';

/// Same 24 identities as the web client; saved color values never change.
abstract final class DataFormatColors {
  static const _dark = [
    0xFF24344A,
    0xFF203C32,
    0xFF443325,
    0xFF322B43,
    0xFF442D36,
    0xFF203A3E,
    0xFF403B26,
    0xFF303D2A,
    0xFF3E2D43,
    0xFF2B3543,
    0xFF423328,
    0xFF263C49,
    0xFF422D3C,
    0xFF263847,
    0xFF374029,
    0xFF443027,
    0xFF30314A,
    0xFF243D37,
    0xFF3E352B,
    0xFF263B40,
    0xFF44312F,
    0xFF343E2A,
    0xFF33344A,
    0xFF263C30,
  ];
  static const _markers = [
    0xFFA6C9FF,
    0xFF93DDB8,
    0xFFFFD0A0,
    0xFFCBB9FF,
    0xFFFFB7CB,
    0xFF8ADDE6,
    0xFFE8D991,
    0xFFB6DC94,
    0xFFE7B4E9,
    0xFFAFCAEB,
    0xFFF0C69F,
    0xFF9BD7F4,
    0xFFF0B4D9,
    0xFF9DCDF2,
    0xFFD1E292,
    0xFFFFC2A2,
    0xFFBDBDFF,
    0xFF8DE1C6,
    0xFFE4C9A5,
    0xFF91D7DA,
    0xFFFFB7AC,
    0xFFC7DF8C,
    0xFFC4C5FF,
    0xFFA4DEAA,
  ];
  static Color surface(String color, bool dark) {
    final index = brainyFormatColors.indexOf(color);
    return dark
        ? Color(index < 0 ? 0xFF24344A : _dark[index])
        : Color(
            0xFF000000 |
                (int.tryParse(color.replaceFirst('#', ''), radix: 16) ??
                    0xEEF5FF),
          );
  }

  static Color marker(String color, bool dark) {
    final index = brainyFormatColors.indexOf(color);
    return Color(
      index < 0
          ? (dark ? 0xFFA6C9FF : 0xFF24344A)
          : dark
          ? _markers[index]
          : _dark[index],
    );
  }
}
