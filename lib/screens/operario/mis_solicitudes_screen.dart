// Pantalla del operario para revisar sus solicitudes y su estado.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';
import '../../services/providers.dart';
import '../../services/api_service.dart';
import '../../models/models.dart' as models;
import '../../widgets/responsive.dart';

class MisSolicitudesScreen extends ConsumerStatefulWidget {
  const MisSolicitudesScreen({super.key});

  @override
  ConsumerState<MisSolicitudesScreen> createState() =>
      _MisSolicitudesScreenState();
}

class _MisSolicitudesScreenState extends ConsumerState<MisSolicitudesScreen> {
  final _busquedaCtrl = TextEditingController();
  final _fmtDay = DateFormat('dd/MM/yyyy');

  DateTime? _fechaFiltro;
  String _estadoFiltro = 'todos';
  String _origenFiltro = 'todos';
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
      initialDate: _fechaFiltro ?? DateTime(ahora.year, ahora.month, ahora.day),
      firstDate: DateTime(2020),
      lastDate: DateTime(ahora.year + 1),
    );

    if (seleccion != null) {
      setState(() {
        _fechaFiltro = DateTime(
          seleccion.year,
          seleccion.month,
          seleccion.day,
        );
      });
    }
  }

  void _limpiarFiltros() {
    setState(() {
      _fechaFiltro = null;
      _estadoFiltro = 'todos';
      _origenFiltro = 'todos';
      _busqueda = '';
      _busquedaCtrl.clear();
    });
  }

  Future<void> _abrirFiltrosMobile() async {
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
          child: _MisSolicitudesFiltros(
            busquedaCtrl: _busquedaCtrl,
            estadoFiltro: _estadoFiltro,
            origenFiltro: _origenFiltro,
            fechaFiltro: _fechaFiltro,
            fmtDay: _fmtDay,
            onBuscar: (value) => setState(() => _busqueda = value),
            onEstadoChanged: (value) => setState(() => _estadoFiltro = value),
            onOrigenChanged: (value) => setState(() => _origenFiltro = value),
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
    final solicitudes = ref.watch(misSolicitudesProvider);
    final isMobile = Responsive.isMobile(context);

    return Scaffold(
      backgroundColor: TecneroTheme.grisClaro,
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: Responsive.headerPadding(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mis solicitudes',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Pedidos y despachos registrados por bodega',
                  style: TextStyle(
                    fontSize: 13,
                    color: TecneroTheme.textoSecundario,
                  ),
                ),
                const SizedBox(height: 12),
                if (isMobile)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _abrirFiltrosMobile,
                      icon: const Icon(Icons.tune_outlined, size: 18),
                      label: const Text('Filtros'),
                    ),
                  )
                else
                  _MisSolicitudesFiltros(
                    busquedaCtrl: _busquedaCtrl,
                    estadoFiltro: _estadoFiltro,
                    origenFiltro: _origenFiltro,
                    fechaFiltro: _fechaFiltro,
                    fmtDay: _fmtDay,
                    onBuscar: (value) => setState(() => _busqueda = value),
                    onEstadoChanged: (value) =>
                        setState(() => _estadoFiltro = value),
                    onOrigenChanged: (value) =>
                        setState(() => _origenFiltro = value),
                    onFechaTap: _seleccionarFecha,
                    onClearFecha: () => setState(() => _fechaFiltro = null),
                    onLimpiar: _limpiarFiltros,
                  ),
              ],
            ),
          ),
          Expanded(
            child: solicitudes.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (lista) {
                final filtradas = _filtrar(lista);
                final grupos = _agruparPorDia(filtradas);

                if (filtradas.isEmpty) {
                  return const _Empty();
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(misSolicitudesProvider);
                    await ref.read(misSolicitudesProvider.future);
                  },
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      isMobile ? 12 : 20,
                      14,
                      isMobile ? 12 : 20,
                      24,
                    ),
                    children: [
                      _ResumenMisSolicitudes(solicitudes: filtradas),
                      const SizedBox(height: 14),
                      ...grupos.entries.map(
                        (entry) => _DiaSolicitudesSection(
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

  List<models.Solicitud> _filtrar(List<models.Solicitud> solicitudes) {
    final query = _normalizarTexto(_busqueda);

    return solicitudes.where((s) {
      final despachoDirecto = _esDespachoDirecto(s);
      final fechaActividad = _fechaActividad(s);

      final matchEstado = _estadoFiltro == 'todos' ||
          _normalizarTexto(s.estado) == _estadoFiltro;

      final matchOrigen = switch (_origenFiltro) {
        'todos' => true,
        'directo' => despachoDirecto,
        'planta' => !despachoDirecto,
        _ => true,
      };

      final matchFecha =
          _fechaFiltro == null || _mismoDia(fechaActividad, _fechaFiltro!);

      final texto = _normalizarTexto([
        s.numero,
        s.lineaNombre,
        s.aprobadoPor ?? '',
        s.observaciones ?? '',
        s.estado,
        s.origen,
        ...s.detalles.expand(
          (d) => [
            d.materialNombre,
            d.materialCodigo,
            d.unidadMedida,
          ],
        ),
      ].join(' '));

      final matchBusqueda = query.isEmpty || texto.contains(query);

      return matchEstado && matchOrigen && matchFecha && matchBusqueda;
    }).toList()
      ..sort((a, b) => _fechaActividad(b).compareTo(_fechaActividad(a)));
  }

  Map<DateTime, List<models.Solicitud>> _agruparPorDia(
    List<models.Solicitud> solicitudes,
  ) {
    final grupos = <DateTime, List<models.Solicitud>>{};

    for (final solicitud in solicitudes) {
      final fecha = _fechaActividad(solicitud);
      final dia = DateTime(fecha.year, fecha.month, fecha.day);
      grupos.putIfAbsent(dia, () => []).add(solicitud);
    }

    return Map.fromEntries(
      grupos.entries.toList()..sort((a, b) => b.key.compareTo(a.key)),
    );
  }
}

class _MisSolicitudesFiltros extends StatelessWidget {
  final TextEditingController busquedaCtrl;
  final String estadoFiltro;
  final String origenFiltro;
  final DateTime? fechaFiltro;
  final DateFormat fmtDay;
  final ValueChanged<String> onBuscar;
  final ValueChanged<String> onEstadoChanged;
  final ValueChanged<String> onOrigenChanged;
  final VoidCallback onFechaTap;
  final VoidCallback onClearFecha;
  final VoidCallback onLimpiar;

  const _MisSolicitudesFiltros({
    required this.busquedaCtrl,
    required this.estadoFiltro,
    required this.origenFiltro,
    required this.fechaFiltro,
    required this.fmtDay,
    required this.onBuscar,
    required this.onEstadoChanged,
    required this.onOrigenChanged,
    required this.onFechaTap,
    required this.onClearFecha,
    required this.onLimpiar,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: isMobile ? double.infinity : 300,
          child: TextField(
            controller: busquedaCtrl,
            decoration: const InputDecoration(
              hintText: 'Buscar solicitud, línea o material...',
              prefixIcon: Icon(Icons.search, size: 18),
              isDense: true,
            ),
            onChanged: onBuscar,
          ),
        ),
        SizedBox(
          width: isMobile ? double.infinity : 190,
          child: DropdownButtonFormField<String>(
            initialValue: estadoFiltro,
            isExpanded: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.tune_outlined, size: 18),
              isDense: true,
            ),
            selectedItemBuilder: (context) {
              return const [
                _DropdownSelectedText('Todos'),
                _DropdownSelectedText('Pedidos'),
                _DropdownSelectedText('Despachados'),
                _DropdownSelectedText('Rechazados'),
                _DropdownSelectedText('Aprobados'),
              ];
            },
            items: const [
              DropdownMenuItem(
                value: 'todos',
                child: Text('Todos'),
              ),
              DropdownMenuItem(
                value: 'pendiente',
                child: Text('Pedidos'),
              ),
              DropdownMenuItem(
                value: 'entregada',
                child: Text('Despachados'),
              ),
              DropdownMenuItem(
                value: 'rechazada',
                child: Text('Rechazados'),
              ),
              DropdownMenuItem(
                value: 'aprobada',
                child: Text('Aprobados'),
              ),
            ],
            onChanged: (value) {
              if (value != null) onEstadoChanged(value);
            },
          ),
        ),
        SizedBox(
          width: isMobile ? double.infinity : 230,
          child: DropdownButtonFormField<String>(
            initialValue: origenFiltro,
            isExpanded: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.route_outlined, size: 18),
              isDense: true,
            ),
            selectedItemBuilder: (context) {
              return const [
                _DropdownSelectedText('Todos los orígenes'),
                _DropdownSelectedText('Pedidos de planta'),
                _DropdownSelectedText('Despacho directo'),
              ];
            },
            items: const [
              DropdownMenuItem(
                value: 'todos',
                child: Text('Todos los orígenes'),
              ),
              DropdownMenuItem(
                value: 'planta',
                child: Text('Pedidos de planta'),
              ),
              DropdownMenuItem(
                value: 'directo',
                child: Text('Despacho directo'),
              ),
            ],
            onChanged: (value) {
              if (value != null) onOrigenChanged(value);
            },
          ),
        ),
        SizedBox(
          width: isMobile ? double.infinity : 210,
          child: InkWell(
            onTap: onFechaTap,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: TecneroTheme.grisBorde),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      fechaFiltro == null
                          ? 'Todas las fechas'
                          : fmtDay.format(fechaFiltro!),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
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
          icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
          label: const Text(
            'Limpiar',
            overflow: TextOverflow.ellipsis,
          ),
        ),
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

class _ResumenMisSolicitudes extends StatelessWidget {
  final List<models.Solicitud> solicitudes;

  const _ResumenMisSolicitudes({
    required this.solicitudes,
  });

  @override
  Widget build(BuildContext context) {
    final pedidos = solicitudes.where((s) => s.estado == 'pendiente').length;
    final despachados =
        solicitudes.where((s) => s.estado == 'entregada').length;
    final directos = solicitudes.where(_esDespachoDirecto).length;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _MetricChip(
          icon: Icons.receipt_long_outlined,
          label: 'Solicitudes',
          value: '${solicitudes.length}',
        ),
        _MetricChip(
          icon: Icons.schedule_outlined,
          label: 'Pedidos',
          value: '$pedidos',
          color: const Color(0xFFF59E0B),
        ),
        _MetricChip(
          icon: Icons.local_shipping_outlined,
          label: 'Despachados',
          value: '$despachados',
          color: const Color(0xFF059669),
        ),
        _MetricChip(
          icon: Icons.storefront_outlined,
          label: 'Directos',
          value: '$directos',
          color: const Color(0xFF0284C7),
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
    this.color = TecneroTheme.azulOscuro,
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

class _DiaSolicitudesSection extends StatelessWidget {
  final DateTime fecha;
  final List<models.Solicitud> solicitudes;

  const _DiaSolicitudesSection({
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
          ...solicitudes.map((s) => _SolicitudCard(solicitud: s)),
        ],
      ),
    );
  }
}

class _SolicitudCard extends ConsumerStatefulWidget {
  final models.Solicitud solicitud;

  const _SolicitudCard({
    required this.solicitud,
  });

  @override
  ConsumerState<_SolicitudCard> createState() => _SolicitudCardState();
}

class _SolicitudCardState extends ConsumerState<_SolicitudCard> {
  bool _expandido = false;
  final _fmtDate = DateFormat('dd/MM/yyyy HH:mm');

  Future<void> _abrirEditar() async {
    final actualizado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EditarSolicitudDialog(
        solicitud: widget.solicitud,
      ),
    );

    if (actualizado == true) {
      ref.invalidate(misSolicitudesProvider);
      ref.invalidate(solicitudesPendientesProvider);

      await ref.read(misSolicitudesProvider.future);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solicitud actualizada correctamente'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.solicitud;
    final estado = _estadoVisual(s);
    final fechaActividad = _fechaActividad(s);
    final despachoDirecto = _esDespachoDirecto(s);

    return Card(
      color: despachoDirecto ? const Color(0xFFF0F9FF) : Colors.white,
      elevation: despachoDirecto ? 2 : 1,
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => setState(() => _expandido = !_expandido),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: despachoDirecto ? const Color(0xFF0284C7) : estado.color,
                width: despachoDirecto ? 6 : 4,
              ),
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (despachoDirecto) ...[
                const _DespachoDirectoNotice(),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: estado.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      estado.icon,
                      size: 18,
                      color: estado.color,
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
                            _ActividadBadge(estado: estado),
                            if (despachoDirecto) const _DespachoDirectoBadge(),
                            EstadoBadge(estado: s.estado),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          s.lineaNombre.isEmpty ? 'Sin línea' : s.lineaNombre,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          s.estado == 'entregada'
                              ? 'Despachado: ${_fmtDate.format(fechaActividad)}'
                              : 'Pedido: ${_fmtDate.format(s.fecha.toLocal())}',
                          style: TextStyle(
                            fontSize: 11,
                            color: estado.color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
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
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoPill(
                      icon: Icons.event_note_outlined,
                      label: 'Hora de pedido',
                      value: _fmtDate.format(s.fecha.toLocal()),
                    ),
                    _InfoPill(
                      icon: s.estado == 'entregada'
                          ? Icons.local_shipping_outlined
                          : Icons.schedule_outlined,
                      label: s.estado == 'entregada'
                          ? 'Hora de despacho'
                          : 'Estado del despacho',
                      value: s.estado == 'entregada'
                          ? _fmtDate.format(
                              (s.fechaEntrega ?? s.fecha).toLocal(),
                            )
                          : 'Pendiente en bodega',
                    ),
                    if (s.aprobadoPor != null && s.aprobadoPor!.isNotEmpty)
                      _InfoPill(
                        icon: Icons.badge_outlined,
                        label: 'Despachó',
                        value: s.aprobadoPor!,
                      ),
                    if (despachoDirecto)
                      const _InfoPill(
                        icon: Icons.storefront_outlined,
                        label: 'Origen',
                        value: 'Despacho directo en bodega',
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                if (s.detalles.isEmpty)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Sin materiales registrados',
                      style: TextStyle(
                        fontSize: 12,
                        color: TecneroTheme.textoSecundario,
                      ),
                    ),
                  )
                else
                  ...s.detalles.map(
                    (d) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: TecneroTheme.naranja,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              d.materialNombre,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          Text(
                            '${_formatCantidad(d.cantidad)} ${d.unidadMedida}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: TecneroTheme.textoSecundario,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (s.observaciones != null && s.observaciones!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: TecneroTheme.grisClaro,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Observación: ${s.observaciones}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: TecneroTheme.textoSecundario,
                      ),
                    ),
                  ),
                ],
                if (s.estado == 'pendiente') ...[
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: _abrirEditar,
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Editar solicitud'),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _formatCantidad(double value) {
    if (value % 1 == 0) return value.toInt().toString();
    return value.toStringAsFixed(2);
  }
}

class _ActividadVisual {
  final String label;
  final Color color;
  final IconData icon;

  const _ActividadVisual({
    required this.label,
    required this.color,
    required this.icon,
  });
}

class _ActividadBadge extends StatelessWidget {
  final _ActividadVisual estado;

  const _ActividadBadge({
    required this.estado,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: estado.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        estado.label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: estado.color,
        ),
      ),
    );
  }
}

