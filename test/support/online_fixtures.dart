import 'dart:async';
import 'dart:convert';
import 'package:battle_chess_arena/src/domain/game_session.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

Map<String, dynamic> stateJson({
  GameSession? game,
  int sequence = 1,
  int round = 1,
  String status = 'active',
  String gameId = 'room',
  Map<String, dynamic>? result,
  int whiteMs = 60000,
  int blackMs = 60000,
}) {
  game ??= GameSession();
  return {
    'gameId': gameId,
    'sequence': sequence,
    'round': round,
    'status': status,
    'fen': game.position.fen,
    'turn': game.position.turn.name == 'white' ? 'w' : 'b',
    'san': game.sanMoves,
    'clocks': {'w': whiteMs, 'b': blackMs},
    'result': result,
    'drawOffer': null,
    'rematchOffers': <String>[],
  };
}

class FakeChannel implements WebSocketChannel {
  final incoming = StreamController<dynamic>();
  final sent = <Map<String, dynamic>>[];
  late final FakeSink outgoing = FakeSink(sent);
  @override
  Future<void> get ready async {}
  @override
  Stream<dynamic> get stream => incoming.stream;
  @override
  WebSocketSink get sink => outgoing;
  void receive(Map<String, dynamic> frame) => incoming.add(jsonEncode(frame));
  void seat({String seat = 'w', Map<String, dynamic>? state}) => receive({
    'type': 'game_created',
    'gameId': 'room',
    'seat': seat,
    'seatToken': 'test-secret',
    'state': state ?? stateJson(),
  });
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeSink implements WebSocketSink {
  FakeSink(this.sent);
  final List<Map<String, dynamic>> sent;
  final _closed = Completer<void>();
  @override
  void add(dynamic data) =>
      sent.add(jsonDecode(data as String) as Map<String, dynamic>);
  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    if (!_closed.isCompleted) _closed.complete();
  }

  @override
  Future<void> get done => _closed.future;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
