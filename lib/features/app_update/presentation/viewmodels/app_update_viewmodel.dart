import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../app/di/providers.dart';
import '../../domain/entities/app_release_info.dart';
import '../../domain/entities/installed_version.dart';
import '../../domain/repositories/app_installer_service.dart';
import '../../domain/repositories/app_update_repository.dart';

// ─── Estados ─────────────────────────────────────

/// Estados posibles del flujo de actualización.
enum AppUpdateStatus {
  idle,
  checking,
  downloading,
  readyToInstall,
  installing,
  error,
  postponed,
}

/// Estado inmutable del ViewModel de actualización.
class AppUpdateState {
  final AppUpdateStatus status;
  final double downloadProgress;
  final AppReleaseInfo? availableRelease;
  final String? filePath;
  final String? errorMessage;
  final bool isPostponed;

  const AppUpdateState({
    this.status = AppUpdateStatus.idle,
    this.downloadProgress = 0.0,
    this.availableRelease,
    this.filePath,
    this.errorMessage,
    this.isPostponed = false,
  });

  AppUpdateState copyWith({
    AppUpdateStatus? status,
    double? downloadProgress,
    AppReleaseInfo? availableRelease,
    String? filePath,
    String? errorMessage,
    bool? isPostponed,
  }) {
    return AppUpdateState(
      status: status ?? this.status,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      availableRelease: availableRelease ?? this.availableRelease,
      filePath: filePath ?? this.filePath,
      errorMessage: errorMessage ?? this.errorMessage,
      isPostponed: isPostponed ?? this.isPostponed,
    );
  }
}

// ─── ViewModel ───────────────────────────────────

/// ViewModel que maneja el ciclo completo de detección → descarga → instalación.
class AppUpdateNotifier extends Notifier<AppUpdateState> {
  StreamSubscription<AppReleaseInfo?>? _releaseSub;

  @override
  AppUpdateState build() {
    ref.onDispose(() => _releaseSub?.cancel());
    _startWatching();
    return const AppUpdateState(status: AppUpdateStatus.checking);
  }

  AppUpdateRepository get _repo => ref.read(appUpdateRepositoryProvider);
  AppInstallerService get _installer =>
      ref.read(appInstallerServiceProvider);

  /// Determina la plataforma actual como string.
  String get _currentPlatform {
    if (defaultTargetPlatform == TargetPlatform.android) return 'android';
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
    if (defaultTargetPlatform == TargetPlatform.windows) return 'windows';
    if (defaultTargetPlatform == TargetPlatform.macOS) return 'macos';
    if (defaultTargetPlatform == TargetPlatform.linux) return 'linux';
    if (kIsWeb) return 'web';
    return 'unknown';
  }

  /// Inicia la escucha del stream de releases.
  void _startWatching() {
    _releaseSub?.cancel();
    _releaseSub = _repo.watchLatestRelease(_currentPlatform).listen(
      (release) async {
        if (release == null) {
          state = const AppUpdateState(status: AppUpdateStatus.idle);
          return;
        }

        final hasUpdate = await _isNewerThanLocal(release);
        if (hasUpdate) {
          final cached = await _repo.isAlreadyDownloaded(release);
          state = state.copyWith(
            status: cached
                ? AppUpdateStatus.readyToInstall
                : AppUpdateStatus.idle,
            availableRelease: release,
            isPostponed: state.isPostponed,
          );
          if (!state.isPostponed && !cached) {
            state = state.copyWith(status: AppUpdateStatus.idle);
          }
        } else {
          state = const AppUpdateState(status: AppUpdateStatus.idle);
        }
      },
      onError: (e) {
        debugPrint('AppUpdateNotifier: Error en stream: $e');
        state = state.copyWith(
          status: AppUpdateStatus.error,
          errorMessage: 'Error verificando actualizaciones: $e',
        );
      },
    );
  }

