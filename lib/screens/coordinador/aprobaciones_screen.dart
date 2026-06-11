// Vista del coordinador para consultar despachos y su detalle.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/models.dart';
import '../../services/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/responsive.dart';

class AprobacionesScreen extends ConsumerStatefulWidget {
  const AprobacionesScreen({super.key});

  @override
  ConsumerState<AprobacionesScreen> createState() => _DespachosScreenState();
}

class _DespachosScreenState extends ConsumerState<AprobacionesScreen> {
  final _fmtDate = DateFormat('dd/MM/yyyy HH:mm');
  final _fmtDay = DateFormat('dd/MM/yyyy');
  final _fmtMoney = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  final _busquedaCtrl = TextEditingController();

  DateTime? _fechaFiltro;
  String? _lineaFiltroId;
  String _busqueda = '';

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFecha() async {
    final ahora = DateTime.now();

    final seleccion = await showDatePicker(
      context: context,
      initialDate: _fechaFiltro ?? ahora,
      firstDate: DateTime(2020),
      lastDate: DateTime(ahora.year + 1),
    );

    if (seleccion != null) {
      setState(() => _fechaFiltro = seleccion);
    }
  }

  void _limpiarFiltros() {
    setState(() {
      _fechaFiltro = null;
      _lineaFiltroId = null;
      _busqueda = '';
      _busquedaCtrl.clear();
    });
  }

