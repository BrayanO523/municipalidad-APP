import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/app_release_info.dart';

/// DTO para mapear datos de Firestore a/desde [AppReleaseInfo].
class AppReleaseModel {
  final String version;
  final int buildNumber;
  final String storagePath;
  final String fileName;
  final DateTime? updatedAt;

  const AppReleaseModel({
    required this.version,
    required this.buildNumber,
    required this.storagePath,
    required this.fileName,
    this.updatedAt,
  });

  /// Construye desde un mapa de Firestore (el sub-documento de una plataforma).
  factory AppReleaseModel.fromFirestore(Map<String, dynamic> map) {
    return AppReleaseModel(
      version: map['version'] as String? ?? '0.0.0',
      buildNumber: (map['buildNumber'] as num?)?.toInt() ?? 0,
      storagePath: map['storagePath'] as String? ?? '',
      fileName: map['fileName'] as String? ?? '',
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Convierte a entidad de dominio.
  AppReleaseInfo toEntity() {
    return AppReleaseInfo(
      version: version,
      buildNumber: buildNumber,
      storagePath: storagePath,
      fileName: fileName,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'version': version,
      'buildNumber': buildNumber,
      'storagePath': storagePath,
      'fileName': fileName,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }
}
