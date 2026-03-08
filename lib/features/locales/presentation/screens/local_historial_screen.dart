import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../../app/di/providers.dart';
import '../../../../core/platform/web_downloader/web_downloader.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/reporte_pdf_generator.dart';
import '../../../cobros/domain/entities/cobro.dart';
import '../../../locales/domain/entities/local.dart';
import '../../../mercados/domain/entities/mercado.dart';

/// Pantalla de historial financiero completo de un local.
/// Muestra KPIs (saldo a favor, deuda, días pagados, días pendientes)
/// y el listado cronológico de todos sus cobros.
class LocalHistorialScreen extends ConsumerStatefulWidget {
  final Local local;

  const LocalHistorialScreen({super.key, required this.local});

  @override
  ConsumerState<LocalHistorialScreen> createState() =>
      _LocalHistorialScreenState();
}

class _LocalHistorialScreenState extends ConsumerState<LocalHistorialScreen> {
  String _filtro =
      'todos'; // 'todos' | 'cobrado' | 'pendiente' | 'abono_parcial'

  @override
  Widget build(BuildContext context) {
    final localAsync = ref.watch(localStreamProvider(widget.local.id ?? ''));
    final cobrosAsync = ref.watch(
      localCobrosStreamProvider(widget.local.id ?? ''),
    );
    final colorScheme = Theme.of(context).colorScheme;
    final mercados = ref.watch(mercadosProvider).value ?? [];

    return localAsync.when(
      data: (local) {
        if (local == null) {
          return const Scaffold(
            body: Center(child: Text('Local no encontrado')),
          );
        }

        return cobrosAsync.when(
          data: (cobrosList) {
            // KPIs calculados desde cobros locales
            final diasCobrados = cobrosList
                .where((c) => c.estado == 'cobrado')
                .length;
            final diasPendientes = cobrosList
                .where((c) => c.estado == 'pendiente')
                .length;
            final totalRecaudado = cobrosList.fold<num>(
              0,
              (sum, c) => sum + (c.monto ?? 0),
            );

            // ── Lógica de Días Adelantados Virtuales ───────────────────────
            final numAdelantados =
                (local.saldoAFavor ?? 0) ~/
                ((local.cuotaDiaria ?? 0) > 0 ? local.cuotaDiaria! : 1);

            final ahora = DateTime.now();
            final hoy = DateTime(ahora.year, ahora.month, ahora.day);

            // Determinar desde cuándo empezar a mostrar adelantos
            // Si hoy ya tiene un registro (cobrado o pendiente), los adelantos empiezan mañana
            final hoyTieneRegistro = cobrosList.any(
              (c) =>
                  c.fecha != null &&
                  c.fecha!.year == hoy.year &&
                  c.fecha!.month == hoy.month &&
                  c.fecha!.day == hoy.day,
            );

            final fechaInicioAdelantos = hoyTieneRegistro
                ? hoy.add(const Duration(days: 1))
                : hoy;

            final listAdelantados = List.generate(numAdelantados, (i) {
              return Cobro(
                id: 'VIRTUAL-$i',
                localId: local.id,
                fecha: fechaInicioAdelantos.add(Duration(days: i)),
                monto: local.cuotaDiaria,
                estado: 'adelantado',
                cuotaDiaria: local.cuotaDiaria,
                saldoPendiente: 0,
                observaciones: 'Día cubierto por saldo a favor.',
              );
            });

            // Combinar y filtrar
            final combinedList = [...cobrosList, ...listAdelantados];
            combinedList.sort(
              (a, b) =>
                  (b.fecha ?? DateTime(0)).compareTo(a.fecha ?? DateTime(0)),
            );

            final filtered = _filtro == 'todos'
                ? combinedList
                : _filtro == 'abono_parcial'
                ? combinedList
                      .where(
                        (c) =>
                            c.estado == 'abono_parcial' ||
                            c.estado == 'adelantado',
                      )
                      .toList()
                : combinedList.where((c) => c.estado == _filtro).toList();

            return Scaffold(
              backgroundColor: colorScheme.surface,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      local.nombreSocial ?? 'Local',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    if (local.mercadoId != null)
                      Text(
                        local.mercadoId!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                        ),
                      ),
                  ],
                ),
                actions: [
                  IconButton(
                    onPressed: () async {
                      final mercadoName =
                          mercados
                              .cast<Mercado>()
                              .firstWhere(
                                (m) => m.id == local.mercadoId,
                                orElse: () => const Mercado(nombre: '-'),
                              )
                              .nombre ??
                          '-';

                      final bytes =
                          await ReportePdfGenerator.generarEstadoCuentaLocalPdf(
                            local: local,
                            cobros: combinedList,
                            nombreMercado: mercadoName,
                          );
                      if (kIsWeb) {
                        await descargarPdfWeb(
                          bytes,
                          'EstadoCuenta_${local.nombreSocial?.replaceAll(" ", "_") ?? "Local"}.pdf',
                        );
                      } else {
                        await Printing.layoutPdf(
                          onLayout: (_) async => bytes,
                          name: 'EstadoCuenta_${local.nombreSocial}',
                        );
                      }
                    },
                    icon: const Icon(Icons.picture_as_pdf_rounded),
                    tooltip: 'Exportar estado de cuenta en PDF',
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              body: CustomScrollView(
                slivers: [
                  // ── Info del local ─────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          _LocalInfoCard(local: local),
                          const SizedBox(height: 16),
                          // KPIs financieros y Balance Neto
                          _KpiRow(
                            items: [
                              _KpiItem(
                                label: 'Saldo a Favor',
                                value: DateFormatter.formatCurrency(
                                  local.saldoAFavor ?? 0,
                                ),
                                color: const Color(0xFF00D9A6),
                                icon: Icons.savings_rounded,
                              ),
                              _KpiItem(
                                label: 'Deuda Acum.',
                                value: DateFormatter.formatCurrency(
                                  local.deudaAcumulada ?? 0,
                                ),
                                color: const Color(0xFFEE5A6F),
                                icon: Icons.warning_amber_rounded,
                              ),
                              _KpiItem(
                                label: 'Balance Neto',
                                value: DateFormatter.formatCurrency(
                                  local.balanceNeto,
                                ),
                                color: local.balanceNeto >= 0
                                    ? const Color(0xFF00D9A6)
                                    : const Color(0xFFEE5A6F),
                                icon: local.balanceNeto >= 0
                                    ? Icons.account_balance_wallet_rounded
                                    : Icons.account_balance_rounded,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // KPIs de días
                          _KpiRow(
                            items: [
                              _KpiItem(
                                label: 'Días Cobrados',
                                value: '$diasCobrados',
                                color: Colors.green,
                                icon: Icons.check_circle_rounded,
                              ),
                              _KpiItem(
                                label: 'Días Pendientes',
                                value: '$diasPendientes',
                                color: const Color(0xFFEE5A6F),
                                icon: Icons.cancel_rounded,
                              ),
                              _KpiItem(
                                label: 'Días Adelantados',
                                value:
                                    '${((local.saldoAFavor ?? 0) / ((local.cuotaDiaria ?? 0) > 0 ? local.cuotaDiaria! : 1)).floor()}',
                                color: const Color(0xFFFF9F43),
                                icon: Icons.fast_forward_rounded,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _KpiRow(
                            items: [
                              _KpiItem(
                                label: 'Total Recaudado',
                                value: DateFormatter.formatCurrency(
                                  totalRecaudado,
                                ),
                                color: const Color(0xFF6C63FF),
                                icon: Icons.payments_rounded,
                              ),
                              _KpiItem(
                                label: 'Total Registros',
                                value: '${combinedList.length}',
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                                icon: Icons.receipt_long_rounded,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // Filtros
                          Text(
                            'Historial de Cobros (Tiempo Real)',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 10),
                          _FiltroBar(
                            filtroActivo: _filtro,
                            onFiltro: (f) => setState(() => _filtro = f),
                            cobros: combinedList,
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                  // ── Lista de cobros ────────────────────────────────────────
                  if (filtered.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(
                          child: Text(
                            'No hay registros',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) =>
                            _CobroRow(cobro: filtered[index]),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ),
            );
          },
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }
}

// ── Widgets de soporte ────────────────────────────────────────────────────────

class _LocalInfoCard extends StatelessWidget {
  final Local local;
  const _LocalInfoCard({required this.local});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoFila('Representante', local.representante ?? '—'),
          _InfoFila('Teléfono', local.telefonoRepresentante ?? '—'),
          _InfoFila(
            'Cuota Diaria',
            DateFormatter.formatCurrency(local.cuotaDiaria),
          ),
          if (local.id != null) _InfoFila('ID', local.id!),
        ],
      ),
    );
  }
}

class _InfoFila extends StatelessWidget {
  final String label;
  final String value;
  const _InfoFila(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54), fontSize: 13),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiRow extends StatelessWidget {
  final List<_KpiItem> items;
  const _KpiRow({required this.items});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: items
          .map(
            (item) => Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _KpiCard(item: item),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _KpiItem {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const _KpiItem({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });
}

class _KpiCard extends StatelessWidget {
  final _KpiItem item;
  const _KpiCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: item.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: item.color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(item.icon, size: 16, color: item.color),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              item.value,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: item.color,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.label,
            style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _FiltroBar extends StatelessWidget {
  final String filtroActivo;
  final ValueChanged<String> onFiltro;
  final List<Cobro> cobros;

  const _FiltroBar({
    required this.filtroActivo,
    required this.onFiltro,
    required this.cobros,
  });

  @override
  Widget build(BuildContext context) {
    final opciones = [
      ('todos', 'Todos', cobros.length, Theme.of(context).colorScheme.onSurface),
      (
        'cobrado',
        'Cobrados',
        cobros.where((c) => c.estado == 'cobrado').length,
        Colors.green,
      ),
      (
        'pendiente',
        'Pendientes',
        cobros.where((c) => c.estado == 'pendiente').length,
        const Color(0xFFEE5A6F),
      ),
      (
        'abono_parcial',
        'Adelantados',
        cobros
            .where(
              (c) => c.estado == 'abono_parcial' || c.estado == 'adelantado',
            )
            .length,
        const Color(0xFFFF9F43),
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: opciones.map((o) {
          final (key, label, count, color) = o;
          final selected = filtroActivo == key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onFiltro(key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? color.withValues(alpha: 0.2)
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected ? color : Colors.transparent,
                  ),
                ),
                child: Text(
                  '$label ($count)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    color: selected ? color : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _CobroRow extends StatelessWidget {
  final Cobro cobro;
  const _CobroRow({required this.cobro});

  @override
  Widget build(BuildContext context) {
    final estado = cobro.estado ?? 'desconocido';
    final fecha = cobro.fecha;

    Color estadoColor;
    IconData estadoIcon;
    switch (estado) {
      case 'cobrado':
        estadoColor = Colors.green;
        estadoIcon = Icons.check_circle_rounded;
      case 'pendiente':
        estadoColor = const Color(0xFFEE5A6F);
        estadoIcon = Icons.cancel_rounded;
      case 'abono_parcial':
        estadoColor = const Color(0xFFFF9F43);
        estadoIcon = Icons.timelapse_rounded;
      case 'adelantado':
        estadoColor = const Color(0xFFFF9F43);
        estadoIcon = Icons.fast_forward_rounded;
      default:
        estadoColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7);
        estadoIcon = Icons.help_outline_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: estadoColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          // Estado icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: estadoColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(estadoIcon, color: estadoColor, size: 18),
          ),
          const SizedBox(width: 12),
          // Fecha
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fecha != null ? DateFormatter.formatDateTime(fecha) : '—',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                if (cobro.observaciones != null &&
                    cobro.observaciones!.isNotEmpty)
                  Text(
                    cobro.observaciones!,
                    style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
              ],
            ),
          ),
          // Monto y estado
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                DateFormatter.formatCurrency(
                  estado == 'pendiente' ? cobro.saldoPendiente : cobro.monto,
                ),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: estado == 'pendiente' ? estadoColor : Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: estadoColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  estado == 'abono_parcial'
                      ? 'abono'
                      : estado == 'adelantado'
                      ? 'adelantado'
                      : estado,
                  style: TextStyle(
                    fontSize: 9,
                    color: estadoColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}