  /// Compara el release remoto con la versión local instalada.
  Future<bool> _isNewerThanLocal(AppReleaseInfo remote) async {
    try {
      final info = await PackageInfo.fromPlatform();
      final localVersion = info.version;
      final localBuild = int.tryParse(info.buildNumber) ?? 0;

      final cmp = _compareVersions(remote.version, localVersion);
      if (cmp > 0) return true;
      if (cmp == 0 && remote.buildNumber > localBuild) return true;
      return false;
    } catch (e) {
      debugPrint('AppUpdateNotifier: Error obteniendo versión local: $e');
      return false;
    }
  }

  /// Compara dos strings de versión semántica. Retorna >0 si a > b.
  int _compareVersions(String a, String b) {
    final partsA = a.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final partsB = b.split('.').map((s) => int.tryParse(s) ?? 0).toList();

    for (int i = 0; i < 3; i++) {
      final va = i < partsA.length ? partsA[i] : 0;
      final vb = i < partsB.length ? partsB[i] : 0;
      if (va != vb) return va - vb;
    }
    return 0;
  }

  /// Indica si hay una actualización disponible.
  bool get hasUpdateAvailable =>
      state.availableRelease != null &&
      state.status != AppUpdateStatus.idle;

  /// Inicia la descarga del release disponible.
  Future<void> startDownload() async {
    final release = state.availableRelease;
    if (release == null) return;

    state = state.copyWith(
      status: AppUpdateStatus.downloading,
      downloadProgress: 0.0,
      errorMessage: null,
    );

    try {
      final filePath = await _repo.downloadRelease(
        release,
        onProgress: (progress) {
          state = state.copyWith(downloadProgress: progress);
        },
      );

      state = state.copyWith(
        status: AppUpdateStatus.readyToInstall,
        filePath: filePath,
        downloadProgress: 1.0,
      );
    } catch (e) {
      debugPrint('AppUpdateNotifier: Error descargando: $e');
      state = state.copyWith(
        status: AppUpdateStatus.error,
        errorMessage: 'Error durante la descarga: $e',
      );
    }
  }

  /// Instala la actualización descargada.
  Future<void> installUpdate() async {
    final path = state.filePath;
    final release = state.availableRelease;
    if (path == null || release == null) return;

    if (!_installer.isSupported) {
      state = state.copyWith(
        status: AppUpdateStatus.error,
        errorMessage:
            'La instalación automática no está disponible en esta plataforma.',
      );
      return;
    }

    state = state.copyWith(status: AppUpdateStatus.installing);

    try {
      await _installer.install(path);

      // Registrar en historial local
      await _repo.recordInstalledVersion(InstalledVersion(
        id: '${release.version}+${release.buildNumber}',
        version: release.version,
        buildNumber: release.buildNumber,
        platform: _currentPlatform,
        installedAt: DateTime.now(),
      ));

      // Intentar sincronizar (best-effort)
      try {
        await _repo.syncVersionHistory();
      } catch (_) {}

      state = const AppUpdateState(status: AppUpdateStatus.idle);
    } catch (e) {
      debugPrint('AppUpdateNotifier: Error instalando: $e');
      state = state.copyWith(
        status: AppUpdateStatus.error,
        errorMessage: 'Error al instalar: $e',
      );
    }
  }

  /// Pospone la actualización (cierra el diálogo pero mantiene badge).
  void postpone() {
    state = state.copyWith(
      status: AppUpdateStatus.postponed,
      isPostponed: true,
    );
  }

  /// Reactiva la actualización después de posponer.
  void showUpdateAgain() {
    if (state.availableRelease != null) {
      state = state.copyWith(
        isPostponed: false,
        status: AppUpdateStatus.idle,
      );
    }
  }

  /// Reintenta tras un error.
  void retry() {
    state = const AppUpdateState(status: AppUpdateStatus.checking);
    _startWatching();
  }
}

/// Notifier provider para el ViewModel de actualización.
final appUpdateNotifierProvider =
    NotifierProvider<AppUpdateNotifier, AppUpdateState>(
  AppUpdateNotifier.new,
);
