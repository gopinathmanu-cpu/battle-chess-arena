import 'package:dartchess/dartchess.dart';

enum PlayerMode { local, computer }

class MoveResolution {
  const MoveResolution({
    required this.move,
    required this.san,
    required this.attacker,
    this.defender,
  });

  final NormalMove move;
  final String san;
  final Piece attacker;
  final Piece? defender;

  bool get isCapture => defender != null;
}

class GameSession {
  GameSession({this.mode = PlayerMode.local, Position? position})
    : _position = position ?? Chess.initial;

  factory GameSession.fromMoves({
    PlayerMode mode = PlayerMode.local,
    required Iterable<String> moves,
  }) {
    final session = GameSession(mode: mode);
    for (final move in moves) {
      if (session.playUci(move) == null) {
        throw FormatException('Invalid saved move: $move');
      }
    }
    return session;
  }

  final PlayerMode mode;
  Position _position;
  final List<Position> _positions = <Position>[];
  final List<String> _sanMoves = <String>[];
  final List<String> _uciMoves = <String>[];

  Position get position => _position;
  List<String> get sanMoves => List.unmodifiable(_sanMoves);
  List<String> get uciMoves => List.unmodifiable(_uciMoves);
  bool get canUndo => _positions.isNotEmpty;
  bool get isHumanTurn =>
      mode == PlayerMode.local || _position.turn == Side.white;

  Piece? pieceAt(Square square) => _position.board.pieceAt(square);

  Set<Square> legalDestinations(Square from) {
    final piece = pieceAt(from);
    if (piece == null || piece.color != _position.turn) return const {};
    return _position.legalMovesOf(from).squares.map((to) {
      // dartchess represents castling as king-to-rook internally. The UI uses
      // the familiar king destination (g-file or c-file).
      if (piece.role == Role.king && pieceAt(to)?.color == piece.color) {
        return Square.fromCoords(
          to.file > from.file ? File.g : File.c,
          from.rank,
        );
      }
      return to;
    }).toSet();
  }

  MoveResolution? play(Square from, Square to, {Role promotion = Role.queen}) {
    final attacker = pieceAt(from);
    if (attacker == null || attacker.color != _position.turn) return null;

    final reachesBackRank =
        attacker.role == Role.pawn &&
        (to.rank == Rank.first || to.rank == Rank.eighth);
    var engineTarget = to;
    if (attacker.role == Role.king &&
        from.file == File.e &&
        (to.file == File.g || to.file == File.c)) {
      engineTarget = Square.fromCoords(
        to.file == File.g ? File.h : File.a,
        from.rank,
      );
    }
    final move = NormalMove(
      from: from,
      to: engineTarget,
      promotion: reachesBackRank ? promotion : null,
    );
    if (!_position.isLegal(move)) return null;

    Piece? defender = engineTarget == to ? pieceAt(to) : null;
    // The rules engine encodes castling as king-to-own-rook.
    if (defender?.color == attacker.color) defender = null;
    if (defender == null &&
        attacker.role == Role.pawn &&
        from.file != to.file) {
      defender = Piece(color: attacker.color.opposite, role: Role.pawn);
    }

    final (next, san) = _position.makeSan(move);
    _positions.add(_position);
    _sanMoves.add(san);
    _uciMoves.add(move.uci);
    _position = next;
    return MoveResolution(
      move: move,
      san: san,
      attacker: attacker,
      defender: defender,
    );
  }

  MoveResolution? playUci(String uci) {
    final parsed = Move.parse(uci);
    if (parsed is! NormalMove) return null;
    return play(
      parsed.from,
      parsed.to,
      promotion: parsed.promotion ?? Role.queen,
    );
  }

  void undo() {
    if (_positions.isEmpty) return;
    _position = _positions.removeLast();
    _sanMoves.removeLast();
    _uciMoves.removeLast();
  }

  void reset() {
    _position = Chess.initial;
    _positions.clear();
    _sanMoves.clear();
    _uciMoves.clear();
  }
}
