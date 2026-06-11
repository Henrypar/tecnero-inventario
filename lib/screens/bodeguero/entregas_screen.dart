// Pantalla de solicitudes pendientes, despacho y rechazo operativo.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';
import '../../services/providers.dart';
import '../../models/models.dart' as models;
import '../../widgets/responsive.dart';

class EntregasScreen extends ConsumerStatefulWidget {
  const EntregasScreen({super.key});

  @override
  ConsumerState<EntregasScreen> createState() => _EntregasScreenState();
}

class _EntregasScreenState extends ConsumerState<EntregasScreen> {
  bool _procesando = false;
  final _fmtDate = DateFormat('dd/MM/yyyy HH:mm');

  Future<void> _recargarPendientes() async {
    ref.invalidate(solicitudesPendientesBodegaProvider);
    await ref.read(solicitudesPendientesBodegaProvider.future);
  }

  Future<void> _entregar(models.Solicitud solicitud) async {
    final confirma = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar entrega'),
        content: Text(
          '¿Confirmas que entregaste los materiales de la solicitud ${solicitud.numero}?\n\nEl stock se descontará automáticamente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, confirmar entrega'),
          ),
        ],
      ),
    );

    if (confirma != true) return;

    setState(() => _procesando = true);

    try {
      await ref.read(apiServiceProvider).marcarEntregada(solicitud.id);

      ref.invalidate(solicitudesPendientesBodegaProvider);
      ref.invalidate(solicitudesPendientesProvider);
      ref.invalidate(solicitudesEntregadasProvider);
      ref.invalidate(solicitudesHistorialBodegaProvider);
      ref.invalidate(materialesProvider);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Entrega de ${solicitud.numero} registrada'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _procesando = false);
      }
    }
  }

  Future<void> _rechazar(models.Solicitud solicitud) async {
    // El bodeguero puede rechazar, pero siempre dejando motivo escrito para
    // trazabilidad.
    final motivo = await showDialog<String>(
      context: context,
      builder: (ctx) => _MotivoRechazoDialog(numeroSolicitud: solicitud.numero),
    );

    if (motivo == null || motivo.trim().isEmpty) return;

    setState(() => _procesando = true);

    try {
      final usuarioNombre =
          ref.read(apiServiceProvider).currentUser?.nombre ?? 'Bodega';
      await ref.read(apiServiceProvider).rechazarSolicitud(
            solicitud.id,
            usuarioNombre,
            motivo.trim(),
          );

      ref.invalidate(solicitudesPendientesBodegaProvider);
      ref.invalidate(solicitudesPendientesProvider);
      ref.invalidate(solicitudesEntregadasProvider);
      ref.invalidate(solicitudesHistorialBodegaProvider);
      ref.invalidate(notificacionesProvider);
      ref.invalidate(contadorNotificacionesNoLeidasProvider);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Solicitud ${solicitud.numero} rechazada'),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _procesando = false);
      }
    }
  }

  Future<void> _abrirDespachoDirecto() async {
    final creado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _DespachoDirectoDialog(),
    );

    if (creado != true) return;

    ref.invalidate(solicitudesPendientesBodegaProvider);
    ref.invalidate(solicitudesPendientesProvider);
    ref.invalidate(solicitudesEntregadasProvider);
    ref.invalidate(solicitudesHistorialBodegaProvider);
    ref.invalidate(materialesProvider);
    ref.invalidate(notificacionesProvider);
    ref.invalidate(contadorNotificacionesNoLeidasProvider);
  }

  @override
  Widget build(BuildContext context) {
    final pendientesAsync = ref.watch(solicitudesPendientesBodegaProvider);
    final materialesAsync = ref.watch(materialesProvider);
    final isMobile = Responsive.isMobile(context);

    return Scaffold(
      backgroundColor: TecneroTheme.grisClaro,
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: Responsive.headerPadding(context),
            child: Wrap(
              spacing: 12,
              runSpacing: 10,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: isMobile ? MediaQuery.sizeOf(context).width - 88 : 360,
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Despachos pendientes',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Pedidos diarios recibidos directamente por bodega',
                        style: TextStyle(
                          fontSize: 13,
                          color: TecneroTheme.textoSecundario,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _recargarPendientes,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Recargar despachos',
                ),
                pendientesAsync.when(
                  data: (lista) => lista.isNotEmpty
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${lista.length} para entregar',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      : const SizedBox(),
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            color: const Color(0xFFF8FAFC),
            padding: EdgeInsets.fromLTRB(
              isMobile ? 12 : 20,
              10,
              isMobile ? 12 : 20,
              10,
            ),
            child: const _DespachosResumenBar(),
          ),
          Expanded(
            child: pendientesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _EntregasError(
                error: e,
                onRetry: () {
                  ref.invalidate(usuarioActualProvider);
                  ref.invalidate(solicitudesPendientesBodegaProvider);
                  ref.invalidate(materialesProvider);
                },
                onLogin: () async {
                  await ref.read(apiServiceProvider).logout();
                  ref.invalidate(usuarioActualProvider);
                  ref.invalidate(solicitudesPendientesBodegaProvider);
                  if (context.mounted) context.go('/login');
                },
              ),
              data: (solicitudes) {
                if (solicitudes.isEmpty) {
                  return const _EmptyEntregas();
                }

                return materialesAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Text(
                      'Error cargando stock: $e',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  data: (materiales) {
                    final materialesMap = {
                      for (final m in materiales) m.id: m,
                    };

                    return ListView.builder(
                      padding: Responsive.pagePadding(context),
                      itemCount: solicitudes.length,
                      itemBuilder: (ctx, i) {
                        final solicitud = solicitudes[i];

                        return _EntregaCard(
                          solicitud: solicitud,
                          materialesMap: materialesMap,
                          fmtDate: _fmtDate,
                          procesando: _procesando,
                          onEntregar: () => _entregar(solicitud),
                          onRechazar: () => _rechazar(solicitud),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirDespachoDirecto,
        icon: const Icon(Icons.add_task_outlined),
        label: const Text('Despacho directo'),
      ),
    );
  }
}

class _DespachosResumenBar extends ConsumerWidget {
  const _DespachosResumenBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendientesAsync = ref.watch(solicitudesPendientesBodegaProvider);
    final entregadasAsync = ref.watch(solicitudesEntregadasProvider);
    final historialAsync = ref.watch(solicitudesHistorialBodegaProvider);

    final loading =
        pendientesAsync.isLoading || entregadasAsync.isLoading || historialAsync.isLoading;
    final error = pendientesAsync.hasError
        ? pendientesAsync.error
        : entregadasAsync.hasError
            ? entregadasAsync.error
            : historialAsync.error;

    if (loading) {
      return const LinearProgressIndicator(minHeight: 3);
    }

    if (error != null) {
      return Text(
        'No se pudo cargar el resumen de despachos: $error',
        style: const TextStyle(
          fontSize: 12,
          color: TecneroTheme.textoSecundario,
        ),
      );
    }

    final pendientes = pendientesAsync.asData?.value ?? const [];
    final entregadas = entregadasAsync.asData?.value ?? const [];
    final historial = historialAsync.asData?.value ?? const [];
    final rechazadas = historial.where((s) => s.estado == 'rechazada').length;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ResumenPill(
              label: 'Pendientes',
              value: '${pendientes.length}',
              color: const Color(0xFF2563EB),
            ),
            _ResumenPill(
              label: 'Entregadas',
              value: '${entregadas.length}',
              color: const Color(0xFF059669),
            ),
            _ResumenPill(
              label: 'Rechazadas',
              value: '$rechazadas',
              color: const Color(0xFFB91C1C),
            ),
          ],
        ),
        TextButton.icon(
          onPressed: () => context.go('/bodeguero/historial'),
          icon: const Icon(Icons.history, size: 18),
          label: const Text('Ver historial'),
        ),
      ],
    );
  }
}

class _ResumenPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ResumenPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _EntregaCard extends StatefulWidget {
  final models.Solicitud solicitud;
  final Map<String, models.Material> materialesMap;
  final DateFormat fmtDate;
  final bool procesando;
  final VoidCallback onEntregar;
  final VoidCallback onRechazar;

  const _EntregaCard({
    required this.solicitud,
    required this.materialesMap,
    required this.fmtDate,
    required this.procesando,
    required this.onEntregar,
    required this.onRechazar,
  });

  @override
  State<_EntregaCard> createState() => _EntregaCardState();
}

class _EntregaCardState extends State<_EntregaCard> {
  bool _expandido = true;

  bool get _stockSuficiente {
    for (final detalle in widget.solicitud.detalles) {
      final material = widget.materialesMap[detalle.materialId];

      if (material == null) return false;
      if (material.stockActual < detalle.cantidad) return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.solicitud;
    final stockSuficiente = _stockSuficiente;
    final isMobile = Responsive.isMobile(context);
    final double actionWidth =
        isMobile ? MediaQuery.sizeOf(context).width - 64 : 240;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expandido = !_expandido),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(12),
            ),
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: stockSuficiente
                          ? const Color(0xFFD1FAE5)
                          : const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      stockSuficiente
                          ? Icons.inventory_2_outlined
                          : Icons.warning_amber_outlined,
                      size: 18,
                      color: stockSuficiente
                          ? const Color(0xFF059669)
                          : const Color(0xFFB91C1C),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              s.numero,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: TecneroTheme.azulOscuro,
                              ),
                            ),
                            EstadoBadge(estado: s.estado),
                            _StockBadge(ok: stockSuficiente),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${s.solicitanteNombre} · ${s.lineaNombre}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: TecneroTheme.textoSecundario,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                        Text(
                          'Solicitado: ${widget.fmtDate.format(s.fecha)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: TecneroTheme.textoSecundario,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expandido ? Icons.expand_less : Icons.expand_more,
                    color: TecneroTheme.textoSecundario,
                  ),
                ],
              ),
            ),
          ),
          if (_expandido) ...[
            const Divider(height: 1),
            Padding(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AvisoStock(stockSuficiente: stockSuficiente),
                  const SizedBox(height: 12),
                  _MaterialesStockTable(
                    detalles: s.detalles,
                    materialesMap: widget.materialesMap,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      // Accion nueva: rechazo operativo con motivo obligatorio.
                      SizedBox(
                        width: actionWidth,
                        child: OutlinedButton.icon(
                          onPressed:
                              widget.procesando ? null : widget.onRechazar,
                          icon: const Icon(Icons.close_outlined, size: 18),
                          label: const Text('Rechazar solicitud'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFB91C1C),
                            side: const BorderSide(color: Color(0xFFFCA5A5)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      // Confirmacion normal de despacho cuando hay stock
                      // suficiente para completar toda la solicitud.
                      SizedBox(
                        width: actionWidth,
                        child: ElevatedButton.icon(
                          onPressed: widget.procesando || !stockSuficiente
                              ? null
                              : widget.onEntregar,
                          icon: widget.procesando
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_circle_outline,
                                  size: 18),
                          label: Text(
                            stockSuficiente
                                ? 'Confirmar entrega'
                                : 'No se puede entregar: stock insuficiente',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            disabledBackgroundColor: Colors.grey.shade300,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MotivoRechazoDialog extends StatefulWidget {
  final String numeroSolicitud;

  const _MotivoRechazoDialog({
    required this.numeroSolicitud,
  });

  @override
  State<_MotivoRechazoDialog> createState() => _MotivoRechazoDialogState();
}

class _MotivoRechazoDialogState extends State<_MotivoRechazoDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      // Diálogo simple para capturar el motivo del rechazo sin agregar
      // complejidad visual.
      title: const Text('Rechazar solicitud'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Indica el motivo para rechazar la solicitud ${widget.numeroSolicitud}.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ctrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Motivo',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            final motivo = _ctrl.text.trim();
            if (motivo.isEmpty) return;
            Navigator.pop(context, motivo);
          },
          child: const Text('Rechazar'),
        ),
      ],
    );
  }
}

class _AvisoStock extends StatelessWidget {
  final bool stockSuficiente;

  const _AvisoStock({
    required this.stockSuficiente,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color:
            stockSuficiente ? const Color(0xFFECFDF5) : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: stockSuficiente
              ? const Color(0xFFA7F3D0)
              : const Color(0xFFFCA5A5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            stockSuficiente ? Icons.info_outline : Icons.warning_amber_outlined,
            size: 14,
            color: stockSuficiente
                ? const Color(0xFF047857)
                : const Color(0xFFB91C1C),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              stockSuficiente
                  ? 'Stock suficiente. Al confirmar, se descontará automáticamente.'
                  : 'Hay materiales sin stock suficiente. Revisa la columna "Quedaría".',
              style: TextStyle(
                fontSize: 11,
                color: stockSuficiente
                    ? const Color(0xFF047857)
                    : const Color(0xFF991B1B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MaterialesStockTable extends StatelessWidget {
  final List<models.DetalleSolicitud> detalles;
  final Map<String, models.Material> materialesMap;

  const _MaterialesStockTable({
    required this.detalles,
    required this.materialesMap,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    if (detalles.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: TecneroTheme.grisClaro,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Esta solicitud no tiene materiales registrados.',
          style: TextStyle(
            fontSize: 12,
            color: TecneroTheme.textoSecundario,
          ),
        ),
      );
    }

    if (isMobile) {
      return Column(
        children: detalles.map((d) {
          final material = materialesMap[d.materialId];
          final stockActual = material?.stockActual;
          final restante =
              stockActual == null ? null : stockActual - d.cantidad;
          final suficiente = restante != null && restante >= 0;

          return _StockMaterialCard(
            nombre: d.materialNombre,
            codigo: d.materialCodigo,
            unidad: d.unidadMedida,
            solicitado: d.cantidad,
            stockActual: stockActual,
            restante: restante,
            suficiente: suficiente,
          );
        }).toList(),
      );
    }

    return Table(
      columnWidths: const {
        0: FlexColumnWidth(3),
        1: FixedColumnWidth(90),
        2: FixedColumnWidth(100),
        3: FixedColumnWidth(100),
        4: FixedColumnWidth(70),
      },
      children: [
        TableRow(
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: TecneroTheme.grisBorde),
            ),
          ),
          children:
              ['Material', 'Solicitado', 'Stock actual', 'Quedaría', 'Unidad']
                  .map(
                    (h) => Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 4,
                      ),
                      child: Text(
                        h,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: TecneroTheme.textoSecundario,
                        ),
                      ),
                    ),
                  )
                  .toList(),
        ),
        ...detalles.map((d) {
          final material = materialesMap[d.materialId];
          final stockActual = material?.stockActual;
          final restante =
              stockActual == null ? null : stockActual - d.cantidad;
          final suficiente = restante != null && restante >= 0;

          return TableRow(
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: TecneroTheme.grisBorde,
                  width: 0.5,
                ),
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 4,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.materialNombre,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (d.materialCodigo.isNotEmpty)
                      Text(
                        d.materialCodigo,
                        style: const TextStyle(
                          fontSize: 10,
                          color: TecneroTheme.textoSecundario,
                        ),
                      ),
                  ],
                ),
              ),
              _TableText(_formatCantidad(d.cantidad)),
              _TableText(
                stockActual == null
                    ? 'No encontrado'
                    : _formatCantidad(stockActual),
                color: stockActual == null
                    ? const Color(0xFFB91C1C)
                    : TecneroTheme.textoPrimario,
              ),
              _TableText(
                restante == null ? '—' : _formatCantidad(restante),
                color: suficiente
                    ? const Color(0xFF047857)
                    : const Color(0xFFB91C1C),
                bold: true,
              ),
              _TableText(d.unidadMedida),
            ],
          );
        }),
      ],
    );
  }
}

