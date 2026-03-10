// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cobro_hive.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CobroHiveAdapter extends TypeAdapter<CobroHive> {
  @override
  final int typeId = 0;

  @override
  CobroHive read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CobroHive(
      id: fields[0] as String?,
      syncStatus: fields[1] as int,
      cobradorId: fields[2] as String?,
      actualizadoEn: fields[3] as DateTime?,
      actualizadoPor: fields[4] as String?,
      creadoEn: fields[5] as DateTime?,
      creadoPor: fields[6] as String?,
      cuotaDiaria: fields[7] as double?,
      estado: fields[8] as String?,
      fecha: fields[9] as DateTime?,
      localId: fields[10] as String?,
      mercadoId: fields[11] as String?,
      monto: fields[12] as double?,
      municipalidadId: fields[13] as String?,
      observaciones: fields[14] as String?,
      saldoPendiente: fields[15] as double?,
      telefonoRepresentante: fields[16] as String?,
      correlativo: fields[17] as int?,
      numeroBoleta: fields[23] as String?,
      anioCorrelativo: fields[18] as int?,
      deudaAnterior: fields[19] as double?,
      montoAbonadoDeuda: fields[20] as double?,
      nuevoSaldoFavor: fields[21] as double?,
      pagoACuota: fields[22] as double?,
      idsDeudasSaldadas: (fields[24] as List?)?.cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, CobroHive obj) {
    writer
      ..writeByte(25)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.syncStatus)
      ..writeByte(2)
      ..write(obj.cobradorId)
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
      ..write(obj.estado)
      ..writeByte(9)
      ..write(obj.fecha)
      ..writeByte(10)
      ..write(obj.localId)
      ..writeByte(11)
      ..write(obj.mercadoId)
      ..writeByte(12)
      ..write(obj.monto)
      ..writeByte(13)
      ..write(obj.municipalidadId)
      ..writeByte(14)
      ..write(obj.observaciones)
      ..writeByte(15)
      ..write(obj.saldoPendiente)
      ..writeByte(16)
      ..write(obj.telefonoRepresentante)
      ..writeByte(17)
      ..write(obj.correlativo)
      ..writeByte(18)
      ..write(obj.anioCorrelativo)
      ..writeByte(19)
      ..write(obj.deudaAnterior)
      ..writeByte(20)
      ..write(obj.montoAbonadoDeuda)
      ..writeByte(21)
      ..write(obj.nuevoSaldoFavor)
      ..writeByte(22)
      ..write(obj.pagoACuota)
      ..writeByte(23)
      ..write(obj.numeroBoleta)
      ..writeByte(24)
      ..write(obj.idsDeudasSaldadas);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CobroHiveAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
