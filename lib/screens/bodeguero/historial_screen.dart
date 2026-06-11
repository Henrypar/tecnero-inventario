// Historial de bodega con entregas y rechazos agrupados por fecha.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';
import '../../services/providers.dart';
import '../../models/models.dart';
import '../../widgets/responsive.dart';

class HistorialScreen extends ConsumerStatefulWidget {
  const HistorialScreen({super.key});

  @override
  ConsumerState<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends ConsumerState<HistorialScreen> {
  final _buscarCtrl = TextEditingController();
  final _fmtDay = DateFormat('dd/MM/yyyy');
  DateTime? _fechaFiltro;
  String _origenFiltro = 'todos';
  String _lineaFiltro = 'todas';
  String _busqueda = '';

  @override
  void dispose() {
    _buscarCtrl.dispose();
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
      _origenFiltro = 'todos';
      _lineaFiltro = 'todas';
      _busqueda = '';
      _buscarCtrl.clear();
    });
  }

  Future<void> _abrirFiltrosMobile(List<String> lineas) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: _Header(
            lineas: lineas,
            mostrarSoloFiltros: true,
            busquedaCtrl: _buscarCtrl,
            origenFiltro: _origenFiltro,
            lineaFiltro: _lineaFiltro,
            fechaFiltro: _fechaFiltro,
            fmtDay: _fmtDay,
            onBuscar: (value) => setState(() => _busqueda = value),
            onOrigenChanged: (value) => setState(() => _origenFiltro = value),
            onLineaChanged: (value) => setState(() => _lineaFiltro = value),
            onFechaTap: _seleccionarFecha,
            onClearFecha: () => setState(() => _fechaFiltro = null),
            onLimpiar: _limpiarFiltros,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entregadasAsync = ref.watch(solicitudesHistorialBodegaProvider);
    final isMobile = Responsive.isMobile(context);

    return Scaffold(
      backgroundColor: TecneroTheme.grisClaro,
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: Responsive.headerPadding(context),
            child: entregadasAsync.when(
              loading: () => const _Header(
                lineas: [],
                loading: true,
              ),
              error: (_, __) => const _Header(lineas: []),
              data: (entregadas) {
                final lineas = _lineasDisponibles(entregadas);

                if (_lineaFiltro != 'todas' && !lineas.contains(_lineaFiltro)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _lineaFiltro = 'todas');
                  });
                }

                return _Header(
                  lineas: lineas,
                  busquedaCtrl: _buscarCtrl,
                  origenFiltro: _origenFiltro,
                  lineaFiltro: _lineaFiltro,
                  fechaFiltro: _fechaFiltro,
                  fmtDay: _fmtDay,
                  onBuscar: (value) => setState(() => _busqueda = value),
                  onOrigenChanged: (value) =>
                      setState(() => _origenFiltro = value),
                  onLineaChanged: (value) =>
                      setState(() => _lineaFiltro = value),
                  onFechaTap: _seleccionarFecha,
                  onClearFecha: () => setState(() => _fechaFiltro = null),
                  onLimpiar: _limpiarFiltros,
                  onAbrirFiltros: () => _abrirFiltrosMobile(lineas),
                );
              },
            ),
          ),
          Expanded(
            child: entregadasAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (entregadas) {
                final filtradas = _filtrar(entregadas);
                final grupos = _agruparPorDia(filtradas);

                if (filtradas.isEmpty) {
                  return const _EmptyHistorial();
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(solicitudesHistorialBodegaProvider);
                    await ref.read(solicitudesHistorialBodegaProvider.future);
                  },
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      isMobile ? 12 : 20,
                      14,
                      isMobile ? 12 : 20,
                      24,
                    ),
                    children: [
                      _ResumenHistorial(solicitudes: filtradas),
                      const SizedBox(height: 14),
                      ...grupos.entries.map(
                        (entry) => _DiaHistorialSection(
                          fecha: entry.key,
                          solicitudes: entry.value,
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
      final directo = _esDespachoDirecto(s);
      final fechaEntrega = _fechaEntrega(s);
      final texto = [
        s.numero,
        s.solicitanteNombre,
        s.lineaNombre,
        s.aprobadoPor ?? '',
        s.observaciones ?? '',
        ...s.detalles.expand((d) => [d.materialNombre, d.materialCodigo]),
      ].join(' ').toLowerCase();

      final matchOrigen = _origenFiltro == 'todos' ||
          (_origenFiltro == 'directo' && directo) ||
          (_origenFiltro == 'solicitud' && !directo);
      final matchLinea =
          _lineaFiltro == 'todas' || s.lineaNombre == _lineaFiltro;
      final matchFecha =
          _fechaFiltro == null || _mismoDia(fechaEntrega, _fechaFiltro!);
      final matchBusqueda = query.isEmpty || texto.contains(query);

      return matchOrigen && matchLinea && matchFecha && matchBusqueda;
    }).toList()
      ..sort((a, b) => _fechaEntrega(b).compareTo(_fechaEntrega(a)));
  }

  Map<DateTime, List<Solicitud>> _agruparPorDia(List<Solicitud> solicitudes) {
    final grupos = <DateTime, List<Solicitud>>{};

    for (final solicitud in solicitudes) {
      final fecha = _fechaEntrega(solicitud);
      final dia = DateTime(fecha.year, fecha.month, fecha.day);
      grupos.putIfAbsent(dia, () => []).add(solicitud);
    }

    return Map.fromEntries(
      grupos.entries.toList()..sort((a, b) => b.key.compareTo(a.key)),
    );
  }

  List<String> _lineasDisponibles(List<Solicitud> solicitudes) {
    return solicitudes
        .map((s) => s.lineaNombre)
        .where((linea) => linea.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }
}

class _Header extends StatelessWidget {
  final List<String> lineas;
  final bool loading;
  final TextEditingController? busquedaCtrl;
  final String origenFiltro;
  final String lineaFiltro;
  final DateTime? fechaFiltro;
  final DateFormat? fmtDay;
  final ValueChanged<String>? onBuscar;
  final ValueChanged<String>? onOrigenChanged;
  final ValueChanged<String>? onLineaChanged;
  final VoidCallback? onFechaTap;
  final VoidCallback? onClearFecha;
  final VoidCallback? onLimpiar;
  final VoidCallback? onAbrirFiltros;
  final bool mostrarSoloFiltros;

  const _Header({
    required this.lineas,
    this.loading = false,
    this.busquedaCtrl,
    this.origenFiltro = 'todos',
    this.lineaFiltro = 'todas',
    this.fechaFiltro,
    this.fmtDay,
    this.onBuscar,
    this.onOrigenChanged,
    this.onLineaChanged,
    this.onFechaTap,
    this.onClearFecha,
    this.onLimpiar,
    this.onAbrirFiltros,
    this.mostrarSoloFiltros = false,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    double fieldWidth(double desktopWidth) {
      return isMobile ? double.infinity : desktopWidth;
    }

    final filtros = Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: fieldWidth(300),
          child: TextField(
            controller: busquedaCtrl,
            decoration: const InputDecoration(
              hintText: 'Buscar solicitud, operario o material...',
              prefixIcon: Icon(Icons.search, size: 18),
              isDense: true,
            ),
            onChanged: onBuscar,
          ),
        ),
        SizedBox(
          width: fieldWidth(220),
          child: DropdownButtonFormField<String>(
            initialValue: origenFiltro,
            isExpanded: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.route_outlined, size: 18),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 12,
              ),
            ),
            selectedItemBuilder: (context) {
              return const [
                _DropdownSelectedText('Todos'),
                _DropdownSelectedText('Pedidos de planta'),
                _DropdownSelectedText('Despacho directo'),
              ];
            },
            items: const [
              DropdownMenuItem(
                value: 'todos',
                child: Text('Todos'),
              ),
              DropdownMenuItem(
                value: 'solicitud',
                child: Text('Pedidos de planta'),
              ),
              DropdownMenuItem(
                value: 'directo',
                child: Text('Despacho directo'),
              ),
            ],
            onChanged: (value) {
              if (value != null) onOrigenChanged?.call(value);
            },
          ),
        ),
        SizedBox(
          width: fieldWidth(240),
          child: DropdownButtonFormField<String>(
            initialValue: lineaFiltro,
            isExpanded: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.factory_outlined, size: 18),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 12,
              ),
            ),
            selectedItemBuilder: (context) {
              return [
                const _DropdownSelectedText('Todas las fábricas'),
                ...lineas.map(
                  (linea) => _DropdownSelectedText(linea),
                ),
              ];
            },
            items: [
              const DropdownMenuItem(
                value: 'todas',
                child: Text('Todas las fábricas'),
              ),
              ...lineas.map(
                (linea) => DropdownMenuItem(
                  value: linea,
                  child: Text(
                    linea,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ),
            ],
            onChanged: (value) {
              if (value != null) onLineaChanged?.call(value);
            },
          ),
        ),
        SizedBox(
          width: fieldWidth(210),
          height: 40,
          child: OutlinedButton.icon(
            onPressed: onFechaTap,
            icon: const Icon(
              Icons.calendar_today_outlined,
              size: 18,
            ),
            label: Text(
              fechaFiltro == null
                  ? 'Todas las fechas'
                  : fmtDay!.format(fechaFiltro!),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.centerLeft,
            ),
          ),
        ),
        if (fechaFiltro != null)
          IconButton(
            onPressed: onClearFecha,
            icon: const Icon(Icons.close),
            tooltip: 'Quitar fecha',
          ),
        TextButton.icon(
          onPressed: onLimpiar,
          icon: const Icon(
            Icons.filter_alt_off_outlined,
            size: 18,
          ),
          label: const Text(
            'Limpiar',
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    if (mostrarSoloFiltros) return filtros;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Historial de bodega',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'Entregas y rechazos de bodega, separados por día y origen',
          style: TextStyle(
            fontSize: 13,
            color: TecneroTheme.textoSecundario,
          ),
        ),
        const SizedBox(height: 14),
        if (loading)
          const LinearProgressIndicator(minHeight: 2)
        else if (isMobile)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onAbrirFiltros,
              icon: const Icon(Icons.tune_outlined, size: 18),
              label: const Text('Filtros'),
            ),
          )
        else
          filtros,
      ],
    );
  }
}

