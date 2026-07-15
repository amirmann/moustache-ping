import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_internet_speed_test_pro/flutter_internet_speed_test_pro.dart';
import '../../shared/storage/hive_service.dart';
import 'speed_result.dart';

enum SpeedTestStatus { idle, testingDownload, testingUpload, done, error }

enum SpeedProvider { fast, ookla }

class SpeedTestState {
  final SpeedTestStatus status;
  final SpeedProvider provider;
  final double downloadMbps;
  final double uploadMbps;
  final int latencyMs;
  final double progress;
  final String? error;
  final List<SpeedResult> history;

  const SpeedTestState({
    this.status = SpeedTestStatus.idle,
    this.provider = SpeedProvider.fast,
    this.downloadMbps = 0,
    this.uploadMbps = 0,
    this.latencyMs = 0,
    this.progress = 0,
    this.error,
    this.history = const [],
  });

  SpeedTestState copyWith({
    SpeedTestStatus? status,
    SpeedProvider? provider,
    double? downloadMbps,
    double? uploadMbps,
    int? latencyMs,
    double? progress,
    String? error,
    List<SpeedResult>? history,
  }) {
    return SpeedTestState(
      status: status ?? this.status,
      provider: provider ?? this.provider,
      downloadMbps: downloadMbps ?? this.downloadMbps,
      uploadMbps: uploadMbps ?? this.uploadMbps,
      latencyMs: latencyMs ?? this.latencyMs,
      progress: progress ?? this.progress,
      error: error,
      history: history ?? this.history,
    );
  }
}

class SpeedTestNotifier extends Notifier<SpeedTestState> {
  final _speedTest = FlutterInternetSpeedTest();

  @override
  SpeedTestState build() {
    return SpeedTestState(history: HiveService.getAllSpeedResults());
  }

  void setProvider(SpeedProvider p) {
    state = state.copyWith(provider: p);
  }

  Future<void> startTest() async {
    if (_speedTest.isTestInProgress()) return;

    state = SpeedTestState(
      status: SpeedTestStatus.testingDownload,
      provider: state.provider,
      history: state.history,
    );

    final useFast = state.provider == SpeedProvider.fast;

    await _speedTest.startTesting(
      useFastApi: useFast,
      onCompleted: (TestResult download, TestResult upload) async {
        final saved = SpeedResult(
          downloadMbps: download.transferRate,
          uploadMbps: upload.transferRate,
          latencyMs: 0,
          timestamp: DateTime.now(),
          provider: state.provider.name,
        );
        await HiveService.saveSpeedResult(saved);
        state = state.copyWith(
          status: SpeedTestStatus.done,
          downloadMbps: download.transferRate,
          uploadMbps: upload.transferRate,
          progress: 1.0,
          history: HiveService.getAllSpeedResults(),
        );
      },
      onDownloadComplete: (TestResult result) {
        state = state.copyWith(
          status: SpeedTestStatus.testingUpload,
          downloadMbps: result.transferRate,
          progress: 0.5,
        );
      },
      onUploadComplete: (TestResult result) {
        state = state.copyWith(
          uploadMbps: result.transferRate,
          progress: 1.0,
        );
      },
      onError: (String errorMsg, String errorCode) {
        state = state.copyWith(
          status: SpeedTestStatus.error,
          error: errorMsg,
        );
      },
      onProgress: (double percent, TestResult result) {
        final isDownload = state.status == SpeedTestStatus.testingDownload;
        state = state.copyWith(
          progress: isDownload ? percent / 200 : 0.5 + percent / 200,
          downloadMbps: isDownload ? result.transferRate : state.downloadMbps,
          uploadMbps: !isDownload ? result.transferRate : state.uploadMbps,
        );
      },
      onDefaultServerSelectionInProgress: () {},
      onDefaultServerSelectionDone: (Client? client) {},
      onCancel: () {
        state = state.copyWith(status: SpeedTestStatus.idle);
      },
    );
  }

  Future<void> cancel() async {
    await _speedTest.cancelTest();
    state = state.copyWith(status: SpeedTestStatus.idle);
  }

  void reset() {
    state = SpeedTestState(
      provider: state.provider,
      history: state.history,
    );
  }
}

final speedTestProvider =
    NotifierProvider.autoDispose<SpeedTestNotifier, SpeedTestState>(
  SpeedTestNotifier.new,
);
