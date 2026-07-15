import 'dart:async';
import 'package:dart_ping/dart_ping.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum PingStatus { idle, running, stopped, error }

class PingEntry {
  final int seq;
  final double? rttMs;
  final int? ttl;
  final bool timedOut;
  final String? error;

  PingEntry({
    required this.seq,
    this.rttMs,
    this.ttl,
    this.timedOut = false,
    this.error,
  });

  bool get success => !timedOut && error == null && rttMs != null;
}

class PingState {
  final PingStatus status;
  final String target;
  final List<PingEntry> entries;
  final String? errorMessage;

  const PingState({
    this.status = PingStatus.idle,
    this.target = '',
    this.entries = const [],
    this.errorMessage,
  });

  int get sent => entries.length;
  int get received => entries.where((e) => e.success).length;
  double get lossPercent =>
      sent == 0 ? 0 : ((sent - received) / sent * 100);
  double? get avgRtt {
    final rtts = entries.where((e) => e.success).map((e) => e.rttMs!).toList();
    if (rtts.isEmpty) return null;
    return rtts.reduce((a, b) => a + b) / rtts.length;
  }

  PingState copyWith({
    PingStatus? status,
    String? target,
    List<PingEntry>? entries,
    String? errorMessage,
  }) {
    return PingState(
      status: status ?? this.status,
      target: target ?? this.target,
      entries: entries ?? this.entries,
      errorMessage: errorMessage,
    );
  }
}

class PingNotifier extends Notifier<PingState> {
  Ping? _ping;
  StreamSubscription<PingData>? _sub;

  @override
  PingState build() {
    ref.onDispose(() {
      _sub?.cancel();
      _ping?.stop();
    });
    return const PingState();
  }

  void start(String target, {bool continuous = true}) {
    _sub?.cancel();
    _ping?.stop();

    state = PingState(
      status: PingStatus.running,
      target: target,
      entries: [],
    );

    _ping = Ping(target, count: continuous ? null : 10, interval: 1, timeout: 2);
    _sub = _ping!.stream.listen(
      (data) {
        if (data.error != null) {
          final err = data.error!;
          final entry = PingEntry(
            seq: state.entries.length,
            timedOut: err.error == ErrorType.requestTimedOut ||
                err.error == ErrorType.noReply,
            error: (err.error == ErrorType.requestTimedOut ||
                    err.error == ErrorType.noReply)
                ? null
                : err.toString(),
          );
          state = state.copyWith(entries: [...state.entries, entry]);
        } else if (data.response != null) {
          final r = data.response!;
          final entry = PingEntry(
            seq: state.entries.length,
            rttMs: r.time != null ? r.time!.inMicroseconds / 1000.0 : null,
            ttl: r.ttl,
          );
          state = state.copyWith(entries: [...state.entries, entry]);
        }
      },
      onError: (e) {
        state = state.copyWith(
          status: PingStatus.error,
          errorMessage: e.toString(),
        );
      },
      onDone: () {
        if (state.status == PingStatus.running) {
          state = state.copyWith(status: PingStatus.stopped);
        }
      },
    );
  }

  void stop() {
    _sub?.cancel();
    _ping?.stop();
    if (state.status == PingStatus.running) {
      state = state.copyWith(status: PingStatus.stopped);
    }
  }

  void reset() {
    _sub?.cancel();
    _ping?.stop();
    state = const PingState();
  }
}

final pingProvider =
    NotifierProvider.autoDispose<PingNotifier, PingState>(PingNotifier.new);
