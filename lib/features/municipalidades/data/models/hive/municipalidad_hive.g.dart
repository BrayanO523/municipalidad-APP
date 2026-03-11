// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'municipalidad_hive.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MunicipalidadHiveAdapter extends TypeAdapter<MunicipalidadHive> {
  @override
  final int typeId = 4;

  @override
  MunicipalidadHive read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MunicipalidadHive(
      id: fields[0] as String?,
      nombre: fields[1] as String?,
      municipio: fields[2] as String?,
      departamento: fields[3] as String?,
      logo: fields[4] as String?,
      activa: fields[5] as bool?,
      porcentaje: fields[6] as double?,
      slogan: fields[7] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, MunicipalidadHive obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.nombre)
      ..writeByte(2)
      ..write(obj.municipio)
      ..writeByte(3)
      ..write(obj.departamento)
      ..writeByte(4)
      ..write(obj.logo)
      ..writeByte(5)
      ..write(obj.activa)
      ..writeByte(6)
      ..write(obj.porcentaje)
      ..writeByte(7)
      ..write(obj.slogan);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MunicipalidadHiveAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
