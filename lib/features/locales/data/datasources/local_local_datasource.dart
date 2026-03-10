import 'package:hive/hive.dart';
import '../models/hive/local_hive.dart';

class LocalLocalDatasource {
  static const String boxName = 'localesBox';

  Future<Box<LocalHive>> _getBox() async {
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<LocalHive>(boxName);
    }
    return await Hive.openBox<LocalHive>(boxName);
  }

  Future<void> guardarLocal(LocalHive local) async {
    final box = await _getBox();
    await box.put(local.id, local);
  }

  Future<void> guardarLocales(List<LocalHive> locales) async {
    final box = await _getBox();
    final Map<dynamic, LocalHive> localesMap = {
      for (var local in locales) local.id: local,
    };
    await box.putAll(localesMap);
  }

  Future<List<LocalHive>> obtenerTodos() async {
    final box = await _getBox();
    return box.values.toList();
  }

  Future<LocalHive?> obtenerPorId(String id) async {
    final box = await _getBox();
    return box.get(id);
  }

  Future<List<LocalHive>> obtenerPendientesDeSincronizacion() async {
    final box = await _getBox();
    return box.values.where((l) => l.syncStatus == 0).toList();
  }

  Future<void> eliminarLocal(String id) async {
    final box = await _getBox();
    await box.delete(id);
  }

  Future<void> limpiarCaja() async {
    final box = await _getBox();
    await box.clear();
  }
}