  Future<void> _recargarDespachos() async {
    ref.invalidate(solicitudesEntregadasProvider);
    await ref.read(solicitudesEntregadasProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final entregadasAsync = ref.watch(solicitudesEntregadasProvider);
    final lineasAsync = ref.watch(lineasProvider);
    final isMobile = Responsive.isMobile(context);

    return Scaffold(
      backgroundColor: TecneroTheme.grisClaro,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: Responsive.headerPadding(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Despachos de bodega',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: TecneroTheme.textoPrimario,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Registro completo por fecha, línea y colaborador',
                  style: TextStyle(
                    fontSize: 13,
                    color: TecneroTheme.textoSecundario,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    onPressed: _recargarDespachos,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Recargar despachos',
                  ),
                ),
                const SizedBox(height: 14),
                _FiltrosDespachos(
                  busquedaCtrl: _busquedaCtrl,
                  fechaFiltro: _fechaFiltro,
                  lineaFiltroId: _lineaFiltroId,
                  lineasAsync: lineasAsync,
                  onBuscar: (value) => setState(() => _busqueda = value),
                  onFechaTap: _seleccionarFecha,
                  onClearFecha: () => setState(() => _fechaFiltro = null),
                  onLineaChanged: (value) {
                    setState(() => _lineaFiltroId = value);
                  },
                  onLimpiar: _limpiarFiltros,
                  fmtDay: _fmtDay,
                ),
              ],
            ),
          ),
          Expanded(
            child: entregadasAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text(
                    'Error: $e',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ),
              data: (entregadas) {
                final filtradas = _filtrar(entregadas);
                final grupos = _agruparPorDia(filtradas);

                if (filtradas.isEmpty) {
                  return const _EmptyDespachos();
                }

                final hoy = DateTime.now();
                final despachosHoy = filtradas.where((s) {
                  final fecha = s.fechaEntrega ?? s.fecha;
                  return _mismoDia(fecha, hoy);
                }).toList();

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(solicitudesEntregadasProvider);
                    await ref.read(solicitudesEntregadasProvider.future);
                  },
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      isMobile ? 12 : 20,
                      14,
                      isMobile ? 12 : 20,
                      24,
                    ),
                    children: [
                      _ResumenDespachos(
                        totalFiltrado: filtradas.length,
                        totalHoy: despachosHoy.length,
                        totalItems: filtradas.fold<int>(
                          0,
                          (total, s) => total + s.detalles.length,
                        ),
                      ),
                      const SizedBox(height: 14),
                      ...grupos.entries.map(
                        (entry) => _DiaDespachosSection(
                          fecha: entry.key,
                          solicitudes: entry.value,
                          fmtDate: _fmtDate,
                          fmtMoney: _fmtMoney,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Solicitud> _filtrar(List<Solicitud> solicitudes) {
    final query = _busqueda.trim().toLowerCase();

    return solicitudes.where((s) {
      final fechaDespacho = s.fechaEntrega ?? s.fecha;

      final matchFecha =
          _fechaFiltro == null || _mismoDia(fechaDespacho, _fechaFiltro!);
      final matchLinea = _lineaFiltroId == null || s.lineaId == _lineaFiltroId;
      final matchBusqueda = query.isEmpty ||
          s.numero.toLowerCase().contains(query) ||
          s.solicitanteNombre.toLowerCase().contains(query) ||
          s.lineaNombre.toLowerCase().contains(query) ||
          (s.aprobadoPor ?? '').toLowerCase().contains(query) ||
          (s.observaciones ?? '').toLowerCase().contains(query);

      return matchFecha && matchLinea && matchBusqueda;
    }).toList()
      ..sort((a, b) {
        final fa = a.fechaEntrega ?? a.fecha;
        final fb = b.fechaEntrega ?? b.fecha;
        return fb.compareTo(fa);
      });
  }

  Map<DateTime, List<Solicitud>> _agruparPorDia(List<Solicitud> solicitudes) {
    final grupos = <DateTime, List<Solicitud>>{};

    for (final solicitud in solicitudes) {
      final fecha = solicitud.fechaEntrega ?? solicitud.fecha;
      final dia = DateTime(fecha.year, fecha.month, fecha.day);
      grupos.putIfAbsent(dia, () => []).add(solicitud);
    }

    return Map.fromEntries(
      grupos.entries.toList()..sort((a, b) => b.key.compareTo(a.key)),
    );
  }
}

class _FiltrosDespachos extends StatelessWidget {
  final TextEditingController busquedaCtrl;
  final DateTime? fechaFiltro;
  final String? lineaFiltroId;
  final AsyncValue<List<LineaProduccion>> lineasAsync;
  final ValueChanged<String> onBuscar;
  final VoidCallback onFechaTap;
  final VoidCallback onClearFecha;
  final ValueChanged<String?> onLineaChanged;
  final VoidCallback onLimpiar;
  final DateFormat fmtDay;

  const _FiltrosDespachos({
    required this.busquedaCtrl,
    required this.fechaFiltro,
    required this.lineaFiltroId,
    required this.lineasAsync,
    required this.onBuscar,
    required this.onFechaTap,
    required this.onClearFecha,
    required this.onLineaChanged,
    required this.onLimpiar,
    required this.fmtDay,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    final buscador = TextField(
      controller: busquedaCtrl,
      decoration: const InputDecoration(
        hintText: 'Buscar despachos...',
        prefixIcon: Icon(Icons.search, size: 18),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        prefixIconConstraints: BoxConstraints(minWidth: 40, minHeight: 18),
      ),
      onChanged: onBuscar,
    );

    final fechaButton = OutlinedButton.icon(
      onPressed: onFechaTap,
      icon: const Icon(Icons.calendar_today_outlined, size: 18),
      label: Text(
        fechaFiltro == null ? 'Todas las fechas' : fmtDay.format(fechaFiltro!),
        overflow: TextOverflow.ellipsis,
      ),
    );

    final fechaClear = fechaFiltro == null
        ? const SizedBox()
        : IconButton(
            onPressed: onClearFecha,
            icon: const Icon(Icons.close),
            tooltip: 'Quitar fecha',
          );

    final lineaDropdown = lineasAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text(
        'No se pudieron cargar líneas: $e',
        style: const TextStyle(fontSize: 12, color: Colors.red),
      ),
      data: (lineas) => DropdownButtonFormField<String?>(
        value: lineaFiltroId,
        isExpanded: true,
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.factory_outlined, size: 18),
          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        ),
        selectedItemBuilder: (context) {
          return [
            const Text(
              'Todas las líneas',
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            ...lineas.map(
              (linea) => Text(
                linea.nombre,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ];
        },
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text(
              'Todas las líneas',
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          ...lineas.map(
            (linea) => DropdownMenuItem<String?>(
              value: linea.id,
              child: Text(
                linea.nombre,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ),
        ],
        onChanged: onLineaChanged,
      ),
    );

    final limpiarButton = TextButton.icon(
      onPressed: onLimpiar,
      icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
      label: const Text('Limpiar filtros'),
    );

    if (isMobile) {
      return lineasAsync.when(
        loading: () => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            buscador,
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: fechaButton),
                if (fechaFiltro != null) fechaClear,
              ],
            ),
            const SizedBox(height: 10),
            const LinearProgressIndicator(),
          ],
        ),
        error: (e, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            buscador,
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: fechaButton),
                if (fechaFiltro != null) fechaClear,
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'No se pudieron cargar líneas: $e',
              style: const TextStyle(fontSize: 12, color: Colors.red),
            ),
          ],
        ),
        data: (lineas) {
          final lineaNombre = _lineaLabel(lineas, lineaFiltroId);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              buscador,
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(
                    height: 40,
                    child: OutlinedButton.icon(
                      onPressed: onFechaTap,
                      icon: const Icon(Icons.calendar_today_outlined, size: 18),
                      label: Text(
                        fechaFiltro == null
                            ? 'Fecha'
                            : fmtDay.format(fechaFiltro!),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 40,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final seleccion = await showModalBottomSheet<String?>(
                          context: context,
                          isScrollControlled: true,
                          showDragHandle: true,
                          builder: (_) => _LineaSelectorSheet(
                            lineas: lineas,
                            lineaSeleccionadaId: lineaFiltroId,
                          ),
                        );

                        if (seleccion != null) {
                          onLineaChanged(seleccion.isEmpty ? null : seleccion);
                        }
                      },
                      icon: const Icon(Icons.factory_outlined, size: 18),
                      label: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 160),
                        child: Text(
                          lineaNombre,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                  if (fechaFiltro != null || lineaFiltroId != null)
                    SizedBox(
                      height: 40,
                      child: TextButton.icon(
                        onPressed: onLimpiar,
                        icon:
                            const Icon(Icons.filter_alt_off_outlined, size: 18),
                        label: const Text('Limpiar'),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(width: 280, child: buscador),
        SizedBox(width: 220, child: fechaButton),
        if (fechaFiltro != null) fechaClear,
        SizedBox(width: 240, child: lineaDropdown),
        limpiarButton,
      ],
    );
  }
}

class _LineaSelectorSheet extends StatelessWidget {
  final List<LineaProduccion> lineas;
  final String? lineaSeleccionadaId;

  const _LineaSelectorSheet({
    required this.lineas,
    required this.lineaSeleccionadaId,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          const Text(
            'Filtrar por línea',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          RadioListTile<String?>(
            value: null,
            groupValue: lineaSeleccionadaId,
            onChanged: (value) => Navigator.pop(context, value),
            title: const Text('Todas las líneas'),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
          ...lineas.map(
            (linea) => RadioListTile<String?>(
              value: linea.id,
              groupValue: lineaSeleccionadaId,
              onChanged: (value) => Navigator.pop(context, value),
              title: Text(
                linea.nombre,
                overflow: TextOverflow.ellipsis,
              ),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}

String _lineaLabel(List<LineaProduccion> lineas, String? lineaId) {
  if (lineaId == null) return 'Todas las líneas';
  for (final linea in lineas) {
    if (linea.id == lineaId) return linea.nombre;
  }
  return 'Línea';
}

class _ResumenDespachos extends StatelessWidget {
  final int totalFiltrado;
  final int totalHoy;
  final int totalItems;

  const _ResumenDespachos({
    required this.totalFiltrado,
    required this.totalHoy,
    required this.totalItems,
  });

  @override
  Widget build(BuildContext context) {
    final chips = [
      _MetricChip(
        icon: Icons.local_shipping_outlined,
        label: 'Despachos filtrados',
        value: '$totalFiltrado',
      ),
      _MetricChip(
        icon: Icons.today_outlined,
        label: 'Despachos hoy',
        value: '$totalHoy',
      ),
      _MetricChip(
        icon: Icons.inventory_2_outlined,
        label: 'Ítems registrados',
        value: '$totalItems',
      ),
    ];

    if (Responsive.isMobile(context)) {
      return Column(
        children: [
          for (final chip in chips) ...[
            chip,
            const SizedBox(height: 8),
          ],
        ],
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: chips,
    );
  }
}

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetricChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Container(
      width: isMobile ? double.infinity : 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: TecneroTheme.grisBorde),
      ),
      child: Row(
        children: [
          Icon(icon, color: TecneroTheme.naranja),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: TecneroTheme.textoSecundario,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DiaDespachosSection extends StatelessWidget {
  final DateTime fecha;
  final List<Solicitud> solicitudes;
  final DateFormat fmtDate;
  final NumberFormat fmtMoney;

  const _DiaDespachosSection({
    required this.fecha,
    required this.solicitudes,
    required this.fmtDate,
    required this.fmtMoney,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 2),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    _labelDia(fecha),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: TecneroTheme.azulOscuro,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: TecneroTheme.naranja.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${solicitudes.length}',
                    style: const TextStyle(
                      color: TecneroTheme.naranja,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...solicitudes.map(
            (solicitud) => _DespachoCard(
              solicitud: solicitud,
              fmtDate: fmtDate,
              fmtMoney: fmtMoney,
            ),
          ),
        ],
      ),
    );
  }
}

class _DespachoCard extends StatefulWidget {
  final Solicitud solicitud;
  final DateFormat fmtDate;
  final NumberFormat fmtMoney;

  const _DespachoCard({
    required this.solicitud,
    required this.fmtDate,
    required this.fmtMoney,
  });

  @override
  State<_DespachoCard> createState() => _DespachoCardState();
}

class _DespachoCardState extends State<_DespachoCard> {
  bool _expandido = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.solicitud;
    final isMobile = Responsive.isMobile(context);
    final fechaDespacho = s.fechaEntrega ?? s.fecha;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expandido = !_expandido),
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 12 : 14),
              child: isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _DespachoIcon(),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _DespachoCardInfo(
                                solicitud: s,
                                fechaDespacho: fechaDespacho,
                                fmtDate: widget.fmtDate,
                              ),
                            ),
                            Icon(
                              _expandido
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              color: TecneroTheme.textoSecundario,
                              size: 22,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _MiniInfoChip(
                              icon: Icons.inventory_2_outlined,
                              text: '${s.detalles.length} materiales',
                            ),
                            _MiniInfoChip(
                              icon: Icons.attach_money,
                              text: _moneyText(
                                widget.fmtMoney,
                                s.costoTotal,
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DespachoIcon(),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DespachoCardInfo(
                            solicitud: s,
                            fechaDespacho: fechaDespacho,
                            fmtDate: widget.fmtDate,
                          ),
                        ),
                        const SizedBox(width: 10),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 125),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                widget.fmtMoney.format(s.costoTotal).trim(),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: TecneroTheme.naranja,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${s.detalles.length} materiales',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: TecneroTheme.textoSecundario,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Icon(
                                _expandido
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                color: TecneroTheme.textoSecundario,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          if (_expandido) ...[
            const Divider(height: 1),
            Padding(
              padding: EdgeInsets.all(isMobile ? 12 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoBlocksGrid(
                    solicitud: s,
                    fechaDespacho: fechaDespacho,
                    fmtDate: widget.fmtDate,
                  ),
                  if ((s.observaciones ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _InfoBlock(
                      label: 'Comentarios',
                      value: s.observaciones!,
                      icon: Icons.notes_outlined,
                      fullWidth: true,
                    ),
                  ],
                  const SizedBox(height: 14),
                  const Text(
                    'Materiales despachados',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: TecneroTheme.textoPrimario,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (s.detalles.isEmpty)
                    const Text(
                      'Sin materiales registrados',
                      style: TextStyle(
                        fontSize: 12,
                        color: TecneroTheme.textoSecundario,
                      ),
                    )
                  else
                    ...s.detalles.map(
                      (d) => _MaterialDespachoItem(
                        detalle: d,
                        fmtMoney: widget.fmtMoney,
                      ),
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

class _DespachoIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFD1FAE5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(
        Icons.local_shipping_outlined,
        color: Color(0xFF047857),
        size: 18,
      ),
    );
  }
}

class _DespachoCardInfo extends StatelessWidget {
  final Solicitud solicitud;
  final DateTime fechaDespacho;
  final DateFormat fmtDate;

  const _DespachoCardInfo({
    required this.solicitud,
    required this.fechaDespacho,
    required this.fmtDate,
  });

  @override
  Widget build(BuildContext context) {
    final s = solicitud;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 5,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              s.numero,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: TecneroTheme.azulOscuro,
              ),
            ),
            EstadoBadge(estado: s.estado),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${s.solicitanteNombre} · ${s.lineaNombre}',
          style: const TextStyle(
            fontSize: 12,
            color: TecneroTheme.textoPrimario,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
        const SizedBox(height: 2),
        Text(
          'Pedido: ${fmtDate.format(s.fecha)}',
          style: const TextStyle(
            fontSize: 11,
            color: TecneroTheme.textoSecundario,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          'Despacho: ${fmtDate.format(fechaDespacho)}',
          style: const TextStyle(
            fontSize: 11,
            color: TecneroTheme.textoSecundario,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        if ((s.aprobadoPor ?? '').trim().isNotEmpty)
          Text(
            'Despachó: ${s.aprobadoPor}',
            style: const TextStyle(
              fontSize: 11,
              color: TecneroTheme.textoSecundario,
            ),
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }
}

class _InfoBlocksGrid extends StatelessWidget {
  final Solicitud solicitud;
  final DateTime fechaDespacho;
  final DateFormat fmtDate;

  const _InfoBlocksGrid({
    required this.solicitud,
    required this.fechaDespacho,
    required this.fmtDate,
  });

  @override
  Widget build(BuildContext context) {
    final s = solicitud;
    final blocks = [
      _InfoBlock(
        label: 'Colaborador',
        value: s.solicitanteNombre,
        icon: Icons.person_outline,
      ),
      _InfoBlock(
        label: 'Línea / fábrica',
        value: s.lineaNombre.isEmpty ? 'Sin línea registrada' : s.lineaNombre,
        icon: Icons.factory_outlined,
      ),
      _InfoBlock(
        label: 'Hora de pedido',
        value: fmtDate.format(s.fecha),
        icon: Icons.event_note_outlined,
      ),
      _InfoBlock(
        label: 'Hora de despacho',
        value: fmtDate.format(fechaDespacho),
        icon: Icons.local_shipping_outlined,
      ),
      _InfoBlock(
        label: 'Despachó',
        value: (s.aprobadoPor ?? '').trim().isEmpty
            ? 'No registrado'
            : s.aprobadoPor!,
        icon: Icons.badge_outlined,
      ),
    ];

    if (Responsive.isMobile(context)) {
      return Column(
        children: [
          for (final block in blocks) ...[
            block,
            const SizedBox(height: 8),
          ],
        ],
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: blocks,
    );
  }
}

class _InfoBlock extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool fullWidth;

  const _InfoBlock({
    required this.label,
    required this.value,
    required this.icon,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: fullWidth || Responsive.isMobile(context) ? double.infinity : 260,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: TecneroTheme.grisClaro,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: TecneroTheme.grisBorde),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: TecneroTheme.textoSecundario),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      color: TecneroTheme.textoSecundario,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 12,
                      color: TecneroTheme.textoPrimario,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniInfoChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MiniInfoChip({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: TecneroTheme.grisClaro,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: TecneroTheme.grisBorde),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: TecneroTheme.textoSecundario),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              color: TecneroTheme.textoSecundario,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MaterialDespachoItem extends StatelessWidget {
  final DetalleSolicitud detalle;
  final NumberFormat fmtMoney;

  const _MaterialDespachoItem({
    required this.detalle,
    required this.fmtMoney,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: TecneroTheme.grisBorde),
        borderRadius: BorderRadius.circular(8),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detalle.materialNombre,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (detalle.materialCodigo.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    detalle.materialCodigo,
                    style: const TextStyle(
                      fontSize: 10,
                      color: TecneroTheme.textoSecundario,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _MobileMetricPill(
                        label: 'Cantidad',
                        value:
                            '${_formatCantidad(detalle.cantidad)} ${detalle.unidadMedida}',
                        icon: Icons.numbers_outlined,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MobileMetricPill(
                        label: 'Subtotal',
                        value: _moneyText(fmtMoney, detalle.subtotal),
                        icon: Icons.attach_money,
                        alignEnd: true,
                      ),
                    ),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        detalle.materialNombre,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (detalle.materialCodigo.isNotEmpty)
                        Text(
                          detalle.materialCodigo,
                          style: const TextStyle(
                            fontSize: 10,
                            color: TecneroTheme.textoSecundario,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    '${_formatCantidad(detalle.cantidad)} ${detalle.unidadMedida}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 14),
                Flexible(
                  child: Text(
                    fmtMoney.format(detalle.subtotal),
                    style: const TextStyle(
                      fontSize: 12,
                      color: TecneroTheme.textoSecundario,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
    );
  }
}

class _MobileMetricPill extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool alignEnd;

  const _MobileMetricPill({
    required this.label,
    required this.value,
    required this.icon,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: TecneroTheme.grisClaro,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: TecneroTheme.grisBorde),
      ),
      child: Row(
        children: [
          Icon(icon, size: 13, color: TecneroTheme.textoSecundario),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: TecneroTheme.textoSecundario,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value,
                  textAlign: alignEnd ? TextAlign.right : TextAlign.left,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: TecneroTheme.textoPrimario,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDespachos extends StatelessWidget {
  const _EmptyDespachos();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Text(
          'No hay despachos con los filtros seleccionados',
          textAlign: TextAlign.center,
          style: TextStyle(color: TecneroTheme.textoSecundario),
        ),
      ),
    );
  }
}

bool _mismoDia(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String _labelDia(DateTime fecha) {
  final hoy = DateTime.now();
  final ayer = hoy.subtract(const Duration(days: 1));
  final anteayer = hoy.subtract(const Duration(days: 2));

  if (_mismoDia(fecha, hoy)) return 'Hoy';
  if (_mismoDia(fecha, ayer)) return 'Ayer';
  if (_mismoDia(fecha, anteayer)) return 'Antes de ayer';

  return DateFormat('dd/MM/yyyy').format(fecha);
}

String _formatCantidad(double value) {
  if (value % 1 == 0) return value.toInt().toString();
  return value.toStringAsFixed(2);
}

String _moneyText(NumberFormat fmt, num value) {
  final formatted = fmt.format(value).trim();
  return formatted.replaceFirst(RegExp(r'^[^\d-]+'), '').trimLeft();
}
