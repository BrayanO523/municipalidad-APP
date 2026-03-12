import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/entities/usuario.dart';
import '../viewmodels/usuarios_paginados_notifier.dart';

class CorrelativosControlScreen extends ConsumerStatefulWidget {
  const CorrelativosControlScreen({super.key});

  @override
  ConsumerState<CorrelativosControlScreen> createState() => _CorrelativosControlScreenState();
}

class _CorrelativosControlScreenState extends ConsumerState<CorrelativosControlScreen> {
  @override
  void initState() {
    super.initState();
    // Forzar la carga de los cobradores si venimos directo a esta pantalla sin pasar por "Usuarios"
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(usuariosPaginadosProvider.notifier);
      final state = ref.read(usuariosPaginadosProvider);
      if (state.usuarios.isEmpty && !state.cargando) {
        notifier.cargarPagina(reiniciar: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(usuariosPaginadosProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, outerConstraints) {
          final isMobile = outerConstraints.maxWidth <= 700;
          return Padding(
            padding: isMobile
                ? const EdgeInsets.all(12)
                : const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeaderSection(),
                const SizedBox(height: 24),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      if (state.cargando && state.usuarios.isEmpty) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (state.errorMsg != null && state.usuarios.isEmpty) {
                        return Center(child: Text('Error: ${state.errorMsg}'));
                      }
                      return _CorrelativosTable(
                        usuarios: state.usuarios.where((u) => u.esCobrador).toList(),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 500;
        return Row(
          children: [
            Icon(
              Icons.tag_rounded,
              color: Theme.of(context).colorScheme.onSurface,
              size: isMobile ? 22 : 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isMobile ? 'Correlativos' : 'Control de Correlativos',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: isMobile ? 18 : 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    isMobile
                        ? 'Prefijos y numeración'
                        : 'Supervisión de prefijos y numeración por cobrador',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withAlpha(138),
                      fontSize: isMobile ? 12 : 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CorrelativosTable extends StatelessWidget {
  final List<dynamic> usuarios;

  const _CorrelativosTable({required this.usuarios});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (usuarios.isEmpty) {
      return Center(
        child: Text(
          'No hay cobradores registrados',
          style: TextStyle(color: colorScheme.onSurface.withAlpha(128)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withAlpha(77),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withAlpha(26)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                colorScheme.primary.withAlpha(13),
              ),
              columns: const [
                DataColumn(label: Text('Cobrador')),
                DataColumn(label: Text('Código (Prefijo)')),
                DataColumn(label: Text('Año')),
                DataColumn(label: Text('Último Correlativo')),
                DataColumn(label: Text('Estado')),
                DataColumn(label: Text('Acciones')),
              ],
              rows: usuarios.map((u) {
                final int ultimoC = u.ultimoCorrelativo ?? 0;
                final String codigo = u.codigoCobrador ?? 'SIN ASIGNAR';
                final int anio = u.anioCorrelativo ?? DateTime.now().year;

                return DataRow(
                  cells: [
                    DataCell(
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: colorScheme.primary.withAlpha(26),
                            child: Text(
                              u.nombre?.substring(0, 1).toUpperCase() ?? 'U',
                              style: TextStyle(
                                fontSize: 10,
                                color: colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(u.nombre ?? ''),
                        ],
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          codigo,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ),
                    DataCell(Text(anio.toString())),
                    DataCell(
                      Text(
                        ultimoC.toString().padLeft(4, '0'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataCell(
                      _StatusBadge(ultimoC: ultimoC),
                    ),
                    DataCell(
                      OutlinedButton.icon(
                        icon: const Icon(Icons.list_alt_rounded, size: 16),
                        label: const Text('Ver'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          foregroundColor: colorScheme.primary,
                        ),
                        onPressed: () {
                          context.pushNamed(
                            'cobrador-cobros-admin',
                            extra: u as Usuario,
                          );
                        },
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final int ultimoC;
  const _StatusBadge({required this.ultimoC});

  @override
  Widget build(BuildContext context) {
    final bool isAtivo = ultimoC > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isAtivo 
            ? Colors.green.withAlpha(26) 
            : Colors.orange.withAlpha(26),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isAtivo ? Colors.green.withAlpha(77) : Colors.orange.withAlpha(77),
        ),
      ),
      child: Text(
        isAtivo ? 'Activo' : 'Sin Cobros',
        style: TextStyle(
          color: isAtivo ? Colors.green : Colors.orange,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