class _TableText extends StatelessWidget {
  final String text;
  final Color? color;
  final bool bold;

  const _TableText(
    this.text, {
    this.color,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 8,
        horizontal: 4,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _StockMaterialCard extends StatelessWidget {
  final String nombre;
  final String codigo;
  final String unidad;
  final double solicitado;
  final double? stockActual;
  final double? restante;
  final bool suficiente;

  const _StockMaterialCard({
    required this.nombre,
    required this.codigo,
    required this.unidad,
    required this.solicitado,
    required this.stockActual,
    required this.restante,
    required this.suficiente,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: TecneroTheme.grisBorde),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            nombre,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (codigo.isNotEmpty)
            Text(
              codigo,
              style: const TextStyle(
                fontSize: 10,
                color: TecneroTheme.textoSecundario,
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _MiniChip('Solicitado', '${_formatCantidad(solicitado)} $unidad'),
              _MiniChip(
                'Stock',
                stockActual == null
                    ? 'No encontrado'
                    : _formatCantidad(stockActual!),
                danger: stockActual == null,
              ),
              _MiniChip(
                'Quedaría',
                restante == null ? '—' : _formatCantidad(restante!),
                danger: !suficiente,
                success: suficiente,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  final String value;
  final bool danger;
  final bool success;

  const _MiniChip(
    this.label,
    this.value, {
    this.danger = false,
    this.success = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger
        ? const Color(0xFFFEE2E2)
        : success
            ? const Color(0xFFD1FAE5)
            : TecneroTheme.grisClaro;

    final textColor = danger
        ? const Color(0xFF991B1B)
        : success
            ? const Color(0xFF047857)
            : TecneroTheme.textoPrimario;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }
}

class _StockBadge extends StatelessWidget {
  final bool ok;

  const _StockBadge({
    required this.ok,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: ok ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        ok ? 'STOCK OK' : 'STOCK BAJO',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: ok ? const Color(0xFF047857) : const Color(0xFFB91C1C),
        ),
      ),
    );
  }
}

class _DespachoDirectoDialog extends ConsumerStatefulWidget {
  const _DespachoDirectoDialog();

  @override
  ConsumerState<_DespachoDirectoDialog> createState() =>
      _DespachoDirectoDialogState();
}

class _DespachoItem {
  final models.Material material;
  double cantidad;

  _DespachoItem({
    required this.material,
    required this.cantidad,
  });
}

class _DespachoDirectoDialogState
    extends ConsumerState<_DespachoDirectoDialog> {
  final _obsCtrl = TextEditingController();
  final List<_DespachoItem> _items = [];

  models.Usuario? _operario;
  models.LineaProduccion? _linea;

  bool _guardando = false;
  bool _cargandoSugeridos = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _obsCtrl.dispose();
    super.dispose();
  }

  String _normalizarTexto(String value) {
    return value
        .toLowerCase()
        .trim()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ä', 'a')
        .replaceAll('ë', 'e')
        .replaceAll('ï', 'i')
        .replaceAll('ö', 'o')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n');
  }

  String _categoriaLabel(models.Material m) {
    final c = _normalizarTexto(m.codigo);
    final n = _normalizarTexto(m.nombre);

    if (c.startsWith('a-segu') ||
        n.contains('guante') ||
        n.contains('careta') ||
        n.contains('mascarilla') ||
        n.contains('gafa') ||
        n.contains('monogafa') ||
        n.contains('mandil') ||
        n.contains('tapones') ||
        n.contains('protector') ||
        n.contains('vidrio')) {
      return 'EPP';
    }

    if (c.startsWith('r-matl') ||
        n.contains('suelda 6011') ||
        n.contains('suelda 7018') ||
        n.contains('cemento de contacto')) {
      return 'Mantenimiento';
    }

    return 'Producción';
  }

  Color _categoriaColor(String cat) {
    switch (cat) {
      case 'EPP':
        return const Color(0xFFFFF1B8);
      case 'Mantenimiento':
        return const Color(0xFFD9F7BE);
      default:
        return const Color(0xFFE5E7EB);
    }
  }

  Future<void> _abrirSelectorMateriales(
      List<models.Material> materiales) async {
    final seleccionados = await showDialog<List<models.Material>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SelectorMaterialesDespachoDialog(
        materiales: materiales,
        seleccionInicial: _items.map((e) => e.material).toList(),
        categoriaLabel: _categoriaLabel,
        categoriaColor: _categoriaColor,
        normalizarTexto: _normalizarTexto,
      ),
    );

    if (seleccionados == null) return;

    final nuevos = <_DespachoItem>[];

    for (final material in seleccionados) {
      final existente = _items.where((i) => i.material.id == material.id);

      if (existente.isNotEmpty) {
        nuevos.add(existente.first);
      } else {
        nuevos.add(_DespachoItem(material: material, cantidad: 1));
      }
    }

    setState(() {
      _items
        ..clear()
        ..addAll(nuevos);
      _error = null;
      _info = null;
    });
  }

  Future<void> _cargarSugeridos(models.LineaProduccion linea) async {
    if (_cargandoSugeridos) return;

    setState(() {
      _cargandoSugeridos = true;
      _error = null;
      _info = null;
    });

    try {
      final sugeridos =
          await ref.read(apiServiceProvider).getMaterialesPorLinea(linea.id);

      if (!mounted || _linea?.id != linea.id) return;

      if (sugeridos.isEmpty) {
        setState(() {
          _items.clear();
          _info =
              'Esta línea todavía no tiene materiales asociados. Puedes seleccionarlos manualmente.';
        });
        return;
      }

      final nuevos = <_DespachoItem>[];
      final usados = <String>{};

      for (final sugerido in sugeridos) {
        final material = sugerido.material;
        if (!usados.add(material.id)) continue;

        nuevos.add(
          _DespachoItem(
            material: material,
            cantidad:
                sugerido.cantidadSugerida <= 0 ? 1 : sugerido.cantidadSugerida,
          ),
        );
      }

      setState(() {
        _items
          ..clear()
          ..addAll(nuevos);
        _info =
            'Se cargaron ${nuevos.length} materiales sugeridos para ${linea.nombre}.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar los sugeridos: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _cargandoSugeridos = false);
      }
    }
  }

  bool get _stockValido {
    if (_items.isEmpty) return false;

    for (final item in _items) {
      if (item.cantidad <= 0) return false;
      if (item.cantidad > item.material.stockActual) return false;
    }

    return true;
  }

  Future<void> _guardar() async {
    if (_operario == null || _linea == null || _items.isEmpty) {
      setState(
        () => _error = 'Selecciona colaborador, línea y al menos un material',
      );
      return;
    }

    for (final item in _items) {
      if (item.cantidad <= 0) {
        setState(() => _error = 'Todas las cantidades deben ser mayores a 0');
        return;
      }

      if (item.cantidad > item.material.stockActual) {
        setState(
          () => _error =
              'Stock insuficiente para ${item.material.nombre}. Stock actual: ${_formatCantidad(item.material.stockActual)}',
        );
        return;
      }
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      await ref.read(apiServiceProvider).crearDespachoBodega(
            solicitanteId: _operario!.id,
            solicitanteNombre: _operario!.nombre,
            lineaId: _linea!.id,
            lineaNombre: _linea!.nombre,
            observaciones:
                _obsCtrl.text.trim().isEmpty ? null : _obsCtrl.text.trim(),
            items: _items
                .map(
                  (i) => {
                    'materialId': i.material.id,
                    'cantidad': i.cantidad,
                  },
                )
                .toList(),
          );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final operarios = ref.watch(operariosProvider);
    final lineas = ref.watch(lineasProvider);
    final materiales = ref.watch(materialesProvider);
    final isMobile = Responsive.isMobile(context);
    final width = MediaQuery.sizeOf(context).width;

    return AlertDialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 40,
        vertical: isMobile ? 14 : 24,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: const Color(0xFFF8FAFC),
      titlePadding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
      contentPadding: const EdgeInsets.fromLTRB(22, 12, 22, 10),
      actionsPadding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: TecneroTheme.azulOscuro.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.assignment_turned_in_outlined,
              color: TecneroTheme.azulOscuro,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Registrar despacho directo',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 2),
                Text(
                  'Bodega entrega y registra stock en un solo paso',
                  style: TextStyle(
                    fontSize: 11,
                    color: TecneroTheme.textoSecundario,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: isMobile ? width * 0.92 : 760,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              operarios.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => _DialogError('Operarios: $e'),
                data: (lista) => DropdownButtonFormField<models.Usuario>(
                  initialValue: _operario,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Colaborador de planta',
                    prefixIcon: Icon(Icons.person_outline, size: 18),
                  ),
                  items: lista
                      .map(
                        (u) => DropdownMenuItem(
                          value: u,
                          child: Text(
                            u.nombre,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _operario = v),
                ),
              ),
              const SizedBox(height: 10),
              lineas.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => _DialogError('Líneas: $e'),
                data: (lista) =>
                    DropdownButtonFormField<models.LineaProduccion>(
                  initialValue: _linea,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Línea',
                    prefixIcon: Icon(Icons.factory_outlined, size: 18),
                  ),
                  items: lista
                      .map(
                        (l) => DropdownMenuItem(
                          value: l,
                          child: Text(
                            l.nombre,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    setState(() {
                      _linea = v;
                      _items.clear();
                      _error = null;
                      _info = null;
                    });

                    if (v != null) {
                      _cargarSugeridos(v);
                    }
                  },
                ),
              ),
              const SizedBox(height: 14),
              materiales.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => _DialogError('Materiales: $e'),
                data: (lista) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SizedBox(
                          width: isMobile ? double.infinity : 260,
                          child: ElevatedButton.icon(
                            onPressed: _linea == null || _cargandoSugeridos
                                ? null
                                : () => _cargarSugeridos(_linea!),
                            icon: Icon(
                              _cargandoSugeridos
                                  ? Icons.hourglass_top_outlined
                                  : Icons.auto_awesome_outlined,
                              size: 19,
                            ),
                            label: Text(
                              _cargandoSugeridos
                                  ? 'Cargando sugeridos...'
                                  : 'Cargar sugeridos de línea',
                            ),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                              backgroundColor: TecneroTheme.azulOscuro,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: isMobile ? double.infinity : 260,
                          child: OutlinedButton.icon(
                            onPressed: () => _abrirSelectorMateriales(lista),
                            icon: Icon(
                              _items.isEmpty
                                  ? Icons.add_circle_outline
                                  : Icons.edit_outlined,
                              size: 20,
                            ),
                            label: Text(
                              _items.isEmpty
                                  ? 'Buscar materiales'
                                  : 'Editar selección (${_items.length})',
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                              side: const BorderSide(
                                color: TecneroTheme.azulOscuro,
                                width: 1.5,
                              ),
                              foregroundColor: TecneroTheme.azulOscuro,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_info != null) ...[
                      const SizedBox(height: 10),
                      _DialogInfo(_info!),
                    ],
                    if (_items.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _ResumenStockDespacho(items: _items),
                      const SizedBox(height: 10),
                      ...List.generate(_items.length, (i) {
                        final item = _items[i];

                        return _DespachoDirectoItemCard(
                          key: ValueKey(item.material.id),
                          item: item,
                          onCantidadChange: (value) {
                            setState(() {
                              item.cantidad = value;
                              _error = null;
                            });
                          },
                          onRemove: () {
                            setState(() {
                              _items.removeAt(i);
                              _error = null;
                            });
                          },
                        );
                      }),
                    ] else ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F9FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFBAE6FD)),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Color(0xFF0284C7),
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Selecciona uno o varios materiales. Podrás ver el stock y ajustar cantidades antes de despachar.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF0369A1),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _obsCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Observaciones',
                  hintText: 'Ej: Entrega directa en ventanilla',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                _DialogError(_error!),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          onPressed: _guardando || !_stockValido ? null : _guardar,
          icon: _guardando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check_circle_outline, size: 18),
          label: const Text('Guardar y despachar'),
        ),
      ],
    );
  }
}

class _SelectorMaterialesDespachoDialog extends StatefulWidget {
  final List<models.Material> materiales;
  final List<models.Material> seleccionInicial;
  final String Function(models.Material) categoriaLabel;
  final Color Function(String) categoriaColor;
  final String Function(String) normalizarTexto;

  const _SelectorMaterialesDespachoDialog({
    required this.materiales,
    required this.seleccionInicial,
    required this.categoriaLabel,
    required this.categoriaColor,
    required this.normalizarTexto,
  });

  @override
  State<_SelectorMaterialesDespachoDialog> createState() =>
      _SelectorMaterialesDespachoDialogState();
}

class _SelectorMaterialesDespachoDialogState
    extends State<_SelectorMaterialesDespachoDialog> {
  final _buscarCtrl = TextEditingController();
  final Set<String> _seleccionadosIds = {};
  String _categoriaFiltro = 'Todos';
  bool _soloConStock = false;

  @override
  void initState() {
    super.initState();
    _seleccionadosIds.addAll(widget.seleccionInicial.map((m) => m.id));
  }

  @override
  void dispose() {
    _buscarCtrl.dispose();
    super.dispose();
  }

  List<String> get _categorias {
    final cats = widget.materiales.map(widget.categoriaLabel).toSet().toList()
      ..sort();

    return ['Todos', ...cats];
  }

  List<models.Material> get _filtrados {
    final q = widget.normalizarTexto(_buscarCtrl.text);

    return widget.materiales.where((m) {
      final cat = widget.categoriaLabel(m);
      final matchCat = _categoriaFiltro == 'Todos' || cat == _categoriaFiltro;
      final texto =
          widget.normalizarTexto('${m.codigo} ${m.nombre} ${m.unidadMedida}');
      final matchTxt = q.isEmpty || texto.contains(q);
      final matchStock = !_soloConStock || m.stockActual > 0;

      return matchCat && matchTxt && matchStock;
    }).toList()
      ..sort((a, b) {
        final c = widget.categoriaLabel(a).compareTo(widget.categoriaLabel(b));
        if (c != 0) return c;
        return a.nombre.compareTo(b.nombre);
      });
  }

  @override
  Widget build(BuildContext context) {
    final filtrados = _filtrados;
    final w = MediaQuery.of(context).size.width;
    final isMobile = Responsive.isMobile(context);

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      title: Row(
        children: [
          const Expanded(
            child: Text(
              'Seleccionar materiales',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: TecneroTheme.naranja.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${_seleccionadosIds.length} seleccionados',
              style: const TextStyle(
                fontSize: 12,
                color: TecneroTheme.naranja,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: isMobile ? w * 0.92 : 760,
        height: isMobile ? MediaQuery.sizeOf(context).height * 0.72 : 600,
        child: Column(
          children: [
            TextField(
              controller: _buscarCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o código...',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _buscarCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => _buscarCtrl.clear()),
                      )
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  ..._categorias.map((cat) {
                    final sel = cat == _categoriaFiltro;

                    return FilterChip(
                      label: Text(cat),
                      selected: sel,
                      onSelected: (_) => setState(() => _categoriaFiltro = cat),
                      backgroundColor: cat == 'Todos'
                          ? TecneroTheme.grisClaro
                          : widget.categoriaColor(cat),
                      selectedColor: TecneroTheme.azulOscuro,
                      labelStyle: TextStyle(
                        fontSize: 11,
                        color: sel ? Colors.white : TecneroTheme.textoPrimario,
                      ),
                      checkmarkColor: Colors.white,
                    );
                  }),
                  FilterChip(
                    label: const Text('Con stock'),
                    selected: _soloConStock,
                    onSelected: (value) =>
                        setState(() => _soloConStock = value),
                    selectedColor: const Color(0xFF059669),
                    labelStyle: TextStyle(
                      fontSize: 11,
                      color: _soloConStock
                          ? Colors.white
                          : TecneroTheme.textoPrimario,
                    ),
                    checkmarkColor: Colors.white,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: filtrados.isEmpty
                  ? const Center(
                      child: Text(
                        'Sin resultados',
                        style: TextStyle(color: TecneroTheme.textoSecundario),
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtrados.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final m = filtrados[i];
                        final cat = widget.categoriaLabel(m);
                        final sel = _seleccionadosIds.contains(m.id);
                        final sinStock = m.stockActual <= 0;

                        return CheckboxListTile(
                          dense: true,
                          value: sel,
                          enabled: !sinStock,
                          onChanged: (v) => setState(() {
                            if (v == true) {
                              _seleccionadosIds.add(m.id);
                            } else {
                              _seleccionadosIds.remove(m.id);
                            }
                          }),
                          title: Text(
                            m.nombre,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: sinStock
                                  ? TecneroTheme.textoSecundario
                                  : TecneroTheme.textoPrimario,
                            ),
                          ),
                          subtitle: Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                m.codigo,
                                style: const TextStyle(fontSize: 11),
                              ),
                              Text(
                                m.unidadMedida,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: TecneroTheme.textoSecundario,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: widget.categoriaColor(cat),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  cat,
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: sinStock
                                      ? const Color(0xFFFEE2E2)
                                      : const Color(0xFFD1FAE5),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'Stock: ${_formatCantidad(m.stockActual)}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: sinStock
                                        ? const Color(0xFF991B1B)
                                        : const Color(0xFF047857),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: TecneroTheme.azulOscuro,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            final sel = widget.materiales
                .where((m) => _seleccionadosIds.contains(m.id))
                .toList();

            Navigator.pop(context, sel);
          },
          icon: const Icon(Icons.check, size: 18),
          label: Text('Confirmar (${_seleccionadosIds.length})'),
        ),
      ],
    );
  }
}

class _ResumenStockDespacho extends StatelessWidget {
  final List<_DespachoItem> items;

  const _ResumenStockDespacho({
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final sinStock =
        items.where((i) => i.cantidad > i.material.stockActual).length;

    return Row(
      children: [
        Expanded(
          child: _MiniChip(
            'Materiales',
            '${items.length}',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MiniChip(
            'Stock',
            sinStock == 0 ? 'OK' : '$sinStock con problema',
            success: sinStock == 0,
            danger: sinStock > 0,
          ),
        ),
      ],
    );
  }
}

class _DespachoDirectoItemCard extends StatelessWidget {
  final _DespachoItem item;
  final ValueChanged<double> onCantidadChange;
  final VoidCallback onRemove;

  const _DespachoDirectoItemCard({
    super.key,
    required this.item,
    required this.onCantidadChange,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final restante = item.material.stockActual - item.cantidad;
    final suficiente = restante >= 0;
    final isMobile = Responsive.isMobile(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: suficiente ? TecneroTheme.grisBorde : const Color(0xFFFCA5A5),
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MaterialInfo(material: item.material),
                const SizedBox(height: 10),
                _CantidadYStock(
                  item: item,
                  restante: restante,
                  suficiente: suficiente,
                  onCantidadChange: onCantidadChange,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Quitar',
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(child: _MaterialInfo(material: item.material)),
                const SizedBox(width: 12),
                SizedBox(
                  width: 300,
                  child: _CantidadYStock(
                    item: item,
                    restante: restante,
                    suficiente: suficiente,
                    onCantidadChange: onCantidadChange,
                  ),
                ),
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Quitar',
                ),
              ],
            ),
    );
  }
}

class _MaterialInfo extends StatelessWidget {
  final models.Material material;

  const _MaterialInfo({
    required this.material,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          material.nombre,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
        Text(
          material.codigo,
          style: const TextStyle(
            fontSize: 10,
            color: TecneroTheme.textoSecundario,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Unidad: ${material.unidadMedida}',
          style: const TextStyle(
            fontSize: 10,
            color: TecneroTheme.textoSecundario,
          ),
        ),
      ],
    );
  }
}

class _CantidadYStock extends StatelessWidget {
  final _DespachoItem item;
  final double restante;
  final bool suficiente;
  final ValueChanged<double> onCantidadChange;

  const _CantidadYStock({
    required this.item,
    required this.restante,
    required this.suficiente,
    required this.onCantidadChange,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 92,
          child: TextFormField(
            key: ValueKey('cantidad-${item.material.id}'),
            initialValue: _formatCantidad(item.cantidad),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Cantidad',
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            onChanged: (v) {
              final value = double.tryParse(v.replaceAll(',', '.')) ?? 0;
              onCantidadChange(value);
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _MiniChip(
                'Stock',
                _formatCantidad(item.material.stockActual),
              ),
              _MiniChip(
                'Queda',
                _formatCantidad(restante),
                success: suficiente,
                danger: !suficiente,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DialogError extends StatelessWidget {
  final String msg;

  const _DialogError(this.msg);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        msg,
        style: const TextStyle(
          color: Color(0xFF991B1B),
          fontSize: 12,
        ),
      ),
    );
  }
}

class _DialogInfo extends StatelessWidget {
  final String msg;

  const _DialogInfo(this.msg);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFE0F2FE),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF7DD3FC)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.auto_awesome_outlined,
            size: 16,
            color: Color(0xFF0369A1),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              msg,
              style: const TextStyle(
                color: Color(0xFF075985),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EntregasError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  final VoidCallback onLogin;

  const _EntregasError({
    required this.error,
    required this.onRetry,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    final message = error.toString();
    final sesionPerdida =
        message.toLowerCase().contains('sesión no iniciada') ||
            message.toLowerCase().contains('sesion no iniciada');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: TecneroTheme.grisBorde),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                sesionPerdida
                    ? Icons.lock_outline
                    : Icons.error_outline_outlined,
                size: 42,
                color: sesionPerdida
                    ? TecneroTheme.naranja
                    : const Color(0xFFB91C1C),
              ),
              const SizedBox(height: 12),
              Text(
                sesionPerdida
                    ? 'Tu sesión no está activa'
                    : 'No se pudieron cargar las entregas',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: TecneroTheme.azulOscuro,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                sesionPerdida
                    ? 'Vuelve a iniciar sesión para consultar los despachos pendientes.'
                    : message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: TecneroTheme.textoSecundario,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Reintentar'),
                  ),
                  if (sesionPerdida)
                    ElevatedButton.icon(
                      onPressed: onLogin,
                      icon: const Icon(Icons.login, size: 18),
                      label: const Text('Iniciar sesión'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyEntregas extends StatelessWidget {
  const _EmptyEntregas();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_shipping_outlined,
              size: 48,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 12),
            const Text(
              'No hay entregas pendientes',
              style: TextStyle(
                color: TecneroTheme.textoSecundario,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Cuando planta solicite materiales, aparecerán aquí para despacho',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: TecneroTheme.textoSecundario,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatCantidad(double value) {
  if (value % 1 == 0) return value.toInt().toString();
  return value.toStringAsFixed(2);
}
