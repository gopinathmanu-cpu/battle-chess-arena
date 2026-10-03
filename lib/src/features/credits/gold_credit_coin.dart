// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

/// The single visual language for spendable game credits.
///
/// A star is used instead of a currency symbol because credits are an in-game
/// balance, not cash. The layered gold treatment stays recognizable at the
/// compact sizes used in action-price badges.
class GoldCreditCoin extends StatelessWidget {
  const GoldCreditCoin({this.size = 18, super.key});

  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-.28, -.32),
          radius: .9,
          colors: [Color(0xFFFFF1A8), Color(0xFFFFC928), Color(0xFFB96B00)],
          stops: [0, .54, 1],
        ),
        border: Border.all(
          color: const Color(0xFFFFE27A),
          width: size < 14 ? .7 : 1,
        ),
        boxShadow: size < 14
            ? const []
            : const [
                BoxShadow(
                  color: Color(0x553C2300),
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.star_rounded,
        size: size * .62,
        color: const Color(0xFF7A4200),
      ),
    ),
  );
}
