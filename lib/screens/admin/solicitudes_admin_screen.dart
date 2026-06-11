// Vista administrativa para revisar todas las solicitudes y su detalle.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';
import '../../services/providers.dart';
import '../../models/models.dart';
import '../../widgets/responsive.dart';

// ════════════════════════════════════════════════════════════
// SOLICITUDES ADMIN SCREEN
// ════════════════════════════════════════════════════════════

class SolicitudesAdminScreen extends ConsumerStatefulWidget {
  const SolicitudesAdminScreen({super.key});

  @override
  ConsumerState<SolicitudesAdminScreen> createState() =>
      _SolicitudesAdminScreenState();
}

class _SolicitudesAdminScreenState
    extends ConsumerState<SolicitudesAdminScreen> {
  String _estadoFiltro = 'todos';
  String _busqueda = '';
  String? _ultimoContextoSeleccion;
  Solicitud? _seleccionada;

  final _fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  final _fmtDate = DateFormat('dd/MM/yyyy HH:mm');

  void _abrirDetalleMobile(Solicitud solicitud) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: TecneroTheme.grisClaro,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return _DetalleAdmin(
              solicitud: solicitud,
              fmt: _fmt,
              fmtDate: _fmtDate,
              scrollController: scrollController,
              showCloseButton: true,
            );
          },
        );
      },
    );
  }

  Future<void> _recargarSolicitudes() async {
    ref.invalidate(todasSolicitudesProvider);
    await ref.read(todasSolicitudesProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final todas = ref.watch(todasSolicitudesProvider);
    final isMobile = Responsive.isMobile(context);

    return Scaffold(
      backgroundColor: TecneroTheme.grisClaro,
      body: Column(
        children: [
          _SolicitudesHeader(
            estadoFiltro: _estadoFiltro,
            onReload: _recargarSolicitudes,
            onFiltroChanged: (value) {
              setState(() => _estadoFiltro = value);
            },
          ),
          Expanded(
            child: todas.when(
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
              data: (lista) {
                final filtrada = lista.where((s) {
                  final query = _busqueda.trim().toLowerCase();

                  final matchEstado =
                      _estadoFiltro == 'todos' || s.estado == _estadoFiltro;

                  final matchBusq = query.isEmpty ||
                      s.numero.toLowerCase().contains(query) ||
                      s.solicitanteNombre.toLowerCase().contains(query) ||
                      s.lineaNombre.toLowerCase().contains(query);

                  return matchEstado && matchBusq;
                }).toList()
                  ..sort(
                    (a, b) => _fechaActividad(b).compareTo(_fechaActividad(a)),
                  );

                if (!isMobile) {
                  final contextoSeleccion = '$_estadoFiltro|$_busqueda';
                  final contextoCambio =
                      _ultimoContextoSeleccion != contextoSeleccion;
                  final seleccionValida = _seleccionada != null &&
                      filtrada.any((s) => s.id == _seleccionada!.id);

                  if (filtrada.isNotEmpty &&
                      (contextoCambio || !seleccionValida)) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      setState(() {
                        _seleccionada = filtrada.first;
                        _ultimoContextoSeleccion = contextoSeleccion;
                      });
                    });
                  } else if (filtrada.isEmpty && _seleccionada != null) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      setState(() {
                        _seleccionada = null;
                        _ultimoContextoSeleccion = contextoSeleccion;
                      });
                    });
                  } else if (!contextoCambio) {
                    _ultimoContextoSeleccion = contextoSeleccion;
                  }
                }

                final listaWidget = _SolicitudesList(
                  solicitudes: filtrada,
                  seleccionada: _seleccionada,
                  fmt: _fmt,
                  fmtDate: _fmtDate,
                  busqueda: _busqueda,
                  onBusquedaChanged: (value) {
                    setState(() => _busqueda = value);
                  },
                  onTapSolicitud: (solicitud) {
                    if (isMobile) {
                      _abrirDetalleMobile(solicitud);
                    } else {
                      setState(() => _seleccionada = solicitud);
                    }
                  },
                );

                if (isMobile) {
                  return listaWidget;
                }

                return Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: listaWidget,
                    ),
                    Expanded(
                      flex: 3,
                      child: _seleccionada == null
                          ? const Center(
                              child: Text(
                                'Selecciona una solicitud',
                                style: TextStyle(
                                  color: TecneroTheme.textoSecundario,
                                ),
                              ),
                            )
                          : _DetalleAdmin(
                              solicitud: _seleccionada!,
                              fmt: _fmt,
                              fmtDate: _fmtDate,
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SolicitudesHeader extends StatelessWidget {
  final String estadoFiltro;
  final Future<void> Function() onReload;
  final ValueChanged<String> onFiltroChanged;

  const _SolicitudesHeader({
    required this.estadoFiltro,
    required this.onReload,
    required this.onFiltroChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    final filtros = ['todos', 'pendiente', 'entregada', 'rechazada'];

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: Responsive.headerPadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Todas las solicitudes',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: TecneroTheme.textoPrimario,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Control completo con costos reales',
                      style: TextStyle(
                        fontSize: 13,
                        color: TecneroTheme.textoSecundario,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onReload,
                icon: const Icon(Icons.refresh),
                tooltip: 'Recargar solicitudes',
              ),
            ],
          ),
          const SizedBox(height: 14),
          isMobile
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: filtros.map((e) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _FilterChip(
                          label: e == 'todos'
                              ? 'Todos'
                              : e[0].toUpperCase() + e.substring(1),
                          selected: estadoFiltro == e,
                          onTap: () => onFiltroChanged(e),
                        ),
                      );
                    }).toList(),
                  ),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: filtros.map((e) {
                    return _FilterChip(
                      label: e == 'todos'
                          ? 'Todos'
                          : e[0].toUpperCase() + e.substring(1),
                      selected: estadoFiltro == e,
                      onTap: () => onFiltroChanged(e),
                    );
                  }).toList(),
                ),
        ],
      ),
    );
  }
}

