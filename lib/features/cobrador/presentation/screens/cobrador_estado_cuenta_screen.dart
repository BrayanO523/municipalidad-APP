import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/di/providers.dart';
import '../../../../core/platform/web_downloader/web_downloader.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/reporte_pdf_generator.dart';
import '../../../cobros/domain/entities/cobro.dart';
import '../../../locales/domain/entities/local.dart';
import '../../../mercados/domain/entities/mercado.dart';
import '../../../../core/utils/visual_debt_utils.dart';

/// Pantalla de Estado de Cuenta del locatario — vista del Cobrador.
/// Muestra el balance financiero completo y el historial de cobros
/// de un local específico, con acceso rápido a llamar al representante.
class CobradorEstadoCuentaScreen extends ConsumerStatefulWidget {
  final Local local;

  const CobradorEstadoCuentaScreen({super.key, required this.local});

  @override
  ConsumerState<CobradorEstadoCuentaScreen> createState() =>
      _CobradorEstadoCuentaScreenState();
}

class _CobradorEstadoCuentaScreenState
    extends ConsumerState<CobradorEstadoCuentaScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _llamar(String? telefono) async {
    if (telefono == null || telefono.isEmpty) return;
    final uri = Uri.parse('tel:$telefono');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localAsync = ref.watch(localStreamProvider(widget.local.id ?? ''));
    final cobrosAsync = ref.watch(
      localCobrosStreamProvider(widget.local.id ?? ''),
    );
    final mercados = ref.watch(mercadosProvider).value ?? [];

    return localAsync.when(
      data: (local) {
        if (local == null) {
          return const Scaffold(
            body: Center(child: Text('Local no encontrado')),
          );
        }
        return cobrosAsync.when(
          data: (cobrosList) =>
              _buildContent(context, local, cobrosList, mercados),
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

  Widget _buildContent(
    BuildContext context,
    Local local,
    List<Cobro> cobrosList,
    List<Mercado> mercados,
  ) {
    // --- Lógica Visual Centralizada ---
    final hoyVirtual = VisualDebtUtils.generarHoyPendienteVirtual(
      local: local,
      actualCobros: cobrosList,
    );
    final adelantadosVirtuales = VisualDebtUtils.generarAdelantadosVirtuales(
      local: local,
      actualCobros: cobrosList,
    );

    final List<Cobro> combinedList = [
      ...cobrosList,
      ...adelantadosVirtuales,
      if (hoyVirtual != null) hoyVirtual,
    ];

    combinedList.sort(
      (a, b) => (b.fecha ?? DateTime(0)).compareTo(a.fecha ?? DateTime(0)),
    );

    final deudaVisual = VisualDebtUtils.calcularDeudaVisual(local, cobrosList);
    final balanceVisual = VisualDebtUtils.calcularBalanceNetoVisual(local, cobrosList);
    final numAdelantados = adelantadosVirtuales.length;

    final cobrados = combinedList.where((c) => c.estado == 'cobrado').toList();
    final pendientes = combinedList.where((c) => c.estado == 'pendiente').toList();

    return Scaffold(
      backgroundColor: const Color(0xFF12131A),
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            backgroundColor: const Color(0xFF1A1B27),
            expandedHeight: 240,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: _Header(
                local: local,
                deuda: deudaVisual,
                saldo: local.saldoAFavor ?? 0,
                balance: balanceVisual,
                numAdelantados: numAdelantados,
                onLlamar: () => _llamar(local.telefonoRepresentante),
              ),
            ),
            leading: const BackButton(),
            title: Text(
              local.nombreSocial ?? 'Estado de Cuenta',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
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
              if (local.telefonoRepresentante != null &&
                  local.telefonoRepresentante!.isNotEmpty)
                IconButton(
                  onPressed: () => _llamar(local.telefonoRepresentante),
                  icon: const Icon(Icons.call_rounded),
                  tooltip: 'Llamar al representante',
                ),
              const SizedBox(width: 4),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFF6C63FF),
              labelColor: const Color(0xFF6C63FF),
              unselectedLabelColor: Colors.white54,
              labelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              tabs: [
                Tab(text: 'Todos (${combinedList.length})'),
                Tab(text: 'Cobrados (${cobrados.length})'),
                Tab(text: 'Pendientes (${pendientes.length})'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _CobrosList(cobros: combinedList, local: local),
            _CobrosList(cobros: cobrados, local: local),
            _CobrosList(cobros: pendientes, local: local),
          ],
        ),
      ),
    );
  }
}

// ── Header expandible ─────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final Local local;
  final num deuda;
  final num saldo;
  final num balance;
  final int numAdelantados;
  final VoidCallback onLlamar;

  const _Header({
    required this.local,
    required this.deuda,
    required this.saldo,
    required this.balance,
    required this.numAdelantados,
    required this.onLlamar,
  });

  @override
  Widget build(BuildContext context) {
    final tieneDeuda = deuda > 0;
    final tieneSaldo = saldo > 0;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1B27), Color(0xFF0E0F18)],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 70, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info básica con botón de llamada
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar con inicial
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFF00D9A6)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    (local.nombreSocial ?? 'L').substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      local.representante ?? '—',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    if (local.telefonoRepresentante != null &&
                        local.telefonoRepresentante!.isNotEmpty)
                      GestureDetector(
                        onTap: onLlamar,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.call_rounded,
                              size: 12,
                              color: Color(0xFF00D9A6),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              local.telefonoRepresentante!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF00D9A6),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      'Cuota: ${DateFormatter.formatCurrency(local.cuotaDiaria)}/día',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
              // Badge de estado global
              _EstadoBadge(tieneDeuda: tieneDeuda, tieneSaldo: tieneSaldo),
            ],
          ),
          const SizedBox(height: 8),
          // KPIs financieros en fila
          Row(
            children: [
              _MiniKpi(
                label: 'Balance',
                value: DateFormatter.formatCurrency(balance),
                color: balance >= 0
                    ? const Color(0xFF00D9A6)
                    : const Color(0xFFEE5A6F),
                icon: Icons.account_balance_wallet_rounded,
              ),
              const SizedBox(width: 8),
              _MiniKpi(
                label: 'Deuda',
                value: DateFormatter.formatCurrency(deuda),
                color: deuda > 0 ? const Color(0xFFEE5A6F) : Colors.white38,
                icon: Icons.warning_amber_rounded,
              ),
              const SizedBox(width: 8),
              _MiniKpi(
                label: 'Días Adel.',
                value: '$numAdelantados',
                color: numAdelantados > 0
                    ? const Color(0xFFFF9F43)
                    : Colors.white38,
                icon: Icons.fast_forward_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EstadoBadge extends StatelessWidget {
  final bool tieneDeuda;
  final bool tieneSaldo;

  const _EstadoBadge({required this.tieneDeuda, required this.tieneSaldo});

  @override
  Widget build(BuildContext context) {
    if (tieneDeuda) {
      return _Badge(
        label: 'Con Deuda',
        color: const Color(0xFFEE5A6F),
        icon: Icons.warning_rounded,
      );
    }
    if (tieneSaldo) {
      return _Badge(
        label: 'Con Crédito',
        color: const Color(0xFF00D9A6),
        icon: Icons.savings_rounded,
      );
    }
    return _Badge(
      label: 'Al Día',
      color: Colors.green,
      icon: Icons.check_circle_rounded,
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _Badge({required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniKpi extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _MiniKpi({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 8, color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Lista de cobros ───────────────────────────────────────────────────────────

class _CobrosList extends StatelessWidget {
  final List<Cobro> cobros;
  final Local local;

  const _CobrosList({required this.cobros, required this.local});

  @override
  Widget build(BuildContext context) {
    if (cobros.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_rounded, size: 48, color: Colors.white24),
            SizedBox(height: 12),
            Text(
              'Sin registros',
              style: TextStyle(color: Colors.white38, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: cobros.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _CobroTile(cobro: cobros[i], local: local),
    );
  }
}

class _CobroTile extends ConsumerWidget {
  final Cobro cobro;
  final Local local;

  const _CobroTile({required this.cobro, required this.local});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = cobro.estado ?? 'desconocido';

    final Color color;
    final IconData icon;
    final String label;

    switch (estado) {
      case 'cobrado':
        color = Colors.green;
        icon = Icons.check_circle_rounded;
        label = 'Cobrado';
      case 'pendiente':
        color = const Color(0xFFEE5A6F);
        icon = Icons.cancel_rounded;
        label = 'Pendiente';
      case 'abono_parcial':
        color = const Color(0xFFFF9F43);
        icon = Icons.timelapse_rounded;
        label = 'Abono';
      case 'adelantado':
        color = const Color(0xFFFF9F43);
        icon = Icons.fast_forward_rounded;
        label = 'Adelantado';
      default:
        color = Colors.white38;
        icon = Icons.help_outline_rounded;
        label = estado;
    }

    final esPendiente = estado == 'pendiente';
    final esAdelantado = estado == 'adelantado';
    final monto = esPendiente ? cobro.saldoPendiente : cobro.monto;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _mostrarDetalles(context, ref, color),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: esAdelantado
                ? const Color(0xFF1E1F2E)
                : const Color(0xFF1A1B27),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: color.withValues(alpha: esAdelantado ? 0.3 : 0.15),
              width: esAdelantado ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cobro.fecha != null
                          ? DateFormatter.formatDateTime(cobro.fecha!)
                          : '—',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                    if (cobro.observaciones != null &&
                        cobro.observaciones!.isNotEmpty)
                      Text(
                        cobro.observaciones!,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white38,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    DateFormatter.formatCurrency(monto),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: esPendiente ? color : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 9,
                        color: color,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _mostrarDetalles(
    BuildContext context,
    WidgetRef ref,
    Color colorEstado,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1B27),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            top: 24,
            left: 20,
            right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Detalles del Cobro',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _DetalleFila(
                label: 'Fecha',
                valor: cobro.fecha != null
                    ? DateFormatter.formatDateTime(cobro.fecha!)
                    : '-',
              ),
              _DetalleFila(
                label: 'Monto Pagado',
                valor: DateFormatter.formatCurrency(cobro.monto),
              ),
              _DetalleFila(
                label: 'Saldo Pendiente Posterior',
                valor: DateFormatter.formatCurrency(cobro.saldoPendiente),
              ),
              if (cobro.observaciones != null &&
                  cobro.observaciones!.isNotEmpty)
                _DetalleFila(
                  label: 'Observaciones',
                  valor: cobro.observaciones!,
                ),
              if (cobro.correlativo != null)
                _DetalleFila(
                  label: 'Correlativo',
                  valor: '${cobro.correlativo}',
                ),
              const SizedBox(height: 24),
              // Solo mostrar el botón de impresión si no es un registro virtual adelantado
              if (cobro.estado != 'adelantado' &&
                  !(cobro.id?.startsWith('VIRTUAL') ?? false))
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      _reimprimirBoleta(context, ref);
                    },
                    icon: const Icon(Icons.print_rounded),
                    label: const Text(
                      'Reimprimir Boleta',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorEstado.withValues(alpha: 0.8),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              if (cobro.estado != 'adelantado' &&
                  !(cobro.id?.startsWith('VIRTUAL') ?? false)) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      _compartirPdf(context, ref);
                    },
                    icon: const Icon(
                      Icons.share_rounded,
                      color: Colors.greenAccent,
                    ),
                    label: const Text(
                      'Compartir por WhatsApp (PDF)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.greenAccent,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.greenAccent),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ] else
                const Center(
                  child: Text(
                    'Este es un registro generado automáticamente y no posee boleta física.',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _compartirPdf(BuildContext context, WidgetRef ref) async {
    final user = ref.read(currentUsuarioProvider).value;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Generando PDF...'),
        duration: Duration(seconds: 1),
      ),
    );

    // --- OBTENER DATOS MAESTROS ---
    final municipalidadRepo = ref.read(municipalidadRepositoryProvider);
    final mercadoRepo = ref.read(mercadoRepositoryProvider);

    final muni = await municipalidadRepo.obtenerPorId(
      cobro.municipalidadId ?? '',
    );
    final merc = await mercadoRepo.obtenerPorId(cobro.mercadoId ?? '');

    final municipalidadNombre = muni?.nombre ?? 'MUNICIPALIDAD';
    final mercadoNombre = merc?.nombre;
    // -----------------------------

    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80, // Formato térmico de 80mm
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Text(
                (municipalidadNombre).toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              if (mercadoNombre != null)
                pw.Text(
                  mercadoNombre.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Comprobante de Cobro',
                style: const pw.TextStyle(fontSize: 14),
              ),
              pw.SizedBox(height: 12),
              pw.Divider(),
              pw.SizedBox(height: 8),
              if (local.nombreSocial != null) ...[
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text('Local: ${local.nombreSocial}'),
                ),
              ],
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  'Fecha: ${cobro.fecha != null ? DateFormatter.formatDateTime(cobro.fecha!) : "-"}',
                ),
              ),
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text('Cobrador: ${user?.nombre ?? "Desconocido"}'),
              ),
              if (cobro.correlativo != null)
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text('Boleta N°: ${cobro.correlativo}'),
                ),
              pw.SizedBox(height: 8),
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Monto Pagado:'),
                  pw.Text(
                    DateFormatter.formatCurrency(cobro.monto),
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              if (cobro.saldoPendiente != null && cobro.saldoPendiente! > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Deuda Actual:'),
                    pw.Text(DateFormatter.formatCurrency(cobro.saldoPendiente)),
                  ],
                ),
              pw.SizedBox(height: 8),
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Text(
                '*** GRACIAS POR SU PAGO ***',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'Comprobante_Municipalidad_${cobro.correlativo ?? "Gen"}.pdf',
    );
  }

  Future<void> _reimprimirBoleta(BuildContext context, WidgetRef ref) async {
    final printer = ref.read(printerServiceProvider);

    // El cobrador actual
    final user = ref.read(currentUsuarioProvider).value;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Re-imprimiendo boleta N°${cobro.correlativo ?? "-"}...'),
        duration: const Duration(seconds: 2),
      ),
    );

    final double montoSeguro = cobro.monto?.toDouble() ?? 0.0;
    final double saldoPendienteRaw = cobro.saldoPendiente?.toDouble() ?? 0.0;
    final double saldoPendienteSeguro = saldoPendienteRaw > 0
        ? saldoPendienteRaw
        : 0.0;

    // --- OBTENER DATOS MAESTROS ---
    final municipalidadRepo = ref.read(municipalidadRepositoryProvider);
    final mercadoRepo = ref.read(mercadoRepositoryProvider);

    final muni = await municipalidadRepo.obtenerPorId(
      cobro.municipalidadId ?? '',
    );
    final merc = await mercadoRepo.obtenerPorId(cobro.mercadoId ?? '');

    final municipalidadNombre = muni?.nombre ?? 'MUNICIPALIDAD';
    final mercadoNombre = merc?.nombre;
    // -----------------------------

    final impreso = await printer.printReceipt(
      empresa: municipalidadNombre,
      mercado: mercadoNombre,
      local: local.nombreSocial ?? 'Local',
      monto: montoSeguro,
      fecha: cobro.fecha ?? DateTime.now(),
      saldoPendiente: saldoPendienteSeguro,
      saldoAFavor: null,
      cobrador: user?.nombre ?? 'Desconocido',
      numeroBoleta: cobro.numeroBoletaFmt,
      anioCorrelativo: cobro.anioCorrelativo ?? DateTime.now().year,
    );

    if (!impreso && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Comprobante no impreso. Revisa conexión de la impresora rápida.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }
}

class _DetalleFila extends StatelessWidget {
  final String label;
  final String valor;

  const _DetalleFila({required this.label, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text(
            valor,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