class _DespachoDirectoBadge extends StatelessWidget {
  const _DespachoDirectoBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFE0F2FE),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'DESPACHO DIRECTO DE BODEGA',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Color(0xFF0369A1),
        ),
      ),
    );
  }
}

class _DespachoDirectoNotice extends StatelessWidget {
  const _DespachoDirectoNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE0F2FE),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF7DD3FC)),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.storefront_outlined,
            size: 16,
            color: Color(0xFF0369A1),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Despacho directo de bodega: el material fue registrado por bodega sin solicitud previa del operario.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF075985),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: Responsive.isMobile(context) ? double.infinity : 230,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: TecneroTheme.grisClaro,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: TecneroTheme.grisBorde),
      ),
      child: Row(
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

_ActividadVisual _estadoVisual(models.Solicitud solicitud) {
  switch (solicitud.estado.toLowerCase()) {
    case 'entregada':
      return const _ActividadVisual(
        label: 'DESPACHADO',
        color: Color(0xFF059669),
        icon: Icons.local_shipping_outlined,
      );
    case 'rechazada':
      return const _ActividadVisual(
        label: 'RECHAZADO',
        color: Color(0xFFDC2626),
        icon: Icons.cancel_outlined,
      );
    case 'aprobada':
      return const _ActividadVisual(
        label: 'LISTO',
        color: Color(0xFF2563EB),
        icon: Icons.inventory_2_outlined,
      );
    default:
      return const _ActividadVisual(
        label: 'PEDIDO',
        color: Color(0xFFF59E0B),
        icon: Icons.schedule_outlined,
      );
  }
}

DateTime _fechaActividad(models.Solicitud solicitud) {
  final fecha = solicitud.estado == 'entregada'
      ? solicitud.fechaEntrega ?? solicitud.fecha
      : solicitud.fecha;

  return fecha.toLocal();
}

bool _esDespachoDirecto(models.Solicitud solicitud) {
  final origen = _normalizarTexto(solicitud.origen);
  final observaciones = _normalizarTexto(solicitud.observaciones ?? '');

  return origen == 'bodega_directo' ||
      origen == 'despacho_directo' ||
      origen == 'directo' ||
      observaciones.contains('despacho registrado directamente') ||
      observaciones.contains('despacho directo') ||
      observaciones.contains('sin solicitud previa');
}

bool _mismoDia(DateTime a, DateTime b) {
  final localA = a.toLocal();
  final localB = b.toLocal();

  return localA.year == localB.year &&
      localA.month == localB.month &&
      localA.day == localB.day;
}

String _normalizarTexto(String value) {
  return value.trim().toLowerCase();
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

class _EditarSolicitudDialog extends ConsumerStatefulWidget {
  final models.Solicitud solicitud;

  const _EditarSolicitudDialog({
    required this.solicitud,
  });

  @override
  ConsumerState<_EditarSolicitudDialog> createState() =>
      _EditarSolicitudDialogState();
}

class _EditItemRow {
  models.Material? material;
  double cantidad;

  _EditItemRow({
    this.material,
    this.cantidad = 1,
  });
}

class _EditarSolicitudDialogState
    extends ConsumerState<_EditarSolicitudDialog> {
  models.LineaProduccion? _lineaSeleccionada;
  final List<_EditItemRow> _items = [];
  late final TextEditingController _obsCtrl;

  bool _inicializado = false;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _obsCtrl = TextEditingController(
      text: widget.solicitud.observaciones ?? '',
    );
  }

  @override
  void dispose() {
    _obsCtrl.dispose();
    super.dispose();
  }

  void _inicializar({
    required List<models.LineaProduccion> lineas,
    required List<models.Material> materiales,
  }) {
    if (_inicializado) return;

    try {
      _lineaSeleccionada = lineas.firstWhere(
        (l) => l.id == widget.solicitud.lineaId,
      );
    } catch (_) {
      _lineaSeleccionada = null;
    }

    for (final detalle in widget.solicitud.detalles) {
      models.Material? material;

      try {
        material = materiales.firstWhere(
          (m) => m.id == detalle.materialId,
        );
      } catch (_) {
        material = null;
      }

      _items.add(
        _EditItemRow(
          material: material,
          cantidad: detalle.cantidad <= 0 ? 1 : detalle.cantidad,
        ),
      );
    }

    if (_items.isEmpty) {
      _items.add(_EditItemRow());
    }

    _inicializado = true;
  }

  void _agregarItem() {
    setState(() {
      _items.add(_EditItemRow());
    });
  }

  void _eliminarItem(int index) {
    if (_items.length <= 1) return;

    setState(() {
      _items.removeAt(index);
      _error = null;
    });
  }

  String? _materialDuplicado() {
    final usados = <String>{};

    for (final item in _items) {
      final materialId = item.material?.id;
      if (materialId == null) continue;

      if (!usados.add(materialId)) {
        return item.material?.nombre ?? 'Material repetido';
      }
    }

    return null;
  }

  Future<void> _guardar() async {
    if (_lineaSeleccionada == null) {
      setState(() => _error = 'Selecciona una línea de producción');
      return;
    }

    if (_items.any((i) => i.material == null)) {
      setState(() => _error = 'Completa todos los materiales');
      return;
    }

    if (_items.any((i) => i.cantidad <= 0)) {
      setState(() => _error = 'Las cantidades deben ser mayores a 0');
      return;
    }

    final duplicado = _materialDuplicado();
    if (duplicado != null) {
      setState(
        () => _error =
            'El material "$duplicado" ya está en la solicitud. Edita esa fila o elimina la repetida.',
      );
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      await ApiService().editarSolicitud(
        id: widget.solicitud.id,
        lineaId: _lineaSeleccionada!.id,
        lineaNombre: _lineaSeleccionada!.nombre,
        observaciones: _obsCtrl.text.trim().isEmpty ? null : _obsCtrl.text,
        items: _items
            .map(
              (i) => {
                'materialId': i.material!.id,
                'materialNombre': i.material!.nombre,
                'materialCodigo': i.material!.codigo,
                'unidadMedida': i.material!.unidadMedida,
                'cantidad': i.cantidad,
              },
            )
            .toList(),
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _guardando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lineasAsync = ref.watch(lineasProvider);
    final materialesAsync = ref.watch(materialesProvider);

    return Dialog(
      insetPadding: EdgeInsets.all(Responsive.isMobile(context) ? 10 : 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 760,
          maxHeight: Responsive.isMobile(context)
              ? MediaQuery.sizeOf(context).height - 20
              : 720,
        ),
        child: lineasAsync.when(
          loading: () => const SizedBox(
            height: 260,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => _DialogError(
            message: 'Error cargando líneas: $e',
          ),
          data: (lineas) => materialesAsync.when(
            loading: () => const SizedBox(
              height: 260,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => _DialogError(
              message: 'Error cargando materiales: $e',
            ),
            data: (materiales) {
              _inicializar(
                lineas: lineas,
                materiales: materiales,
              );

              return Column(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: Responsive.isMobile(context) ? 16 : 22,
                      vertical: 16,
                    ),
                    decoration: const BoxDecoration(
                      color: TecneroTheme.azulOscuro,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Editar solicitud',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Solo puedes editar solicitudes pendientes',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: _guardando
                              ? null
                              : () => Navigator.of(context).pop(false),
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(
                        Responsive.isMobile(context) ? 16 : 22,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Línea de producción',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<models.LineaProduccion>(
                            initialValue: _lineaSeleccionada,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              hintText: 'Selecciona la línea de producción',
                            ),
                            items: lineas
                                .map(
                                  (l) =>
                                      DropdownMenuItem<models.LineaProduccion>(
                                    value: l,
                                    child: Text(
                                      l.nombre,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: _guardando
                                ? null
                                : (v) {
                                    setState(() {
                                      _lineaSeleccionada = v;
                                    });
                                  },
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Materiales',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Edita los materiales y cantidades solicitadas',
                            style: TextStyle(
                              fontSize: 11,
                              color: TecneroTheme.textoSecundario,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (!Responsive.isMobile(context)) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: TecneroTheme.grisClaro,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                children: [
                                  Expanded(
                                    flex: 5,
                                    child: Text(
                                      'Material',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: TecneroTheme.textoSecundario,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  SizedBox(
                                    width: 100,
                                    child: Text(
                                      'Cantidad',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: TecneroTheme.textoSecundario,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  SizedBox(
                                    width: 70,
                                    child: Text(
                                      'Unidad',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: TecneroTheme.textoSecundario,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 40),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          ...List.generate(
                            _items.length,
                            (index) => _EditarMaterialRow(
                              item: _items[index],
                              materiales: materiales,
                              puedeEliminar: _items.length > 1,
                              onMaterialChange: (m) {
                                if (m != null &&
                                    _items.asMap().entries.any(
                                          (entry) =>
                                              entry.key != index &&
                                              entry.value.material?.id == m.id,
                                        )) {
                                  setState(
                                    () => _error =
                                        'Ese material ya está seleccionado en otra fila.',
                                  );
                                  return;
                                }

                                setState(() {
                                  _items[index].material = m;
                                  _error = null;
                                });
                              },
                              onCantidadChange: (cantidad) {
                                setState(() {
                                  _items[index].cantidad = cantidad;
                                  _error = null;
                                });
                              },
                              onRemove: () => _eliminarItem(index),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _guardando ? null : _agregarItem,
                            icon: const Icon(
                              Icons.add_circle_outline,
                              size: 16,
                            ),
                            label: const Text('Agregar otro material'),
                            style: TextButton.styleFrom(
                              foregroundColor: TecneroTheme.azulOscuro,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Divider(),
                          const SizedBox(height: 16),
                          const Text(
                            'Observaciones',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _obsCtrl,
                            enabled: !_guardando,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              hintText: 'Información adicional...',
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 16),
                            _ErrorBox(msg: _error!),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        top: BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      runSpacing: 8,
                      spacing: 10,
                      children: [
                        TextButton(
                          onPressed: _guardando
                              ? null
                              : () => Navigator.of(context).pop(false),
                          child: const Text('Cancelar'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _guardando ? null : _guardar,
                          icon: _guardando
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save_outlined, size: 16),
                          label: Text(
                            _guardando ? 'Guardando...' : 'Guardar cambios',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _EditarMaterialRow extends StatelessWidget {
  final _EditItemRow item;
  final List<models.Material> materiales;
  final bool puedeEliminar;
  final Function(models.Material?) onMaterialChange;
  final Function(double) onCantidadChange;
  final VoidCallback onRemove;

  const _EditarMaterialRow({
    required this.item,
    required this.materiales,
    required this.puedeEliminar,
    required this.onMaterialChange,
    required this.onCantidadChange,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final mobile = Responsive.isMobile(context);

    final materialField = DropdownButtonFormField<models.Material>(
      initialValue: item.material,
      isExpanded: true,
      decoration: const InputDecoration(
        hintText: 'Seleccionar material...',
        contentPadding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
      items: materiales
          .map(
            (m) => DropdownMenuItem<models.Material>(
              value: m,
              child: Text(
                '${m.codigo} — ${m.nombre}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          )
          .toList(),
      onChanged: onMaterialChange,
    );

    final cantidadField = TextFormField(
      key: ValueKey('${item.material?.id}-${item.cantidad}'),
      initialValue: _formatInitialCantidad(item.cantidad),
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
      ),
      decoration: const InputDecoration(
        labelText: 'Cantidad',
        contentPadding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
      style: const TextStyle(fontSize: 13),
      onChanged: (v) {
        final value = double.tryParse(v.replaceAll(',', '.')) ?? 0;
        onCantidadChange(value);
      },
    );

    final unidadText = Text(
      item.material?.unidadMedida ?? '—',
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 12,
        color: TecneroTheme.textoSecundario,
      ),
    );

    if (mobile) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: TecneroTheme.grisClaro,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: TecneroTheme.grisBorde),
        ),
        child: Column(
          children: [
            materialField,
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: cantidadField),
                const SizedBox(width: 12),
                Expanded(
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Unidad'),
                    child: unidadText,
                  ),
                ),
                if (puedeEliminar) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: onRemove,
                    icon: const Icon(
                      Icons.remove_circle_outline,
                      size: 20,
                      color: Color(0xFFEF4444),
                    ),
                    tooltip: 'Eliminar',
                  ),
                ],
              ],
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: materialField,
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: cantidadField,
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 70,
            child: unidadText,
          ),
          SizedBox(
            width: 40,
            child: puedeEliminar
                ? IconButton(
                    onPressed: onRemove,
                    icon: const Icon(
                      Icons.remove_circle_outline,
                      size: 20,
                      color: Color(0xFFEF4444),
                    ),
                    padding: EdgeInsets.zero,
                    tooltip: 'Eliminar',
                  )
                : const SizedBox(),
          ),
        ],
      ),
    );
  }

  static String _formatInitialCantidad(double value) {
    if (value % 1 == 0) return value.toInt().toString();
    return value.toString();
  }
}

class _DialogError extends StatelessWidget {
  final String message;

  const _DialogError({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF991B1B),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String msg;

  const _ErrorBox({
    required this.msg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline,
            size: 16,
            color: Color(0xFF991B1B),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              msg,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF991B1B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 48,
            color: Colors.grey,
          ),
          SizedBox(height: 12),
          Text(
            'No tienes solicitudes aún',
            style: TextStyle(
              color: TecneroTheme.textoSecundario,
            ),
          ),
        ],
      ),
    );
  }
}