class _SolicitudesList extends StatelessWidget {
  final List<Solicitud> solicitudes;
  final Solicitud? seleccionada;
  final NumberFormat fmt;
  final DateFormat fmtDate;
  final String busqueda;
  final ValueChanged<String> onBusquedaChanged;
  final ValueChanged<Solicitud> onTapSolicitud;

  const _SolicitudesList({
    required this.solicitudes,
    required this.seleccionada,
    required this.fmt,
    required this.fmtDate,
    required this.busqueda,
    required this.onBusquedaChanged,
    required this.onTapSolicitud,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final grupos = _agruparPorDia(solicitudes);

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Buscar por número, solicitante o línea...',
              prefixIcon: Icon(Icons.search, size: 18),
            ),
            onChanged: onBusquedaChanged,
          ),
        ),
        Expanded(
          child: solicitudes.isEmpty
              ? const Center(
                  child: Text(
                    'Sin resultados',
                    style: TextStyle(
                      color: TecneroTheme.textoSecundario,
                    ),
                  ),
                )
              : ListView(
                  padding: EdgeInsets.fromLTRB(
                    isMobile ? 12 : 16,
                    0,
                    isMobile ? 12 : 16,
                    16,
                  ),
                  children: [
                    ...grupos.entries.map(
                      (entry) => _DiaSolicitudesAdminSection(
                        fecha: entry.key,
                        solicitudes: entry.value,
                        seleccionada: seleccionada,
                        fmt: fmt,
                        fmtDate: fmtDate,
                        onTapSolicitud: onTapSolicitud,
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _DiaSolicitudesAdminSection extends StatelessWidget {
  final DateTime fecha;
  final List<Solicitud> solicitudes;
  final Solicitud? seleccionada;
  final NumberFormat fmt;
  final DateFormat fmtDate;
  final ValueChanged<Solicitud> onTapSolicitud;

  const _DiaSolicitudesAdminSection({
    required this.fecha,
    required this.solicitudes,
    required this.seleccionada,
    required this.fmt,
    required this.fmtDate,
    required this.onTapSolicitud,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 2),
            child: Row(
              children: [
                Text(
                  _labelDia(fecha),
                  style: const TextStyle(
                    fontSize: 14,
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
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...solicitudes.map((s) {
            final sel = seleccionada?.id == s.id;
            return _SolicitudListCard(
              solicitud: s,
              selected: sel,
              fmt: fmt,
              fmtDate: fmtDate,
              onTap: () => onTapSolicitud(s),
            );
          }),
        ],
      ),
    );
  }
}

class _SolicitudListCard extends StatelessWidget {
  final Solicitud solicitud;
  final bool selected;
  final NumberFormat fmt;
  final DateFormat fmtDate;
  final VoidCallback onTap;

  const _SolicitudListCard({
    required this.solicitud,
    required this.selected,
    required this.fmt,
    required this.fmtDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = solicitud;
    final isMobile = Responsive.isMobile(context);
    final fechaActividad = _fechaActividad(s);
    final fechaLabel = s.estado == 'entregada' ? 'Despachado' : 'Pedido';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: selected ? TecneroTheme.naranja : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 12 : 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      s.numero,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: TecneroTheme.azulOscuro,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  EstadoBadge(estado: s.estado),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                s.solicitanteNombre,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                s.lineaNombre,
                style: const TextStyle(
                  fontSize: 11,
                  color: TecneroTheme.textoSecundario,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _MoneyText(
                          value: fmt.format(s.costoTotal),
                          fontSize: 14,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$fechaLabel: ${fmtDate.format(fechaActividad)}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: TecneroTheme.textoSecundario,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: _MoneyText(
                            value: fmt.format(s.costoTotal),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '$fechaLabel: ${fmtDate.format(fechaActividad)}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 10,
                              color: TecneroTheme.textoSecundario,
                            ),
                            overflow: TextOverflow.ellipsis,
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
}

class _MoneyText extends StatelessWidget {
  final String value;
  final double fontSize;

  const _MoneyText({
    required this.value,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      value.trim(),
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        color: TecneroTheme.naranja,
      ),
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _DetalleAdmin extends StatelessWidget {
  final Solicitud solicitud;
  final NumberFormat fmt;
  final DateFormat fmtDate;
  final ScrollController? scrollController;
  final bool showCloseButton;

  const _DetalleAdmin({
    required this.solicitud,
    required this.fmt,
    required this.fmtDate,
    this.scrollController,
    this.showCloseButton = false,
  });

  @override
  Widget build(BuildContext context) {
    final s = solicitud;
    final isMobile = Responsive.isMobile(context);

    return SingleChildScrollView(
      controller: scrollController,
      padding: Responsive.pagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showCloseButton)
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ),
          isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.numero,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: TecneroTheme.azulOscuro,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    EstadoBadge(estado: s.estado),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: Text(
                        s.numero,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: TecneroTheme.azulOscuro,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    EstadoBadge(estado: s.estado),
                  ],
                ),
          const SizedBox(height: 8),
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
            'Creado: ${fmtDate.format(s.fecha)}',
            style: const TextStyle(
              fontSize: 11,
              color: TecneroTheme.textoSecundario,
            ),
          ),
          if (s.aprobadoPor != null && s.fechaAprobacion != null)
            Text(
              'Aprobado por: ${s.aprobadoPor} — ${fmtDate.format(s.fechaAprobacion!)}',
              style: const TextStyle(
                fontSize: 11,
                color: TecneroTheme.textoSecundario,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 14 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Materiales con costos reales',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...s.detalles.map(
                    (d) => _DetalleMaterialItem(
                      detalle: d,
                      fmt: fmt,
                    ),
                  ),
                  const Divider(),
                  _CostoTotalBox(
                    label: 'COSTO TOTAL',
                    value: fmt.format(s.costoTotal).trim(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _DetalleMaterialItem extends StatelessWidget {
  final dynamic detalle;
  final NumberFormat fmt;

  const _DetalleMaterialItem({
    required this.detalle,
    required this.fmt,
  });

  String _cantidad(dynamic value) {
    final n = double.tryParse(value.toString()) ?? 0;
    if (n % 1 == 0) return n.toInt().toString();
    return n.toStringAsFixed(2);
  }

  String _money(NumberFormat fmt, dynamic value) {
    final n = double.tryParse(value.toString()) ?? 0;
    return fmt.format(n).trim();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final d = detalle;

    final cantidad = _cantidad(d.cantidad);
    final unidad = d.unidadMedida.toString();
    final precioUnitario = _money(fmt, d.precioUnitarioMomento);
    final subtotal = _money(fmt, d.subtotal);

    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: TecneroTheme.grisBorde),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                d.materialNombre,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: TecneroTheme.textoPrimario,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
              const SizedBox(height: 2),
              Text(
                d.materialCodigo,
                style: const TextStyle(
                  fontSize: 10,
                  color: TecneroTheme.textoSecundario,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _DetalleChip(
                    label: 'Cantidad',
                    value: '$cantidad $unidad',
                    color: TecneroTheme.azulOscuro,
                  ),
                  _DetalleChip(
                    label: 'Precio unit.',
                    value: '$precioUnitario / $unidad',
                    color: TecneroTheme.textoPrimario,
                  ),
                  _DetalleChip(
                    label: 'Subtotal',
                    value: subtotal,
                    color: TecneroTheme.naranja,
                    strong: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: TecneroTheme.grisBorde),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d.materialNombre,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: TecneroTheme.textoPrimario,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    d.materialCodigo,
                    style: const TextStyle(
                      fontSize: 10,
                      color: TecneroTheme.textoSecundario,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: _DetalleValueColumn(
                label: 'Cantidad',
                value: '$cantidad $unidad',
              ),
            ),
            Expanded(
              flex: 2,
              child: _DetalleValueColumn(
                label: 'Precio unit.',
                value: '$precioUnitario / $unidad',
              ),
            ),
            Expanded(
              flex: 2,
              child: _DetalleValueColumn(
                label: 'Subtotal',
                value: subtotal,
                color: TecneroTheme.naranja,
                strong: true,
                alignRight: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetalleValueColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final bool strong;
  final bool alignRight;

  const _DetalleValueColumn({
    required this.label,
    required this.value,
    this.color,
    this.strong = false,
    this.alignRight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            color: TecneroTheme.textoSecundario,
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 3),
        Text(
          value,
          textAlign: alignRight ? TextAlign.right : TextAlign.left,
          style: TextStyle(
            fontSize: 12,
            color: color ?? TecneroTheme.textoPrimario,
            fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _DetalleChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool strong;

  const _DetalleChip({
    required this.label,
    required this.value,
    required this.color,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 105),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: TecneroTheme.grisBorde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              color: TecneroTheme.textoSecundario,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _CostoTotalBox extends StatelessWidget {
  final String label;
  final String value;

  const _CostoTotalBox({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 14 : 16),
      decoration: BoxDecoration(
        color: TecneroTheme.azulOscuro,
        borderRadius: BorderRadius.circular(10),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Resumen del pedido',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value.trim(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            )
          : Row(
              children: [
                const Icon(
                  Icons.receipt_long_outlined,
                  color: Colors.white70,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  value.trim(),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? TecneroTheme.naranja : Colors.transparent,
          border: Border.all(
            color: selected ? TecneroTheme.naranja : TecneroTheme.grisBorde,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : TecneroTheme.textoSecundario,
          ),
        ),
      ),
    );
  }
}

Map<DateTime, List<Solicitud>> _agruparPorDia(List<Solicitud> solicitudes) {
  final grupos = <DateTime, List<Solicitud>>{};

  for (final solicitud in solicitudes) {
    final fecha = _fechaActividad(solicitud);
    final dia = DateTime(fecha.year, fecha.month, fecha.day);
    grupos.putIfAbsent(dia, () => []).add(solicitud);
  }

  return Map.fromEntries(
    grupos.entries.toList()..sort((a, b) => b.key.compareTo(a.key)),
  );
}

DateTime _fechaActividad(Solicitud solicitud) {
  return solicitud.fechaEntrega ?? solicitud.fecha;
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

// ════════════════════════════════════════════════════════════
// REPORTES SCREEN
// ════════════════════════════════════════════════════════════

class ReportesScreen extends ConsumerWidget {
  const ReportesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashData = ref.watch(dashboardProvider);
    final fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    return Scaffold(
      backgroundColor: TecneroTheme.grisClaro,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: Responsive.headerPadding(context),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reportes de costos',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Análisis completo para toma de decisiones comerciales',
                  style: TextStyle(
                    fontSize: 13,
                    color: TecneroTheme.textoSecundario,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: dashData.when(
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
              data: (data) {
                final porLinea = data['por_linea'] as List<dynamic>? ?? [];
                final topMats = data['top_materiales'] as List<dynamic>? ?? [];
                final totales = data['totales'] as Map<String, dynamic>? ?? {};

                return SingleChildScrollView(
                  padding: Responsive.pagePadding(context),
                  child: Column(
                    children: [
                      _ReporteCostoLineaCard(
                        porLinea: porLinea,
                        totales: totales,
                        fmt: fmt,
                      ),
                      const SizedBox(height: 16),
                      _ReporteTopMaterialesCard(
                        topMats: topMats,
                        fmt: fmt,
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
}

class _ReporteCostoLineaCard extends StatelessWidget {
  final List<dynamic> porLinea;
  final Map<String, dynamic> totales;
  final NumberFormat fmt;

  const _ReporteCostoLineaCard({
    required this.porLinea,
    required this.totales,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Card(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 14 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Costo por línea de producción',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Úsalo para calcular: Costo por unidad = Costo total ÷ Unidades producidas',
              style: TextStyle(
                fontSize: 11,
                color: TecneroTheme.textoSecundario,
              ),
            ),
            const SizedBox(height: 16),
            if (porLinea.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Sin datos',
                    style: TextStyle(
                      color: TecneroTheme.textoSecundario,
                    ),
                  ),
                ),
              )
            else if (isMobile)
              Column(
                children: [
                  ...porLinea.map(
                    (l) => _ReporteLineaMobileItem(
                      linea: _value(l, ['lineaNombre', 'linea_nombre']),
                      solicitudes: _value(
                        l,
                        ['totalSolicitudes', 'total_solicitudes'],
                      ),
                      costo: fmt.format(
                        _numValue(l, ['costoTotal', 'costo_total']),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _ReporteTotalMobileItem(
                    solicitudes: '${_numValue(
                      totales,
                      ['totalSolicitudes', 'total_solicitudes'],
                    ).toInt()}',
                    costo: fmt.format(
                      _numValue(totales, ['costoTotal', 'costo_total']),
                    ),
                  ),
                ],
              )
            else
              _ResponsiveTable(
                minWidth: 560,
                headers: const [
                  'Línea de producción',
                  'Solicitudes',
                  'Costo total',
                ],
                rows: [
                  ...porLinea.map(
                    (l) => [
                      _value(l, ['lineaNombre', 'linea_nombre']),
                      _value(l, ['totalSolicitudes', 'total_solicitudes']),
                      fmt.format(_numValue(l, ['costoTotal', 'costo_total'])),
                    ],
                  ),
                  [
                    'TOTAL',
                    '${_numValue(
                      totales,
                      ['totalSolicitudes', 'total_solicitudes'],
                    ).toInt()}',
                    fmt.format(
                      _numValue(totales, ['costoTotal', 'costo_total']),
                    ),
                  ],
                ],
                highlightLastRow: true,
              ),
          ],
        ),
      ),
    );
  }
}

class _ReporteTopMaterialesCard extends StatelessWidget {
  final List<dynamic> topMats;
  final NumberFormat fmt;

  const _ReporteTopMaterialesCard({
    required this.topMats,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Card(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 14 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Materiales más consumidos este mes',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            if (topMats.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Sin datos',
                    style: TextStyle(
                      color: TecneroTheme.textoSecundario,
                    ),
                  ),
                ),
              )
            else if (isMobile)
              Column(
                children: topMats.map((m) {
                  return _MaterialMobileItem(
                    nombre: _value(m, ['materialNombre', 'material_nombre']),
                    codigo: _value(m, ['materialCodigo', 'material_codigo']),
                    cantidad: '${_value(m, [
                          'cantidadTotal',
                          'cantidad_total'
                        ])} ${_value(m, ['unidadMedida', 'unidad_medida'])}',
                    costo: fmt.format(
                      _numValue(m, ['costoTotal', 'costo_total']),
                    ),
                  );
                }).toList(),
              )
            else
              _ResponsiveTable(
                minWidth: 600,
                headers: const [
                  'Material',
                  'Cantidad total',
                  'Costo total',
                ],
                rows: topMats.map((m) {
                  return [
                    '${_value(m, [
                          'materialCodigo',
                          'material_codigo'
                        ])} - ${_value(m, [
                          'materialNombre',
                          'material_nombre'
                        ])}',
                    '${_value(m, [
                          'cantidadTotal',
                          'cantidad_total'
                        ])} ${_value(m, ['unidadMedida', 'unidad_medida'])}',
                    fmt.format(
                      _numValue(m, ['costoTotal', 'costo_total']),
                    ),
                  ];
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReporteLineaMobileItem extends StatelessWidget {
  final String linea;
  final String solicitudes;
  final String costo;

  const _ReporteLineaMobileItem({
    required this.linea,
    required this.solicitudes,
    required this.costo,
  });

  @override
  Widget build(BuildContext context) {
    return _MobileInfoCard(
      title: linea,
      subtitle: '$solicitudes solicitudes',
      trailing: costo,
      trailingColor: TecneroTheme.naranja,
    );
  }
}

class _ReporteTotalMobileItem extends StatelessWidget {
  final String solicitudes;
  final String costo;

  const _ReporteTotalMobileItem({
    required this.solicitudes,
    required this.costo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TecneroTheme.azulOscuro,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TOTAL',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white70,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$solicitudes solicitudes',
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              costo,
              style: const TextStyle(
                fontSize: 20,
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MaterialMobileItem extends StatelessWidget {
  final String nombre;
  final String codigo;
  final String cantidad;
  final String costo;

  const _MaterialMobileItem({
    required this.nombre,
    required this.codigo,
    required this.cantidad,
    required this.costo,
  });

  @override
  Widget build(BuildContext context) {
    return _MobileInfoCard(
      title: nombre,
      subtitle: '$codigo · $cantidad',
      trailing: costo,
      trailingColor: TecneroTheme.naranja,
    );
  }
}

class _MobileInfoCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String trailing;
  final Color trailingColor;

  const _MobileInfoCard({
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.trailingColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: TecneroTheme.grisBorde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.isEmpty ? 'Sin nombre' : title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: TecneroTheme.textoPrimario,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 10,
              color: TecneroTheme.textoSecundario,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              trailing,
              style: TextStyle(
                fontSize: 16,
                color: trailingColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResponsiveTable extends StatelessWidget {
  final List<String> headers;
  final List<List<String>> rows;
  final double minWidth;
  final bool highlightLastRow;

  const _ResponsiveTable({
    required this.headers,
    required this.rows,
    required this.minWidth,
    this.highlightLastRow = false,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: minWidth),
        child: Table(
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          columnWidths: {
            for (int i = 0; i < headers.length; i++)
              i: i == 0 ? const FlexColumnWidth(2.4) : const FlexColumnWidth(1),
          },
          children: [
            TableRow(
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: TecneroTheme.grisBorde),
                ),
              ),
              children: headers.map((h) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 4,
                  ),
                  child: Text(
                    h,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: TecneroTheme.textoSecundario,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
            ),
            ...rows.asMap().entries.map((entry) {
              final index = entry.key;
              final row = entry.value;
              final isLast = index == rows.length - 1;
              final highlight = highlightLastRow && isLast;

              return TableRow(
                decoration: BoxDecoration(
                  color: highlight ? TecneroTheme.grisClaro : null,
                  border: const Border(
                    bottom: BorderSide(
                      color: TecneroTheme.grisBorde,
                      width: 0.5,
                    ),
                  ),
                ),
                children: row.map((cell) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 4,
                    ),
                    child: Text(
                      cell,
                      style: TextStyle(
                        fontSize: highlight ? 13 : 12,
                        fontWeight:
                            highlight ? FontWeight.w700 : FontWeight.w400,
                        color: highlight
                            ? TecneroTheme.azulOscuro
                            : TecneroTheme.textoPrimario,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
              );
            }),
          ],
        ),
      ),
    );
  }
}

String _value(dynamic source, List<String> keys) {
  if (source is Map) {
    for (final key in keys) {
      final value = source[key];
      if (value != null) return value.toString();
    }
  }
  return '';
}

double _numValue(dynamic source, List<String> keys) {
  if (source is Map) {
    for (final key in keys) {
      final value = source[key];
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0;
    }
  }
  return 0;
}