class _DropdownSelectedText extends StatelessWidget {
  final String text;

  const _DropdownSelectedText(this.text);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        softWrap: false,
      ),
    );
  }
}

class _ResumenHistorial extends StatelessWidget {
  final List<Solicitud> solicitudes;

  const _ResumenHistorial({
    required this.solicitudes,
  });

  @override
  Widget build(BuildContext context) {
    final directos = solicitudes.where(_esDespachoDirecto).length;
    final entregadas = solicitudes.where((s) => s.estado == 'entregada').length;
    final rechazadas = solicitudes.where((s) => s.estado == 'rechazada').length;
    final materiales = solicitudes.fold<int>(
      0,
      (total, s) => total + s.detalles.length,
    );

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _MetricChip(
          icon: Icons.local_shipping_outlined,
          label: 'Registros',
          value: '${solicitudes.length}',
          color: const Color(0xFF2563EB),
        ),
        _MetricChip(
          icon: Icons.check_circle_outline,
          label: 'Entregadas',
          value: '$entregadas',
          color: const Color(0xFF059669),
        ),
        _MetricChip(
          icon: Icons.cancel_outlined,
          label: 'Rechazadas',
          value: '$rechazadas',
          color: const Color(0xFFDC2626),
        ),
        _MetricChip(
          icon: Icons.storefront_outlined,
          label: 'Directos',
          value: '$directos',
          color: const Color(0xFF0284C7),
        ),
        _MetricChip(
          icon: Icons.inventory_2_outlined,
          label: 'Materiales',
          value: '$materiales',
          color: TecneroTheme.naranja,
        ),
      ],
    );
  }
}

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MetricChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: Responsive.isMobile(context) ? double.infinity : 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: TecneroTheme.grisBorde),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
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

