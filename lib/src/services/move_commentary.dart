// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/game_session.dart';

/// Spoken move descriptions are optional and never delay the chess game.
abstract interface class MoveCommentary {
  Future<void> speak(String text);
  Future<void> stop();
  Future<void> dispose();
}

/// Uses Android's installed text-to-speech engine.
/// Other platforms still display the move caption supplied by the screen.
class NativeMoveCommentary implements MoveCommentary {
  NativeMoveCommentary({MethodChannel? channel, TargetPlatform? platform})
    : _channel = channel ?? const MethodChannel(_channelName),
      _platform = platform ?? defaultTargetPlatform;

  static const _channelName = 'battle_chess_arena/move_commentary';
  final MethodChannel _channel;
  final TargetPlatform _platform;
  bool _disposed = false;

  bool get isSupported => !kIsWeb && _platform == TargetPlatform.android;

  @override
  Future<void> speak(String text) async {
    final narration = text.trim();
    if (_disposed || narration.isEmpty) return;
    await _invoke('speak', {'text': narration});
  }

  @override
  Future<void> stop() async {
    if (_disposed) return;
    await _invoke('stop');
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _invoke('dispose');
  }

  Future<void> _invoke(String method, [Map<String, Object>? arguments]) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      // Older installations can keep showing captions without a voice bridge.
    } on PlatformException {
      // A missing voice or unavailable speech engine must not interrupt play.
    }
  }
}

/// Describes the committed move, including the actual king destination when
/// dartchess encodes castling as a move to the rook's square.
String moveCommentaryText(MoveResolution resolution) {
  final move = resolution.move;
  final side = resolution.attacker.color == Side.white ? 'White' : 'Black';
  final role = resolution.attacker.role.name;
  final defender = resolution.defender;
  String text;

  if (resolution.san.startsWith('O-O')) {
    final kingSide = !resolution.san.startsWith('O-O-O');
    final kingTarget = Square.fromCoords(
      kingSide ? File.g : File.c,
      move.from.rank,
    );
    final rookSource = Square.fromCoords(
      kingSide ? File.h : File.a,
      move.from.rank,
    );
    final rookTarget = Square.fromCoords(
      kingSide ? File.f : File.d,
      move.from.rank,
    );
    text =
        '$side castles ${kingSide ? 'kingside' : 'queenside'}, moving the king '
        'from ${move.from.name} to ${kingTarget.name} and the rook '
        'from ${rookSource.name} to ${rookTarget.name}';
  } else {
    text = '$side $role moves from ${move.from.name} to ${move.to.name}';
    if (defender != null) {
      text += ', capturing a ${defender.color.name} ${defender.role.name}';
    }
    if (move.promotion != null) {
      text += ' and promotes to a ${move.promotion!.name}';
    }
  }

  text += '.';
  if (resolution.san.endsWith('#')) {
    text += ' Checkmate. $side wins.';
  } else if (resolution.san.endsWith('+')) {
    text += ' Check.';
  }
  return text;
}
