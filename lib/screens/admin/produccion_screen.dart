// Pantalla para registrar produccion diaria por linea.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/models.dart' as models;
import '../../services/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/responsive.dart';

class ProduccionScreen extends ConsumerStatefulWidget {
  const ProduccionScreen({super.key});

  @override
  ConsumerState<ProduccionScreen> createState() => _ProduccionScreenState();
}

class _ProduccionScreenState extends ConsumerState<ProduccionScreen> {
  late DateTime _desde;
  late DateTime _hasta;
  Set<String> _lineasIds = {};
  late Future<List<Map<String, dynamic>>> _future;

  final _fmtDate = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _desde = DateTime(now.year, now.month, 1);
    _hasta = DateTime(now.year, now.month, now.day, 23, 59, 59);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(lineasProvider);
    });
    _load();
  }

  void _load() {
    _future = ref.read(apiServiceProvider).getProduccionDiaria(
          desde: _desde,
          hasta: _hasta,
          lineaIds: _lineasIds.isEmpty ? null : _lineasIds.toList(),
        );
  }

  Future<void> _recargarTodo() async {
    ref.invalidate(lineasProvider);
    ref.invalidate(produccionDiariaProvider);
    _load();
    setState(() {});
    await ref.read(lineasProvider.future);
  }

  Future<void> _seleccionarRango() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      initialDateRange: DateTimeRange(
        start: DateTime(_desde.year, _desde.month, _desde.day),
        end: DateTime(_hasta.year, _hasta.month, _hasta.day),
      ),
    );

    if (range == null) return;

    setState(() {
      _desde = DateTime(range.start.year, range.start.month, range.start.day);
      _hasta = DateTime(
        range.end.year,
        range.end.month,
        range.end.day,
        23,
        59,
        59,
      );
      _load();
    });
  }

  Future<void> _abrirRegistro() async {
    ref.invalidate(lineasProvider);
    final lineasActualizadas = await ref.read(lineasProvider.future);
    if (!mounted) return;

    final creado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ProduccionDialog(lineas: lineasActualizadas),
    );

    if (creado != true) return;

    ref.invalidate(lineasProvider);
    ref.invalidate(produccionDiariaProvider);
    setState(_load);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Cantidad producida guardada correctamente')),
    );
  }

  Future<void> _eliminar(String id) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar registro'),
        content: const Text(
          'Esta accion quita el registro de unidades producidas. No modifica los despachos ni el inventario.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    await ref.read(apiServiceProvider).eliminarProduccionDiaria(id);
    ref.invalidate(lineasProvider);
    ref.invalidate(produccionDiariaProvider);
    setState(_load);
  }

  Future<void> _editar(Map<String, dynamic> row) async {
    final editado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EditarProduccionDialog(registro: row),
    );

    if (editado != true) return;

    ref.invalidate(lineasProvider);
    ref.invalidate(produccionDiariaProvider);
    setState(_load);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Cantidad producida actualizada correctamente')),
    );
  }

  Future<void> _verDetalle(Map<String, dynamic> row) async {
    final fecha = '${row['fecha']}';
    final lineaId = '${row['lineaId'] ?? row['linea_id']}';

    if (lineaId.isEmpty) return;

    await showDialog(
      context: context,
      builder: (_) => _DetalleProduccionDialog(
        fecha: fecha,
        lineaId: lineaId,
        lineaNombre:
            '${row['lineaNombre'] ?? row['linea_nombre'] ?? 'Sin línea'}',
        cantidad: _num(row['cantidad']),
        unidad: '${row['unidad'] ?? 'unidades'}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lineasAsync = ref.watch(lineasProvider);
    final lineasDisponibles = lineasAsync.asData?.value ?? const [];
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
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const _HeaderTitle(),
                    FilledButton.icon(
                      onPressed:
                          lineasDisponibles.isNotEmpty ? _abrirRegistro : null,
                      icon: const Icon(Icons.add_chart_outlined, size: 18),
                      label: const Text('Registrar producción'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _ProduccionFiltros(
                  desde: _desde,
                  hasta: _hasta,
                  lineasIds: _lineasIds,
                  lineas: lineasDisponibles,
                  fmtDate: _fmtDate,
                  onRango: _seleccionarRango,
                  onLineasChanged: (value) {
                    setState(() {
                      _lineasIds = value;
                      _load();
                    });
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final rows = snapshot.data ?? const [];
                final totalUnidades = rows.fold<double>(
                  0.0,
                  (sum, row) => sum + _num(row['cantidad']),
                );
                final registrosReales =
                    rows.where((row) => !_esPendiente(row)).length;

                if (rows.isEmpty) {
                  return _EmptyProduccion(
                    onRegistrar:
                        lineasDisponibles.isNotEmpty ? _abrirRegistro : null,
                  );
                }

                return RefreshIndicator(
                  onRefresh: _recargarTodo,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      isMobile ? 12 : 24,
                      16,
                      isMobile ? 12 : 24,
                      28,
                    ),
                    children: [
                      _ResumenProduccion(
                        registros: registrosReales,
                        unidades: totalUnidades,
                      ),
                      const SizedBox(height: 14),
                      ..._agruparPorDia(rows).entries.map(
                            (entry) => _DiaProduccionSection(
                              fecha: entry.key,
                              rows: entry.value,
                              fmtDate: _fmtDate,
                              onDelete: null,
                              onEdit: _editar,
                              onVerDetalle: _verDetalle,
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

  Map<DateTime, List<Map<String, dynamic>>> _agruparPorDia(
    List<Map<String, dynamic>> rows,
  ) {
    final grupos = <DateTime, List<Map<String, dynamic>>>{};

    final ordenadas = rows.toList()
      ..sort((a, b) {
        final fechaA = DateTime.tryParse('${a['fecha']}') ?? DateTime(1900);
        final fechaB = DateTime.tryParse('${b['fecha']}') ?? DateTime(1900);
        return fechaB.compareTo(fechaA);
      });

    for (final row in ordenadas) {
      final fecha = DateTime.tryParse('${row['fecha']}') ?? DateTime.now();
      final dia = DateTime(fecha.year, fecha.month, fecha.day);
      grupos.putIfAbsent(dia, () => []).add(row);
    }

    return grupos;
  }

}

class _HeaderTitle extends StatelessWidget {
  const _HeaderTitle();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cantidades producidas',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        SizedBox(height: 2),
        Text(
          'Edita cuántas unidades se hicieron por día y línea para calcular el costo unitario',
          style: TextStyle(fontSize: 13, color: TecneroTheme.textoSecundario),
        ),
      ],
    );
  }
}

class _ProduccionFiltros extends StatelessWidget {
  final DateTime desde;
  final DateTime hasta;
  final Set<String> lineasIds;
  final List<models.LineaProduccion> lineas;
  final DateFormat fmtDate;
  final VoidCallback onRango;
  final ValueChanged<Set<String>> onLineasChanged;

  const _ProduccionFiltros({
    required this.desde,
    required this.hasta,
    required this.lineasIds,
    required this.lineas,
    required this.fmtDate,
    required this.onRango,
    required this.onLineasChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final lineasSeleccionadas = lineas
        .where((linea) => lineasIds.contains(linea.id))
        .map((linea) => linea.nombre)
        .toList();
    final textoLineas = _textoLineasSeleccionadas(
      lineasSeleccionadas: lineasSeleccionadas,
      totalLineas: lineas.length,
    );

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.start,
      children: [
        SizedBox(
          width: isMobile ? double.infinity : 420,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Líneas de producción',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: TecneroTheme.textoSecundario,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _abrirSelectorLineas(context),
                  icon: const Icon(Icons.view_list_outlined, size: 18),
                  label: Text(
                    textoLineas,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (lineasSeleccionadas.isNotEmpty && !isMobile) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: lineasSeleccionadas
                      .take(3)
                      .map(
                        (nombre) => Chip(
                          label: Text(
                            nombre,
                            overflow: TextOverflow.ellipsis,
                          ),
                          visualDensity: VisualDensity.compact,
                          side: const BorderSide(
                            color: TecneroTheme.grisBorde,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
        SizedBox(
          width: isMobile ? double.infinity : 250,
          child: OutlinedButton.icon(
            onPressed: onRango,
            icon: const Icon(Icons.date_range_outlined, size: 18),
            label: Text(
              '${fmtDate.format(desde)} - ${fmtDate.format(hasta)}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _abrirSelectorLineas(BuildContext context) async {
    if (lineas.isEmpty) return;

    final resultado = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final seleccion = Set<String>.from(lineasIds);

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final maxHeight = MediaQuery.of(sheetContext).size.height * 0.6;

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 8,
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Selecciona una o varias líneas',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'La selección filtra las cantidades producidas por línea.',
                      style: TextStyle(
                        fontSize: 12,
                        color: TecneroTheme.textoSecundario,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: maxHeight,
                      child: ListView(
                        children: [
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: seleccion.isEmpty,
                            title: const Text('Todas las líneas'),
                            subtitle:
                                const Text('Muestra el historial completo'),
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: (_) {
                              setSheetState(() {
                                seleccion.clear();
                              });
                            },
                          ),
                          const Divider(height: 1),
                          ...lineas.map(
                            (linea) => CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: seleccion.contains(linea.id),
                              title: Text(
                                linea.nombre,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                'Filtra cantidades producidas para esta línea',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              controlAffinity: ListTileControlAffinity.leading,
                              onChanged: (checked) {
                                setSheetState(() {
                                  if (checked == true) {
                                    seleccion.add(linea.id);
                                  } else {
                                    seleccion.remove(linea.id);
                                  }
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(sheetContext, null);
                          },
                          child: const Text('Cancelar'),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            setSheetState(() {
                              seleccion.clear();
                            });
                          },
                          child: const Text('Limpiar'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () {
                            Navigator.pop(sheetContext, seleccion);
                          },
                          child: const Text('Aplicar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (resultado == null) return;

    onLineasChanged(resultado.length == lineas.length ? {} : resultado);
  }
}

class _ResumenProduccion extends StatelessWidget {
  final int registros;
  final double unidades;

  const _ResumenProduccion({
    required this.registros,
    required this.unidades,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _MetricChip(
          icon: Icons.event_available_outlined,
          label: 'Registros',
          value: '$registros',
          color: TecneroTheme.azulOscuro,
        ),
        _MetricChip(
          icon: Icons.precision_manufacturing_outlined,
          label: 'Unidades reportadas',
          value: _formatCantidad(unidades),
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
      width: Responsive.isMobile(context) ? double.infinity : 230,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: color,
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

class _DiaProduccionSection extends StatelessWidget {
  final DateTime fecha;
  final List<Map<String, dynamic>> rows;
  final DateFormat fmtDate;
  final ValueChanged<String>? onDelete;
  final ValueChanged<Map<String, dynamic>> onEdit;
  final ValueChanged<Map<String, dynamic>> onVerDetalle;

  const _DiaProduccionSection({
    required this.fecha,
    required this.rows,
    required this.fmtDate,
    required this.onDelete,
    required this.onEdit,
    required this.onVerDetalle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _labelDia(fecha),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: TecneroTheme.azulOscuro,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: TecneroTheme.naranja.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${rows.length}',
                  style: const TextStyle(
                    color: TecneroTheme.naranja,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...rows.map((row) => _ProduccionCard(
                row: row,
                onDelete: onDelete,
                onEdit: () => onEdit(row),
                onVerDetalle: () => onVerDetalle(row),
              )),
        ],
      ),
    );
  }
}

class _ProduccionCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final ValueChanged<String>? onDelete;
  final VoidCallback onEdit;
  final VoidCallback onVerDetalle;

  const _ProduccionCard({
    required this.row,
    required this.onDelete,
    required this.onEdit,
    required this.onVerDetalle,
  });

  @override
  Widget build(BuildContext context) {
    final linea = '${row['lineaNombre'] ?? row['linea_nombre'] ?? 'Sin linea'}';
    final cantidad = _num(row['cantidad']);
    final unidad = '${row['unidad'] ?? 'unidades'}';
    final registradoPor =
        '${row['registradoPor'] ?? row['registrado_por'] ?? ''}';
    final observaciones = '${row['observaciones'] ?? ''}'.trim();
    final id = '${row['id'] ?? ''}';
    final pendiente = _esPendiente(row);
    final iconColor = pendiente ? const Color(0xFF6B7280) : TecneroTheme.naranja;
    final cardColor = pendiente ? const Color(0xFFF8FAFC) : Colors.white;
    final borderColor =
        pendiente ? const Color(0xFFD1D5DB) : TecneroTheme.grisBorde;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onVerDetalle,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.precision_manufacturing_outlined,
                  color: iconColor,
                  size: 20,
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
                          linea,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: pendiente
                                ? const Color(0xFF4B5563)
                                : TecneroTheme.azulOscuro,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_formatCantidad(cantidad)} $unidad',
                      style: TextStyle(
                        fontSize: 12,
                        color: pendiente
                            ? const Color(0xFF6B7280)
                            : TecneroTheme.textoPrimario,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (registradoPor.isNotEmpty ||
                        observaciones.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        [
                          if (registradoPor.isNotEmpty)
                            'Registrado por $registradoPor',
                          if (observaciones.isNotEmpty) observaciones,
                        ].join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: TecneroTheme.textoSecundario,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 20),
                tooltip: 'Editar',
              ),
              if (onDelete != null)
                IconButton(
                  onPressed: id.isEmpty ? null : () => onDelete!(id),
                  icon: const Icon(Icons.delete_outline, size: 20),
                  tooltip: 'Eliminar',
                ),
            ],
          ),
        ),
      ),
    );
  }
}

bool _esPendiente(Map<String, dynamic> row) {
  return row['__pendiente'] == true ||
      (_num(row['cantidad']) <= 0 && '${row['id'] ?? ''}'.trim().isEmpty);
}

class _ProduccionDialog extends ConsumerStatefulWidget {
  final List<models.LineaProduccion> lineas;

  const _ProduccionDialog({required this.lineas});

  @override
  ConsumerState<_ProduccionDialog> createState() => _ProduccionDialogState();
}

class _ProduccionDialogState extends ConsumerState<_ProduccionDialog> {
  late DateTime _fecha;
  models.LineaProduccion? _linea;
  late final TextEditingController _cantidadCtrl;
  late final TextEditingController _unidadCtrl;
  late final TextEditingController _obsCtrl;
  bool _guardando = false;
  String? _error;

  final _fmtDate = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _fecha = DateTime.now();
    _linea = widget.lineas.isNotEmpty ? widget.lineas.first : null;
    _cantidadCtrl = TextEditingController();
    _unidadCtrl = TextEditingController(text: _unidadSugerida(_linea?.nombre));
    _obsCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _cantidadCtrl.dispose();
    _unidadCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFecha() async {
    final value = await showDatePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      initialDate: _fecha,
    );
    if (value != null) setState(() => _fecha = value);
  }

  Future<void> _guardar() async {
    final cantidad =
        double.tryParse(_cantidadCtrl.text.replaceAll(',', '.')) ?? 0;
    final unidad = _unidadCtrl.text.trim();

    if (_linea == null) {
      setState(() => _error = 'Selecciona una linea de produccion');
      return;
    }

    if (cantidad <= 0) {
      setState(() => _error = 'Ingresa una cantidad mayor a 0');
      return;
    }

    if (unidad.isEmpty) {
      setState(() => _error = 'Ingresa la unidad producida');
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      await ref.read(apiServiceProvider).crearProduccionDiaria(
            fecha: _fecha,
            lineaId: _linea!.id,
            cantidad: cantidad,
            unidad: unidad,
            observaciones: _obsCtrl.text.trim().isEmpty ? null : _obsCtrl.text,
          );

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Dialog(
      insetPadding: EdgeInsets.all(isMobile ? 10 : 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16 : 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: TecneroTheme.naranja.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.add_chart_outlined,
                      color: TecneroTheme.naranja,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Registrar produccion',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Esto permite calcular costo por unidad en el dashboard',
                          style: TextStyle(
                            fontSize: 12,
                            color: TecneroTheme.textoSecundario,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _guardando ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: _guardando ? null : _seleccionarFecha,
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                label: Text(_fmtDate.format(_fecha)),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<models.LineaProduccion>(
                initialValue: _linea,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Linea de produccion',
                  prefixIcon: Icon(Icons.factory_outlined, size: 18),
                ),
                items: widget.lineas
                    .map(
                      (l) => DropdownMenuItem(
                        value: l,
                        child: Text(l.nombre, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: _guardando
                    ? null
                    : (value) {
                        setState(() {
                          _linea = value;
                          _unidadCtrl.text = _unidadSugerida(value?.nombre);
                        });
                      },
              ),
              const SizedBox(height: 12),
              _ResponsiveDialogFields(
                children: [
                  TextField(
                    controller: _cantidadCtrl,
                    enabled: !_guardando,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Cantidad producida',
                      prefixIcon: Icon(Icons.onetwothree, size: 20),
                    ),
                  ),
                  TextField(
                    controller: _unidadCtrl,
                    enabled: !_guardando,
                    decoration: const InputDecoration(
                      labelText: 'Unidad',
                      prefixIcon: Icon(Icons.precision_manufacturing_outlined,
                          size: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _obsCtrl,
                enabled: !_guardando,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Observaciones',
                  hintText: 'Turno, lote de produccion o nota adicional',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                _ErrorBox(message: _error!),
              ],
              const SizedBox(height: 18),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 10,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: _guardando ? null : () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton.icon(
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
                        : const Icon(Icons.save_outlined, size: 18),
                    label: Text(_guardando ? 'Guardando...' : 'Guardar'),
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

class _ResponsiveDialogFields extends StatelessWidget {
  final List<Widget> children;

  const _ResponsiveDialogFields({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        if (constraints.maxWidth < 520) {
          return Column(
            children: [
              for (final child in children) ...[
                child,
                if (child != children.last) const SizedBox(height: 12),
              ],
            ],
          );
        }

        return Row(
          children: [
            for (final child in children) ...[
              Expanded(child: child),
              if (child != children.last) const SizedBox(width: 12),
            ],
          ],
        );
      },
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;

  const _ErrorBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Color(0xFF991B1B),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyProduccion extends StatelessWidget {
  final VoidCallback? onRegistrar;

  const _EmptyProduccion({this.onRegistrar});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'No hay producción registrada en el periodo',
              style: TextStyle(color: TecneroTheme.textoSecundario),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'Si todavía no tienes la cantidad producida, puedes dejarla pendiente y volver luego para completar el registro.',
              style: TextStyle(
                color: TecneroTheme.textoSecundario,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRegistrar != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRegistrar,
                icon: const Icon(Icons.add_chart_outlined, size: 18),
                label: const Text('Registrar producción'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _unidadSugerida(String? linea) {
  final normalized = (linea ?? '').toLowerCase();
  if (normalized.contains('cilind') && normalized.contains('fabric')) {
    return 'cilindros fabricados';
  }
  if (normalized.contains('cilind')) return 'cilindros';
  if (normalized.contains('valv')) return 'valvulas reparadas';
  if (normalized.contains('repar')) return 'cilindros reparados';
  if (normalized.contains('asas')) return 'asas';
  if (normalized.contains('bases')) return 'bases';
  return 'unidades';
}

String _formatCantidad(double value) {
  if (value % 1 == 0) return value.toInt().toString();
  return value.toStringAsFixed(2);
}

String _textoLineasSeleccionadas({
  required List<String> lineasSeleccionadas,
  required int totalLineas,
}) {
  if (lineasSeleccionadas.isEmpty ||
      lineasSeleccionadas.length == totalLineas) {
    return 'Todas las líneas';
  }

  if (lineasSeleccionadas.length == 1) {
    return lineasSeleccionadas.first;
  }

  if (lineasSeleccionadas.length == 2) {
    return lineasSeleccionadas.join(' y ');
  }

  return '${lineasSeleccionadas.take(2).join(', ')} +${lineasSeleccionadas.length - 2}';
}

double _num(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse((value ?? '0').toString()) ?? 0;
}

bool _mismoDia(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String _labelDia(DateTime fecha) {
  final hoy = DateTime.now();
  final ayer = hoy.subtract(const Duration(days: 1));

  if (_mismoDia(fecha, hoy)) return 'Hoy';
  if (_mismoDia(fecha, ayer)) return 'Ayer';

  return DateFormat('dd/MM/yyyy').format(fecha);
}

class _EditarProduccionDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic> registro;

  const _EditarProduccionDialog({required this.registro});

  @override
  ConsumerState<_EditarProduccionDialog> createState() =>
      _EditarProduccionDialogState();
}

class _EditarProduccionDialogState
    extends ConsumerState<_EditarProduccionDialog> {
  late final TextEditingController _cantidadCtrl;
  late final TextEditingController _unidadCtrl;
  late final TextEditingController _obsCtrl;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cantidadCtrl = TextEditingController(
      text: _formatCantidad(_num(widget.registro['cantidad'])),
    );
    _unidadCtrl =
        TextEditingController(text: '${widget.registro['unidad'] ?? ''}');
    _obsCtrl = TextEditingController(
        text: '${widget.registro['observaciones'] ?? ''}');
  }

  @override
  void dispose() {
    _cantidadCtrl.dispose();
    _unidadCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final cantidad =
        double.tryParse(_cantidadCtrl.text.replaceAll(',', '.')) ?? 0;
    final unidad = _unidadCtrl.text.trim();

    if (cantidad <= 0) {
      setState(() => _error = 'Ingresa una cantidad mayor a 0');
      return;
    }

    if (unidad.isEmpty) {
      setState(() => _error = 'Ingresa la unidad producida');
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      final id = '${widget.registro['id'] ?? ''}'.trim();
      final fecha = DateTime.tryParse(
            '${widget.registro['fecha'] ?? DateTime.now().toIso8601String()}',
          ) ??
          DateTime.now();
      final lineaId =
          '${widget.registro['lineaId'] ?? widget.registro['linea_id'] ?? ''}'
              .trim();

      if (id.isEmpty) {
        if (lineaId.isEmpty) {
          throw Exception('No se pudo identificar la línea de producción');
        }

        await ref.read(apiServiceProvider).crearProduccionDiaria(
              fecha: fecha,
              lineaId: lineaId,
              cantidad: cantidad,
              unidad: unidad,
              observaciones:
                  _obsCtrl.text.trim().isEmpty ? null : _obsCtrl.text,
            );
      } else {
        await ref.read(apiServiceProvider).actualizarProduccionDiaria(
              id: id,
              cantidad: cantidad,
              unidad: unidad,
              observaciones:
                  _obsCtrl.text.trim().isEmpty ? null : _obsCtrl.text,
            );
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Dialog(
      insetPadding: EdgeInsets.all(isMobile ? 10 : 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16 : 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: TecneroTheme.naranja.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.edit_outlined,
                      color: TecneroTheme.naranja,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Editar produccion',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Ajusta las unidades realizadas para calcular el costo unitario',
                          style: TextStyle(
                            fontSize: 12,
                            color: TecneroTheme.textoSecundario,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _guardando ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _ResponsiveDialogFields(
                children: [
                  TextField(
                    controller: _cantidadCtrl,
                    enabled: !_guardando,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Cantidad producida',
                      prefixIcon: Icon(Icons.onetwothree, size: 20),
                    ),
                  ),
                  TextField(
                    controller: _unidadCtrl,
                    enabled: !_guardando,
                    decoration: const InputDecoration(
                      labelText: 'Unidad',
                      prefixIcon: Icon(Icons.precision_manufacturing_outlined,
                          size: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _obsCtrl,
                enabled: !_guardando,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Observaciones',
                  hintText: 'Turno, lote de produccion o nota adicional',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                _ErrorBox(message: _error!),
              ],
              const SizedBox(height: 18),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 10,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: _guardando ? null : () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton.icon(
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
                        : const Icon(Icons.save_outlined, size: 18),
                    label: Text(_guardando ? 'Guardando...' : 'Guardar'),
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

class _DetalleProduccionDialog extends ConsumerStatefulWidget {
  final String fecha;
  final String lineaId;
  final String lineaNombre;
  final double cantidad;
  final String unidad;

  const _DetalleProduccionDialog({
    required this.fecha,
    required this.lineaId,
    required this.lineaNombre,
    required this.cantidad,
    required this.unidad,
  });

  @override
  ConsumerState<_DetalleProduccionDialog> createState() =>
      _DetalleProduccionDialogState();
}

class _DetalleProduccionDialogState
    extends ConsumerState<_DetalleProduccionDialog> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(apiServiceProvider).getDetalleProduccion(
          fecha: widget.fecha,
          lineaId: widget.lineaId,
        );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Dialog(
      insetPadding: EdgeInsets.all(isMobile ? 10 : 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16 : 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: TecneroTheme.azulOscuro.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.receipt_long_outlined,
                      color: TecneroTheme.azulOscuro,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Detalle de producción',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          widget.lineaNombre,
                          style: const TextStyle(
                            fontSize: 12,
                            color: TecneroTheme.textoSecundario,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _ResumenProduccionInfo(
                fecha: widget.fecha,
                cantidad: widget.cantidad,
                unidad: widget.unidad,
              ),
              const SizedBox(height: 18),
              FutureBuilder<Map<String, dynamic>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Text('Error: ${snapshot.error}'),
                      ),
                    );
                  }

                  final data = snapshot.data ?? {};
                  final materiales = data['materiales'] as List? ?? [];
                  final produccion = data['produccion'] as Map? ?? {};

                  if (materiales.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Text(
                          'No hay materiales gastados en esta fecha',
                          style: TextStyle(
                            color: TecneroTheme.textoSecundario,
                          ),
                        ),
                      ),
                    );
                  }

                  final costoTotal = materiales.fold<double>(
                    0,
                    (sum, m) => sum + _num(m['costo_total']),
                  );

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Materiales gastados',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: TecneroTheme.azulOscuro,
                            ),
                          ),
                          Text(
                            '\$${_formatCantidad(costoTotal)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: TecneroTheme.naranja,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...materiales.map((m) => _MaterialCard(
                            material: m as Map<String, dynamic>,
                            cantidadProducida: widget.cantidad,
                          )),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              Center(
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cerrar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResumenProduccionInfo extends StatelessWidget {
  final String fecha;
  final double cantidad;
  final String unidad;

  const _ResumenProduccionInfo({
    required this.fecha,
    required this.cantidad,
    required this.unidad,
  });

  @override
  Widget build(BuildContext context) {
    final fechaFormateada = DateFormat('dd/MM/yyyy').format(
      DateTime.tryParse(fecha) ?? DateTime.now(),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TecneroTheme.azulOscuro.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: TecneroTheme.azulOscuro.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _InfoItem(
            label: 'Fecha',
            value: fechaFormateada,
          ),
          _InfoItem(
            label: 'Unidades',
            value: '${_formatCantidad(cantidad)} $unidad',
          ),
        ],
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final String label;
  final String value;

  const _InfoItem({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: TecneroTheme.textoSecundario,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: TecneroTheme.azulOscuro,
          ),
        ),
      ],
    );
  }
}

class _MaterialCard extends StatelessWidget {
  final Map<String, dynamic> material;
  final double cantidadProducida;

  const _MaterialCard({
    required this.material,
    required this.cantidadProducida,
  });

  @override
  Widget build(BuildContext context) {
    final nombre = '${material['material_nombre'] ?? 'Sin nombre'}';
    final codigo = '${material['material_codigo'] ?? ''}';
    final unidadMedida = '${material['unidad_medida'] ?? ''}';
    final cantidadTotal = _num(material['cantidad_total']);
    final costoTotal = _num(material['costo_total']);

    final costoUnitario =
        cantidadProducida > 0 ? costoTotal / cantidadProducida : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: TecneroTheme.azulOscuro,
                        ),
                      ),
                      if (codigo.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          codigo,
                          style: const TextStyle(
                            fontSize: 11,
                            color: TecneroTheme.textoSecundario,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  '\$${_formatCantidad(costoTotal)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: TecneroTheme.naranja,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_formatCantidad(cantidadTotal)} $unidadMedida',
                  style: const TextStyle(
                    fontSize: 12,
                    color: TecneroTheme.textoPrimario,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: TecneroTheme.naranja.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '\$${_formatCantidad(costoUnitario)} / unidad',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: TecneroTheme.naranja,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
