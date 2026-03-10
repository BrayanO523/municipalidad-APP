import 'package:hive/hive.dart';
import '../models/hive/municipalidad_hive.dart';

class MunicipalidadLocalDatasource {
  static const String boxName = 'municipalidadesBox';

  Future<Box<MunicipalidadHive>> _getBox() async {
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<MunicipalidadHive>(boxName);
    }
    return await Hive.openBox<MunicipalidadHive>(boxName);
  }

  Future<void> guardar(MunicipalidadHive municipalidad) async {
    final box = await _getBox();
    await box.put(municipalidad.id, municipalidad);
  }

  Future<void> guardarTodas(List<MunicipalidadHive> municipalidades) async {
    final box = await _getBox();
    final Map<dynamic, MunicipalidadHive> entries = {
      for (var m in municipalidades) m.id: m,
    };
    await box.putAll(entries);
  }

  Future<List<MunicipalidadHive>> obtenerTodas() async {
    final box = await _getBox();
    return box.values.toList();
  }

  Future<MunicipalidadHive?> obtenerPorId(String id) async {
    final box = await _getBox();
    return box.get(id);
  }

  Future<void> limpiar() async {
    final box = await _getBox();
    await box.clear();
  }
}
