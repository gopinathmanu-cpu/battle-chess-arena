// SPDX-License-Identifier: GPL-3.0-or-later
import '../../domain/bot_tournament.dart';
import '../../domain/online_player_profile.dart';
import '../../services/last_game_storage.dart';

class TournamentMatchConfig {
  const TournamentMatchConfig({
    required this.title,
    required this.opponent,
    required this.minutesPerSide,
    required this.save,
    required this.cup,
    required this.roundIndex,
  });

  final String title;
  final BuiltInComputerOpponent opponent;
  final int minutesPerSide;
  final BotTournament cup;
  final int roundIndex;
  bool get isFinal => roundIndex == cup.roundCount - 1;
  final Future<void> Function(SavedGame game, TournamentRoundResult? result)
  save;
}
