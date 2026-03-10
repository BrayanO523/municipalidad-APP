import 'package:hive/hive.dart';
import '../models/hive/cobro_hive.dart';

class CobroLocalDatasource {
  static const String boxName = 'cobrosBox';

  Future<Box<CobroHive>> _getBox() async {
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<CobroHive>(boxName);
    }
    return await Hive.openBox<CobroHive>(boxName);
  }

  Future<void> guardarCobro(CobroHive cobro) async {
    final box = await _getBox();
    await box.put(cobro.id, cobro);
  }

  Future<void> guardarCobros(List<CobroHive> cobros) async {
    final box = await _getBox();
    final Map<dynamic, CobroHive> cobrosMap = {
      for (var cobro in cobros) cobro.id: cobro,
    };
    await box.putAll(cobrosMap);
  }

  Future<List<CobroHive>> obtenerTodos() async {
    final box = await _getBox();
    return box.values.toList();
  }

  Future<CobroHive?> obtenerPorId(String id) async {
    final box = await _getBox();
    return box.get(id);
  }

  Future<List<CobroHive>> obtenerPendientesDeSincronizacion() async {
    final box = await _getBox();
    return box.values
        .where((c) => c.syncStatus == 0)
        .toList(); // 0 = pendiente_envio
  }

  Future<void> eliminarCobro(String id) async {
    final box = await _getBox();
    await box.delete(id);
  }

  Future<void> limpiarCaja() async {
    final box = await _getBox();
    await box.clear();
  }
}
