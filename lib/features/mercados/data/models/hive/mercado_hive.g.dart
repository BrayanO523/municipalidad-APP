// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mercado_hive.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MercadoHiveAdapter extends TypeAdapter<MercadoHive> {
  @override
  final int typeId = 2;

  @override
  MercadoHive read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MercadoHive(
      id: fields[0] as String?,
      syncStatus: fields[1] as int,
      activo: fields[2] as bool?,
      actualizadoEn: fields[3] as DateTime?,
      actualizadoPor: fields[4] as String?,
      creadoEn: fields[5] as DateTime?,
      creadoPor: fields[6] as String?,
      municipalidadId: fields[7] as String?,
      nombre: fields[8] as String?,
      ubicacion: fields[9] as String?,
      latitud: fields[12] as double?,
      longitud: fields[13] as double?,
      perimetroJson: fields[14] as String?,
      codigo: fields[15] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, MercadoHive obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.syncStatus)
      ..writeByte(2)
      ..write(obj.activo)
      ..writeByte(3)
      ..write(obj.actualizadoEn)
      ..writeByte(4)
      ..write(obj.actualizadoPor)
      ..writeByte(5)
      ..write(obj.creadoEn)
      ..writeByte(6)
      ..write(obj.creadoPor)
      ..writeByte(7)
      ..write(obj.municipalidadId)
      ..writeByte(8)
      ..write(obj.nombre)
      ..writeByte(9)
      ..write(obj.ubicacion)
      ..writeByte(12)
      ..write(obj.latitud)
      ..writeByte(13)
      ..write(obj.longitud)
      ..writeByte(14)
      ..write(obj.perimetroJson)
      ..writeByte(15)
      ..write(obj.codigo);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MercadoHiveAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
