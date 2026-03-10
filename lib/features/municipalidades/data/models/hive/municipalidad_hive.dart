import 'package:hive/hive.dart';
import '../../../domain/entities/municipalidad.dart';

part 'municipalidad_hive.g.dart';

@HiveType(typeId: 4)
class MunicipalidadHive extends HiveObject {
  @HiveField(0)
  String? id;

  @HiveField(1)
  String? nombre;

  @HiveField(2)
  String? municipio;

  @HiveField(3)
  String? departamento;

  @HiveField(4)
  String? logo;

  @HiveField(5)
  bool? activa;

  @HiveField(6)
  double? porcentaje;

  MunicipalidadHive({
    this.id,
    this.nombre,
    this.municipio,
    this.departamento,
    this.logo,
    this.activa,
    this.porcentaje,
  });

  Municipalidad toDomain() {
    return Municipalidad(
      id: id,
      nombre: nombre,
      municipio: municipio,
      departamento: departamento,
      logo: logo,
      activa: activa,
      porcentaje: porcentaje,
    );
  }

  factory MunicipalidadHive.fromDomain(Municipalidad entity) {
    return MunicipalidadHive(
      id: entity.id,
      nombre: entity.nombre,
      municipio: entity.municipio,
      departamento: entity.departamento,
      logo: entity.logo,
      activa: entity.activa,
      porcentaje: entity.porcentaje?.toDouble(),
    );
  }
}
