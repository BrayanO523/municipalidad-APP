import 'package:hive/hive.dart';
import '../models/hive/mercado_hive.dart';

class MercadoLocalDatasource {
  static const String boxName = 'mercadosBox';

  Future<Box<MercadoHive>> _getBox() async {
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<MercadoHive>(boxName);
    }
    return await Hive.openBox<MercadoHive>(boxName);
  }

  Future<void> guardarMercado(MercadoHive mercado) async {
    final box = await _getBox();
    await box.put(mercado.id, mercado);
  }

  Future<void> guardarMercados(List<MercadoHive> mercados) async {
    final box = await _getBox();
    final Map<dynamic, MercadoHive> mercadosMap = {
      for (var mercado in mercados) mercado.id: mercado,
    };
    await box.putAll(mercadosMap);
  }

  Future<List<MercadoHive>> obtenerTodos() async {
    final box = await _getBox();
    return box.values.toList();
  }

  Future<MercadoHive?> obtenerPorId(String id) async {
    final box = await _getBox();
    return box.get(id);
  }

  Future<List<MercadoHive>> obtenerPendientesDeSincronizacion() async {
    final box = await _getBox();
    return box.values.where((m) => m.syncStatus == 0).toList();
  }

  Future<void> eliminarMercado(String id) async {
    final box = await _getBox();
    await box.delete(id);
  }

  Future<void> limpiarCaja() async {
    final box = await _getBox();
    await box.clear();
  }
}