class _DiaHistorialSection extends StatelessWidget {
  final DateTime fecha;
  final List<Solicitud> solicitudes;

  const _DiaHistorialSection({
    required this.fecha,
    required this.solicitudes,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Text(
                  _labelDia(fecha),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: TecneroTheme.azulOscuro,
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
          ...solicitudes.map((s) => _HistorialEntregaCard(solicitud: s)),
        ],
      ),
    );
  }
}

class _HistorialEntregaCard extends StatefulWidget {
  final Solicitud solicitud;

  const _HistorialEntregaCard({
    required this.solicitud,
  });

  @override
  State<_HistorialEntregaCard> createState() => _HistorialEntregaCardState();
}

class _HistorialEntregaCardState extends State<_HistorialEntregaCard> {
  bool _expandido = false;
  final _fmtDate = DateFormat('dd/MM/yyyy HH:mm');

  @override
  Widget build(BuildContext context) {
    final s = widget.solicitud;
    final directo = _esDespachoDirecto(s);
    final rechazado = s.estado == 'rechazada';
    final fechaEntrega = _fechaEntrega(s);
    final color = rechazado
        ? const Color(0xFFDC2626)
        : directo
            ? const Color(0xFF0284C7)
            : const Color(0xFF059669);

    return Card(
      color: rechazado
          ? const Color(0xFFFEE2E2)
          : directo
              ? const Color(0xFFF0F9FF)
              : Colors.white,
      elevation: directo ? 2 : 1,
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => setState(() => _expandido = !_expandido),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: color, width: directo ? 6 : 4),
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      rechazado
                          ? Icons.cancel_outlined
                          : directo
                              ? Icons.storefront_outlined
                              : Icons.check_circle_outline,
                      size: 18,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
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
                            _OrigenBadge(directo: directo),
                            EstadoBadge(estado: s.estado),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${s.solicitanteNombre.isEmpty ? "Sin operario" : s.solicitanteNombre} · ${s.lineaNombre.isEmpty ? "Sin fábrica" : s.lineaNombre}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          rechazado
                              ? 'Rechazada: ${_fmtDate.format(fechaEntrega)}'
                              : 'Despachado: ${_fmtDate.format(fechaEntrega)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (!Responsive.isMobile(context))
                    Text(
                      '${s.detalles.length} materiales',
                      style: const TextStyle(
                        fontSize: 11,
                        color: TecneroTheme.textoSecundario,
                      ),
                    ),
                  const SizedBox(width: 10),
                  Icon(
                    _expandido ? Icons.expand_less : Icons.expand_more,
                    color: TecneroTheme.textoSecundario,
                    size: 18,
                  ),
                ],
              ),
              if (_expandido) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                _InfoGrid(
                  fmtDate: _fmtDate,
                  solicitud: s,
                  directo: directo,
                  rechazado: rechazado,
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    rechazado
                        ? 'Materiales solicitados (${s.detalles.length})'
                        : 'Materiales entregados (${s.detalles.length})',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: TecneroTheme.textoPrimario,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _MaterialesTable(detalles: s.detalles),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _OrigenBadge extends StatelessWidget {
  final bool directo;

  const _OrigenBadge({
    required this.directo,
  });

  @override
  Widget build(BuildContext context) {
    final color = directo ? const Color(0xFF0369A1) : const Color(0xFF047857);
    final background =
        directo ? const Color(0xFFE0F2FE) : const Color(0xFFD1FAE5);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        directo ? 'DESPACHO DIRECTO' : 'PEDIDO DE PLANTA',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _InfoGrid extends StatelessWidget {
  final Solicitud solicitud;
  final DateFormat fmtDate;
  final bool directo;
  final bool rechazado;

  const _InfoGrid({
    required this.solicitud,
    required this.fmtDate,
    required this.directo,
    required this.rechazado,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _InfoItem(
          label: 'Operario',
          value: solicitud.solicitanteNombre.isEmpty
              ? 'No registrado'
              : solicitud.solicitanteNombre,
          icon: Icons.person_outline,
        ),
        _InfoItem(
          label: 'Fábrica / línea',
          value: solicitud.lineaNombre.isEmpty
              ? 'No registrada'
              : solicitud.lineaNombre,
          icon: Icons.factory_outlined,
        ),
        _InfoItem(
          label: 'Hora de solicitud',
          value: fmtDate.format(solicitud.fecha),
          icon: Icons.event_note_outlined,
        ),
        _InfoItem(
          label: rechazado ? 'Hora de rechazo' : 'Hora de despacho',
          value: fmtDate.format(_fechaEntrega(solicitud)),
          icon: Icons.local_shipping_outlined,
        ),
        _InfoItem(
          label: rechazado ? 'Rechazó' : 'Despachó',
          value: solicitud.aprobadoPor == null || solicitud.aprobadoPor!.isEmpty
              ? 'No registrado'
              : solicitud.aprobadoPor!,
          icon: Icons.badge_outlined,
        ),
        _InfoItem(
          label: 'Origen',
          value: directo
              ? 'Despacho directo de bodega'
              : 'Solicitud realizada por planta',
          icon: directo ? Icons.storefront_outlined : Icons.assignment_outlined,
        ),
        if (solicitud.observaciones != null &&
            solicitud.observaciones!.isNotEmpty)
          _InfoItem(
            label: 'Observaciones',
            value: solicitud.observaciones!,
            icon: Icons.notes_outlined,
            wide: true,
          ),
      ],
    );
  }
}

class _InfoItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool wide;

  const _InfoItem({
    required this.label,
    required this.value,
    required this.icon,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: wide || Responsive.isMobile(context) ? double.infinity : 230,
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MaterialesTable extends StatelessWidget {
  final List<DetalleSolicitud> detalles;

  const _MaterialesTable({
    required this.detalles,
  });

  @override
  Widget build(BuildContext context) {
    if (detalles.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: TecneroTheme.grisClaro,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'No hay materiales registrados en esta entrega',
          style: TextStyle(
            fontSize: 12,
            color: TecneroTheme.textoSecundario,
          ),
        ),
      );
    }

    if (Responsive.isMobile(context)) {
      return Column(
        children: detalles
            .map(
              (d) => Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: TecneroTheme.grisBorde),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            d.materialNombre,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
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
                    Text(
                      '${_formatCantidad(d.cantidad)} ${d.unidadMedida}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: TecneroTheme.textoPrimario,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      );
    }

    return Table(
      columnWidths: const {
        0: FlexColumnWidth(3),
        1: FixedColumnWidth(90),
        2: FixedColumnWidth(80),
      },
      children: [
        TableRow(
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: TecneroTheme.grisBorde),
            ),
          ),
          children: ['Material', 'Cantidad', 'Unidad']
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
        ...detalles.map(
          (d) => TableRow(
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
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 4,
                ),
                child: Text(
                  _formatCantidad(d.cantidad),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 4,
                ),
                child: Text(
                  d.unidadMedida,
                  style: const TextStyle(
                    fontSize: 12,
                    color: TecneroTheme.textoSecundario,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyHistorial extends StatelessWidget {
  const _EmptyHistorial();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history_outlined,
              size: 48,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 12),
            const Text(
              'Sin registros para mostrar',
              style: TextStyle(color: TecneroTheme.textoSecundario),
            ),
            const SizedBox(height: 4),
            const Text(
              'Ajusta los filtros o registra nuevas entregas o rechazos',
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

DateTime _fechaEntrega(Solicitud solicitud) {
  return solicitud.fechaEntrega ?? solicitud.fechaAprobacion ?? solicitud.fecha;
}

bool _esDespachoDirecto(Solicitud solicitud) {
  if (solicitud.origen == 'bodega_directo') return true;

  return (solicitud.observaciones ?? '')
      .toLowerCase()
      .contains('despacho registrado directamente en bodega');
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
