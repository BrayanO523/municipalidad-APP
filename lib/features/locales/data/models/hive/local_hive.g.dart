// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_hive.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LocalHiveAdapter extends TypeAdapter<LocalHive> {
  @override
  final int typeId = 1;

  @override
  LocalHive read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LocalHive(
      id: fields[0] as String?,
      syncStatus: fields[1] as int,
      activo: fields[2] as bool?,
      actualizadoEn: fields[3] as DateTime?,
      actualizadoPor: fields[4] as String?,
      creadoEn: fields[5] as DateTime?,
      creadoPor: fields[6] as String?,
      cuotaDiaria: fields[7] as double?,
      espacioM2: fields[8] as double?,
      mercadoId: fields[9] as String?,
      municipalidadId: fields[10] as String?,
      nombreSocial: fields[11] as String?,
      qrData: fields[12] as String?,
      representante: fields[13] as String?,
      telefonoRepresentante: fields[14] as String?,
      tipoNegocioId: fields[15] as String?,
      latitud: fields[16] as double?,
      longitud: fields[17] as double?,
      saldoAFavor: fields[18] as double?,
      deudaAcumulada: fields[19] as double?,
      frecuenciaCobro: fields[24] as String?,
      perimetroJson: fields[20] as String?,
      clave: fields[21] as String?,
      codigo: fields[25] as String?,
      codigoLower: fields[26] as String?,
      codigoCatastral: fields[22] as String?,
      codigoCatastralLower: fields[23] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, LocalHive obj) {
    writer
      ..writeByte(27)
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
      ..write(obj.cuotaDiaria)
      ..writeByte(8)
      ..write(obj.espacioM2)
      ..writeByte(9)
      ..write(obj.mercadoId)
      ..writeByte(10)
      ..write(obj.municipalidadId)
      ..writeByte(11)
      ..write(obj.nombreSocial)
      ..writeByte(12)
      ..write(obj.qrData)
      ..writeByte(13)
      ..write(obj.representante)
      ..writeByte(14)
      ..write(obj.telefonoRepresentante)
      ..writeByte(15)
      ..write(obj.tipoNegocioId)
      ..writeByte(16)
      ..write(obj.latitud)
      ..writeByte(17)
      ..write(obj.longitud)
      ..writeByte(18)
      ..write(obj.saldoAFavor)
      ..writeByte(19)
      ..write(obj.deudaAcumulada)
      ..writeByte(20)
      ..write(obj.perimetroJson)
      ..writeByte(21)
      ..write(obj.clave)
      ..writeByte(22)
      ..write(obj.codigoCatastral)
      ..writeByte(23)
      ..write(obj.codigoCatastralLower)
      ..writeByte(24)
      ..write(obj.frecuenciaCobro)
      ..writeByte(25)
      ..write(obj.codigo)
      ..writeByte(26)
      ..write(obj.codigoLower);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalHiveAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
