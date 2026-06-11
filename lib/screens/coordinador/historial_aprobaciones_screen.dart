// Historial de aprobaciones y consultas asociadas al coordinador.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';
import '../../services/providers.dart';
import '../../models/models.dart';
import '../../widgets/responsive.dart';

class HistorialAprobacionesScreen extends ConsumerStatefulWidget {
  const HistorialAprobacionesScreen({super.key});

  @override
  ConsumerState<HistorialAprobacionesScreen> createState() =>
      _HistorialAprobacionesScreenState();
}

class _HistorialAprobacionesScreenState
    extends ConsumerState<HistorialAprobacionesScreen> {
  String _estadoFiltro = 'todos';
  String _busqueda = '';

  final _fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  final _fmtDate = DateFormat('dd/MM/yyyy HH:mm');

  @override
  Widget build(BuildContext context) {
    final solicitudesAsync = ref.watch(todasSolicitudesProvider);
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
                  'Historial de decisiones',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: TecneroTheme.textoPrimario,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Solicitudes aprobadas, rechazadas y entregadas',
                  style: TextStyle(
                    fontSize: 13,
                    color: TecneroTheme.textoSecundario,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _FilterChip(
                      label: 'Todas',
                      selected: _estadoFiltro == 'todos',
                      onTap: () => setState(() => _estadoFiltro = 'todos'),
                    ),
                    _FilterChip(
                      label: 'Aprobadas',
                      selected: _estadoFiltro == 'aprobada',
                      onTap: () => setState(() => _estadoFiltro = 'aprobada'),
                    ),
                    _FilterChip(
                      label: 'Entregadas',
                      selected: _estadoFiltro == 'entregada',
                      onTap: () => setState(() => _estadoFiltro = 'entregada'),
                    ),
                    _FilterChip(
                      label: 'Rechazadas',
                      selected: _estadoFiltro == 'rechazada',
                      onTap: () => setState(() => _estadoFiltro = 'rechazada'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              isMobile ? 12 : 20,
              14,
              isMobile ? 12 : 20,
              8,
            ),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar por número, operario o línea...',
                prefixIcon: Icon(Icons.search, size: 18),
              ),
              onChanged: (value) => setState(() => _busqueda = value),
            ),
          ),
          Expanded(
            child: solicitudesAsync.when(
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
                final query = _busqueda.trim().toLowerCase();

                final historial = lista.where((s) {
                  final esHistorial = s.estado == 'aprobada' ||
                      s.estado == 'entregada' ||
                      s.estado == 'rechazada';

                  final matchEstado =
                      _estadoFiltro == 'todos' || s.estado == _estadoFiltro;

                  final matchBusqueda = query.isEmpty ||
                      s.numero.toLowerCase().contains(query) ||
                      s.solicitanteNombre.toLowerCase().contains(query) ||
                      s.lineaNombre.toLowerCase().contains(query);

                  return esHistorial && matchEstado && matchBusqueda;
                }).toList()
                  ..sort((a, b) {
                    final fa = a.fechaAprobacion ?? a.fecha;
                    final fb = b.fechaAprobacion ?? b.fecha;
                    return fb.compareTo(fa);
                  });

                if (historial.isEmpty) {
                  return const _EmptyHistorial();
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(todasSolicitudesProvider);
                    await ref.read(todasSolicitudesProvider.future);
                  },
                  child: ListView.builder(
                    padding: EdgeInsets.fromLTRB(
                      isMobile ? 12 : 20,
                      8,
                      isMobile ? 12 : 20,
                      20,
                    ),
                    itemCount: historial.length,
                    itemBuilder: (context, index) {
                      return _HistorialDecisionCard(
                        solicitud: historial[index],
                        fmt: _fmt,
                        fmtDate: _fmtDate,
                      );
                    },
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

class _HistorialDecisionCard extends StatefulWidget {
  final Solicitud solicitud;
  final NumberFormat fmt;
  final DateFormat fmtDate;

  const _HistorialDecisionCard({
    required this.solicitud,
    required this.fmt,
    required this.fmtDate,
  });

  @override
  State<_HistorialDecisionCard> createState() => _HistorialDecisionCardState();
}

class _HistorialDecisionCardState extends State<_HistorialDecisionCard> {
  bool _expandido = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.solicitud;
    final isMobile = Responsive.isMobile(context);

    final fechaDecision = s.fechaAprobacion ?? s.fecha;
    final decisionLabel = s.estado == 'rechazada'
        ? 'Rechazada'
        : s.estado == 'entregada'
            ? 'Aprobada y entregada'
            : 'Aprobada';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expandido = !_expandido),
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 12 : 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DecisionIcon(estado: s.estado),
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
                          '$decisionLabel: ${widget.fmtDate.format(fechaDecision)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: TecneroTheme.textoSecundario,
                          ),
                        ),
                        if (s.aprobadoPor != null &&
                            s.aprobadoPor!.trim().isNotEmpty)
                          Text(
                            'Por: ${s.aprobadoPor}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: TecneroTheme.textoSecundario,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        widget.fmt.format(s.costoTotal).trim(),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: s.estado == 'rechazada'
                              ? const Color(0xFFB91C1C)
                              : TecneroTheme.naranja,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${s.detalles.length} materiales',
                        style: const TextStyle(
                          fontSize: 10,
                          color: TecneroTheme.textoSecundario,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Icon(
                        _expandido ? Icons.expand_less : Icons.expand_more,
                        color: TecneroTheme.textoSecundario,
                        size: 20,
                      ),
                    ],
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
                  _InfoBlock(
                    label: 'Fecha de solicitud',
                    value: widget.fmtDate.format(s.fecha),
                    icon: Icons.event_note_outlined,
                  ),
                  const SizedBox(height: 8),
                  _InfoBlock(
                    label: s.estado == 'rechazada'
                        ? 'Fecha de rechazo'
                        : 'Fecha de aprobación',
                    value: s.fechaAprobacion == null
                        ? 'No registrada'
                        : widget.fmtDate.format(s.fechaAprobacion!),
                    icon: s.estado == 'rechazada'
                        ? Icons.cancel_outlined
                        : Icons.verified_outlined,
                  ),
                  if (s.fechaEntrega != null) ...[
                    const SizedBox(height: 8),
                    _InfoBlock(
                      label: 'Fecha de entrega',
                      value: widget.fmtDate.format(s.fechaEntrega!),
                      icon: Icons.local_shipping_outlined,
                    ),
                  ],
                  if (s.observaciones != null &&
                      s.observaciones!.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _InfoBlock(
                      label: s.estado == 'rechazada'
                          ? 'Motivo / observación'
                          : 'Observación',
                      value: s.observaciones!,
                      icon: Icons.notes_outlined,
                    ),
                  ],
                  const SizedBox(height: 14),
                  const Text(
                    'Materiales',
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
                      (d) => _MaterialHistorialItem(
                        detalle: d,
                        fmt: widget.fmt,
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

class _DecisionIcon extends StatelessWidget {
  final String estado;

  const _DecisionIcon({
    required this.estado,
  });

  @override
  Widget build(BuildContext context) {
    final bool rechazado = estado == 'rechazada';
    final bool entregado = estado == 'entregada';

    final bg = rechazado
        ? const Color(0xFFFEE2E2)
        : entregado
            ? const Color(0xFFD1FAE5)
            : const Color(0xFFDBEAFE);

    final fg = rechazado
        ? const Color(0xFFB91C1C)
        : entregado
            ? const Color(0xFF047857)
            : const Color(0xFF1D4ED8);

    final icon = rechazado
        ? Icons.cancel_outlined
        : entregado
            ? Icons.local_shipping_outlined
            : Icons.check_circle_outline;

    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 18, color: fg),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoBlock({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: TecneroTheme.grisBorde),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: TecneroTheme.textoSecundario),
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
                    fontWeight: FontWeight.w500,
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

class _MaterialHistorialItem extends StatelessWidget {
  final DetalleSolicitud detalle;
  final NumberFormat fmt;

  const _MaterialHistorialItem({
    required this.detalle,
    required this.fmt,
  });

  String _cantidad(double value) {
    if (value % 1 == 0) return value.toInt().toString();
    return value.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final subtotal = fmt.format(detalle.subtotal).trim();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 7),
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
                  detalle.materialNombre,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: TecneroTheme.textoPrimario,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
                const SizedBox(height: 2),
                Text(
                  '${detalle.materialCodigo} · ${_cantidad(detalle.cantidad)} ${detalle.unidadMedida}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: TecneroTheme.textoSecundario,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            subtotal,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: TecneroTheme.naranja,
            ),
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

class _EmptyHistorial extends StatelessWidget {
  const _EmptyHistorial();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'No hay historial de aprobaciones todavía',
        style: TextStyle(
          color: TecneroTheme.textoSecundario,
        ),
      ),
    );
  }
}
