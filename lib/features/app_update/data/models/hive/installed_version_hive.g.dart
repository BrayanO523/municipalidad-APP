// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'installed_version_hive.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class InstalledVersionHiveAdapter extends TypeAdapter<InstalledVersionHive> {
  @override
  final int typeId = 10;

  @override
  InstalledVersionHive read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return InstalledVersionHive(
      id: fields[0] as String,
      version: fields[1] as String,
      buildNumber: fields[2] as int,
      platform: fields[3] as String,
      installedAt: fields[4] as DateTime,
      syncStatus: fields[5] as String,
    );
  }

  @override
  void write(BinaryWriter writer, InstalledVersionHive obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.version)
      ..writeByte(2)
      ..write(obj.buildNumber)
      ..writeByte(3)
      ..write(obj.platform)
      ..writeByte(4)
      ..write(obj.installedAt)
      ..writeByte(5)
      ..write(obj.syncStatus);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InstalledVersionHiveAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
