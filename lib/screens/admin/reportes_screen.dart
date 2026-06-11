// Pantalla de reportes resumidos de costos y consumo.
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/models.dart' as models;
import '../../services/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/responsive.dart';

enum _ReportePeriodo { hoy, semana, mes, rango }

class ReportesScreen extends ConsumerStatefulWidget {
  const ReportesScreen({super.key});

  @override
  ConsumerState<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends ConsumerState<ReportesScreen> {
  late DateTime _desde;
  late DateTime _hasta;
  late Future<Map<String, dynamic>> _future;

  _ReportePeriodo _periodo = _ReportePeriodo.mes;
  String? _lineaId;

  final _fmtMoney = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  final _fmtShort = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
  final _fmtDate = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _desde = DateTime(now.year, now.month, 1);
    _hasta = DateTime(now.year, now.month, now.day, 23, 59, 59);
    _load();
  }

  void _load() {
    _future = ref.read(apiServiceProvider).getDashboardData(
          desde: _desde,
          hasta: _hasta,
          lineaId: _lineaId,
        );
  }

  void _setRange(DateTime desde, DateTime hasta) {
    setState(() {
      _desde = DateTime(desde.year, desde.month, desde.day);
      _hasta = DateTime(hasta.year, hasta.month, hasta.day, 23, 59, 59);
      _load();
    });
  }

  void _setPeriodo(_ReportePeriodo periodo) {
    final now = DateTime.now();
    setState(() {
      _periodo = periodo;
      switch (periodo) {
        case _ReportePeriodo.hoy:
          _desde = DateTime(now.year, now.month, now.day);
          _hasta = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case _ReportePeriodo.semana:
          final inicio = now.subtract(Duration(days: now.weekday - 1));
          _desde = DateTime(inicio.year, inicio.month, inicio.day);
          _hasta = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case _ReportePeriodo.mes:
          _desde = DateTime(now.year, now.month, 1);
          _hasta = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case _ReportePeriodo.rango:
          break;
      }
      _load();
    });
  }

  Future<void> _seleccionarRango() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime(2030, 12, 31),
      initialDateRange: DateTimeRange(
        start: DateTime(_desde.year, _desde.month, _desde.day),
        end: DateTime(_hasta.year, _hasta.month, _hasta.day),
      ),
    );

    if (picked == null) return;
    setState(() => _periodo = _ReportePeriodo.rango);
    _setRange(picked.start, picked.end);
  }

  Future<void> _exportarPdf() async {
    final data = await _future;
    final pdf = pw.Document();

    final totales = _map(data['totales']);
    final porLinea = _list(data['por_linea']).map(_map).toList();
    final topMateriales = _list(data['top_materiales']).map(_map).toList();
    final gastoPorDia = _list(data['gasto_por_dia']).map(_map).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Text(
            'Reporte de costos TECNERO',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
              'Periodo: ${_fmtDate.format(_desde)} - ${_fmtDate.format(_hasta)}'),
          pw.SizedBox(height: 18),
          pw.Row(
            children: [
              _pdfMetric('Gasto total',
                  _fmtMoney.format(_num(totales, 'costo_total'))),
              _pdfMetric(
                  'Entregas', _num(totales, 'entregadas').toInt().toString()),
              _pdfMetric('Promedio',
                  _fmtMoney.format(_num(totales, 'promedio_solicitud'))),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Text('Costo por línea',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.TableHelper.fromTextArray(
            headers: const ['Línea', 'Entregas', 'Costo'],
            data: porLinea
                .map(
                  (l) => [
                    _str(l, 'linea_nombre', alt: 'lineaNombre'),
                    _num(l, 'total_solicitudes').toInt().toString(),
                    _fmtMoney.format(_num(l, 'costo_total')),
                  ],
                )
                .toList(),
          ),
          pw.SizedBox(height: 18),
          pw.Text('Materiales críticos',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.TableHelper.fromTextArray(
            headers: const ['Material', 'Cantidad', 'Costo'],
            data: topMateriales
                .map(
                  (m) => [
                    _str(m, 'material_nombre', alt: 'nombre'),
                    '${_formatCantidad(_num(m, 'cantidad_total'))} ${_str(m, 'unidad_medida', alt: 'unidadMedida')}',
                    _fmtMoney.format(_num(m, 'costo_total')),
                  ],
                )
                .toList(),
          ),
          pw.SizedBox(height: 18),
          pw.Text('Gasto diario',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.TableHelper.fromTextArray(
            headers: const ['Fecha', 'Costo'],
            data: gastoPorDia
                .map(
                  (d) => [
                    _str(d, 'dia'),
                    _fmtMoney.format(_num(d, 'costo_total')),
                  ],
                )
                .toList(),
          ),
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename:
          'reporte-costos-${_fmtDate.format(_desde).replaceAll('/', '-')}-${_fmtDate.format(_hasta).replaceAll('/', '-')}.pdf',
    );
  }

  pw.Widget _pdfMetric(String label, String value) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        margin: const pw.EdgeInsets.only(right: 8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
            pw.SizedBox(height: 4),
            pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lineasAsync = ref.watch(lineasProvider);

    return Scaffold(
      backgroundColor: TecneroTheme.grisClaro,
      body: Column(
        children: [
          _ReportesHeader(
            desde: _desde,
            hasta: _hasta,
            fmtDate: _fmtDate,
            onPdf: _exportarPdf,
            onRefresh: () => setState(_load),
          ),
          _ReportesFiltros(
            periodo: _periodo,
            lineaId: _lineaId,
            lineas: lineasAsync.asData?.value ?? const [],
            onPeriodo: (periodo) {
              if (periodo == _ReportePeriodo.rango) {
                _seleccionarRango();
              } else {
                _setPeriodo(periodo);
              }
            },
            onLinea: (value) {
              setState(() {
                _lineaId = value;
                _load();
              });
            },
          ),
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final data = snapshot.data ?? <String, dynamic>{};
                final totales = _map(data['totales']);
                final porLinea = _list(data['por_linea']);
                final gastoPorDia = _list(data['gasto_por_dia']);
                final topMateriales = _list(data['top_materiales']);
                final topCantidad = _list(data['top_materiales_cantidad']);

                return SingleChildScrollView(
                  padding: Responsive.pagePadding(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ReportMetrics(
                        fmt: _fmtMoney,
                        total: _num(totales, 'costo_total'),
                        entregas: _num(totales, 'entregadas'),
                        promedio: _num(totales, 'promedio_solicitud'),
                        materiales: _num(totales, 'materiales_consumidos'),
                      ),
                      const SizedBox(height: 16),
                      _ReportSection(
                        title: 'Evolución diaria del gasto',
                        subtitle:
                            'Costo real de materiales despachados por fecha.',
                        child: gastoPorDia.isEmpty
                            ? const _ReportEmpty()
                            : _DailyLineChart(
                                data: gastoPorDia, fmt: _fmtShort),
                      ),
                      if (_periodo == _ReportePeriodo.mes &&
                          gastoPorDia.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _ReportSection(
                          title: 'Resumen semanal del mes',
                          subtitle:
                              'Total y promedio diario para comparar semanas del periodo.',
                          child: _WeeklySummaryTable(
                            data: gastoPorDia,
                            fmt: _fmtMoney,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      _ReportTwoColumns(
                        left: _ReportSection(
                          title: 'Distribución por línea',
                          subtitle:
                              'Participación de cada línea de producción en el costo total.',
                          child: porLinea.isEmpty
                              ? const _ReportEmpty()
                              : _LineBarChart(data: porLinea, fmt: _fmtShort),
                        ),
                        right: _ReportSection(
                          title: 'Materiales críticos por costo',
                          subtitle: 'Qué materiales concentran más gasto.',
                          child: topMateriales.isEmpty
                              ? const _ReportEmpty()
                              : _MaterialsPieChart(
                                  data: topMateriales, fmt: _fmtMoney),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _ReportTwoColumns(
                        left: _ReportSection(
                          title: 'Ranking de líneas',
                          subtitle: 'Costo y entregas cerradas.',
                          child: _ReportTable(
                            rows: porLinea.map(_map).toList(),
                            columns: [
                              _ReportColumn(
                                  'Línea',
                                  (m) => _str(m, 'linea_nombre',
                                      alt: 'lineaNombre')),
                              _ReportColumn(
                                  'Entregas',
                                  (m) => _num(m, 'total_solicitudes')
                                      .toInt()
                                      .toString()),
                              _ReportColumn(
                                  'Costo',
                                  (m) =>
                                      _fmtMoney.format(_num(m, 'costo_total'))),
                            ],
                          ),
                        ),
                        right: _ReportSection(
                          title: 'Materiales más usados',
                          subtitle: 'Consumo físico por cantidad.',
                          child: _ReportTable(
                            rows: topCantidad.map(_map).toList(),
                            columns: [
                              _ReportColumn(
                                  'Material',
                                  (m) => _str(m, 'material_nombre',
                                      alt: 'nombre')),
                              _ReportColumn(
                                  'Cantidad',
                                  (m) =>
                                      '${_formatCantidad(_num(m, 'cantidad_total'))} ${_str(m, 'unidad_medida', alt: 'unidadMedida')}'),
                              _ReportColumn(
                                  'Costo',
                                  (m) =>
                                      _fmtMoney.format(_num(m, 'costo_total'))),
                            ],
                          ),
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
}

class _ReportesHeader extends StatelessWidget {
  final DateTime desde;
  final DateTime hasta;
  final DateFormat fmtDate;
  final VoidCallback onPdf;
  final VoidCallback onRefresh;

  const _ReportesHeader({
    required this.desde,
    required this.hasta,
    required this.fmtDate,
    required this.onPdf,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final mobile = Responsive.isMobile(context);

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: Responsive.headerPadding(context),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: mobile ? MediaQuery.sizeOf(context).width - 32 : 430,
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reportes de costos',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                SizedBox(height: 2),
                Text(
                  'Análisis estadístico de consumo, líneas y materiales críticos',
                  style: TextStyle(
                      fontSize: 13, color: TecneroTheme.textoSecundario),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: mobile ? MediaQuery.sizeOf(context).width - 118 : null,
                child: Chip(
                  label: Text(
                    '${fmtDate.format(desde)} - ${fmtDate.format(hasta)}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              IconButton(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Actualizar'),
              ElevatedButton.icon(
                onPressed: onPdf,
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: const Text('Descargar PDF'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReportesFiltros extends StatelessWidget {
  final _ReportePeriodo periodo;
  final String? lineaId;
  final List<models.LineaProduccion> lineas;
  final ValueChanged<_ReportePeriodo> onPeriodo;
  final ValueChanged<String?> onLinea;

  const _ReportesFiltros({
    required this.periodo,
    required this.lineaId,
    required this.lineas,
    required this.onPeriodo,
    required this.onLinea,
  });

  @override
  Widget build(BuildContext context) {
    final mobile = Responsive.isMobile(context);

    Widget filtros(bool compact) {
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          SizedBox(
            width: compact ? double.infinity : 250,
            child: DropdownButtonFormField<_ReportePeriodo>(
              initialValue: periodo,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Periodo',
                prefixIcon: Icon(Icons.calendar_month_outlined, size: 18),
              ),
              selectedItemBuilder: (context) {
                return const [
                  _DropdownSelectedText('Hoy'),
                  _DropdownSelectedText('Esta semana'),
                  _DropdownSelectedText('Este mes'),
                  _DropdownSelectedText('Rango personalizado'),
                ];
              },
              items: const [
                DropdownMenuItem(
                    value: _ReportePeriodo.hoy, child: Text('Hoy')),
                DropdownMenuItem(
                    value: _ReportePeriodo.semana, child: Text('Esta semana')),
                DropdownMenuItem(
                    value: _ReportePeriodo.mes, child: Text('Este mes')),
                DropdownMenuItem(
                    value: _ReportePeriodo.rango,
                    child: Text('Rango personalizado')),
              ],
              onChanged: (value) {
                if (value != null) onPeriodo(value);
              },
            ),
          ),
          SizedBox(
            width: compact ? double.infinity : 320,
            child: DropdownButtonFormField<String>(
              initialValue: lineaId ?? 'todos',
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Línea de producción',
                prefixIcon: Icon(Icons.factory_outlined, size: 18),
              ),
              selectedItemBuilder: (context) {
                return [
                  const _DropdownSelectedText('Todas las líneas'),
                  ...lineas.map((l) => _DropdownSelectedText(l.nombre)),
                ];
              },
              items: [
                const DropdownMenuItem(
                    value: 'todos', child: Text('Todas las líneas')),
                ...lineas.map((l) =>
                    DropdownMenuItem(value: l.id, child: Text(l.nombre))),
              ],
              onChanged: (value) => onLinea(value == 'todos' ? null : value),
            ),
          ),
        ],
      );
    }

    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(mobile ? 16 : 28, 0, mobile ? 16 : 28, 16),
      child: mobile
          ? SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    builder: (_) => Padding(
                      padding: const EdgeInsets.all(16),
                      child: SingleChildScrollView(child: filtros(true)),
                    ),
                  );
                },
                icon: const Icon(Icons.tune_outlined, size: 18),
                label: const Text('Filtros de reportes'),
              ),
            )
          : filtros(false),
    );
  }
}

class _ReportMetrics extends StatelessWidget {
  final NumberFormat fmt;
  final double total;
  final double entregas;
  final double promedio;
  final double materiales;

  const _ReportMetrics({
    required this.fmt,
    required this.total,
    required this.entregas,
    required this.promedio,
    required this.materiales,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _MetricCard(
            label: 'Gasto total',
            value: fmt.format(total),
            icon: Icons.account_balance_wallet_outlined,
            color: TecneroTheme.naranja),
        _MetricCard(
            label: 'Entregas cerradas',
            value: entregas.toInt().toString(),
            icon: Icons.local_shipping_outlined,
            color: const Color(0xFF059669)),
        _MetricCard(
            label: 'Promedio por entrega',
            value: fmt.format(promedio),
            icon: Icons.analytics_outlined,
            color: const Color(0xFF2563EB)),
        _MetricCard(
            label: 'Materiales consumidos',
            value: materiales.toInt().toString(),
            icon: Icons.inventory_2_outlined,
            color: const Color(0xFF7C3AED)),
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
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: Responsive.isMobile(context) ? double.infinity : 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: TecneroTheme.grisBorde),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: color)),
                Text(label,
                    style: const TextStyle(
                        fontSize: 12, color: TecneroTheme.textoSecundario)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklySummaryTable extends StatelessWidget {
  final List<dynamic> data;
  final NumberFormat fmt;

  const _WeeklySummaryTable({
    required this.data,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final semanas = _buildWeeklySummary(data);

    return _ReportTable(
      rows: semanas,
      columns: [
        _ReportColumn('Semana', (m) => _str(m, 'semana')),
        _ReportColumn('Días', (m) => _num(m, 'dias').toInt().toString()),
        _ReportColumn('Total', (m) => fmt.format(_num(m, 'total'))),
        _ReportColumn('Promedio', (m) => fmt.format(_num(m, 'promedio'))),
      ],
    );
  }
}

class _ReportSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _ReportSection({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: TecneroTheme.grisBorde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(subtitle,
              style: const TextStyle(
                  fontSize: 12, color: TecneroTheme.textoSecundario)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _ReportTwoColumns extends StatelessWidget {
  final Widget left;
  final Widget right;

  const _ReportTwoColumns({required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    if (Responsive.isMobile(context)) {
      return Column(children: [left, const SizedBox(height: 16), right]);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 16),
        Expanded(child: right),
      ],
    );
  }
}

class _DailyLineChart extends StatelessWidget {
  final List<dynamic> data;
  final NumberFormat fmt;

  const _DailyLineChart({required this.data, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final rows = data.map(_map).toList();
    final maxY = rows.fold<double>(0, (max, r) {
      final value = _num(r, 'costo_total');
      return value > max ? value : max;
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        final step = _labelStep(rows.length, constraints.maxWidth);

        return SizedBox(
          height: Responsive.isMobile(context) ? 260 : 320,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: (rows.length - 1).clamp(0, rows.length).toDouble(),
              minY: 0,
              maxY: maxY <= 0 ? 10 : maxY * 1.2,
              gridData: const FlGridData(show: true),
              borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: TecneroTheme.grisBorde)),
              titlesData: FlTitlesData(
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 46,
                        getTitlesWidget: (v, _) => Text(fmt.format(v),
                            style: const TextStyle(fontSize: 10)))),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    reservedSize: 36,
                    getTitlesWidget: (v, _) {
                      if (v != v.roundToDouble()) {
                        return const SizedBox.shrink();
                      }
                      final index = v.toInt();
                      if (index < 0 || index >= rows.length) {
                        return const SizedBox.shrink();
                      }
                      final show = index == 0 ||
                          index == rows.length - 1 ||
                          index % step == 0;
                      if (!show) return const SizedBox.shrink();

                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _shortDate(_str(rows[index], 'dia')),
                          style: const TextStyle(fontSize: 10),
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  isCurved: rows.length > 2,
                  color: TecneroTheme.naranja,
                  barWidth: 3,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(
                      show: true,
                      color: TecneroTheme.naranja.withValues(alpha: 0.12)),
                  spots: rows
                      .asMap()
                      .entries
                      .map((e) => FlSpot(
                          e.key.toDouble(), _num(e.value, 'costo_total')))
                      .toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LineBarChart extends StatelessWidget {
  final List<dynamic> data;
  final NumberFormat fmt;

  const _LineBarChart({required this.data, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final rows = data.map(_map).toList()
      ..sort(
          (a, b) => _num(b, 'costo_total').compareTo(_num(a, 'costo_total')));
    final maxY = rows.fold<double>(0, (max, r) {
      final value = _num(r, 'costo_total');
      return value > max ? value : max;
    });

    return Column(
      children: [
        SizedBox(
          height: Responsive.isMobile(context) ? 260 : 320,
          child: BarChart(
            BarChartData(
              maxY: maxY <= 0 ? 10 : maxY * 1.2,
              gridData: const FlGridData(show: true),
              borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: TecneroTheme.grisBorde)),
              titlesData: FlTitlesData(
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 46,
                        getTitlesWidget: (v, _) => Text(fmt.format(v),
                            style: const TextStyle(fontSize: 10)))),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    reservedSize: 28,
                    getTitlesWidget: (v, _) {
                      if (v != v.roundToDouble()) {
                        return const SizedBox.shrink();
                      }
                      final index = v.toInt();
                      if (index < 0 || index >= rows.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: _chartColor(index),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barGroups: rows.asMap().entries.map((e) {
                return BarChartGroupData(
                  x: e.key,
                  barRods: [
                    BarChartRodData(
                      toY: _num(e.value, 'costo_total'),
                      color: _chartColor(e.key),
                      width: Responsive.isMobile(context) ? 20 : 30,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(6)),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _ChartLegend(
          rows: rows,
          labelBuilder: (row) => _str(row, 'linea_nombre', alt: 'lineaNombre'),
          valueBuilder: (row) => fmt.format(_num(row, 'costo_total')),
        ),
      ],
    );
  }
}

class _MaterialsPieChart extends StatelessWidget {
  final List<dynamic> data;
  final NumberFormat fmt;

  const _MaterialsPieChart({required this.data, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final rows = data.take(6).map(_map).toList();
    final total =
        rows.fold<double>(0, (sum, r) => sum + _num(r, 'costo_total'));

    return Column(
      children: [
        SizedBox(
          height: 240,
          child: PieChart(
            PieChartData(
              centerSpaceRadius: 42,
              sectionsSpace: 2,
              sections: rows.asMap().entries.map((e) {
                final costo = _num(e.value, 'costo_total');
                final pct = total > 0 ? costo / total * 100 : 0;
                return PieChartSectionData(
                  value: costo,
                  color: _chartColor(e.key),
                  title: '${pct.toStringAsFixed(0)}%',
                  radius: 70,
                  titleStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 11),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _ChartLegend(
          rows: rows,
          labelBuilder: (row) => _str(row, 'material_nombre', alt: 'nombre'),
          valueBuilder: (row) => fmt.format(_num(row, 'costo_total')),
        ),
      ],
    );
  }
}

class _ChartLegend extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final String Function(Map<String, dynamic>) labelBuilder;
  final String Function(Map<String, dynamic>) valueBuilder;

  const _ChartLegend({
    required this.rows,
    required this.labelBuilder,
    required this.valueBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: rows.asMap().entries.map((entry) {
        final index = entry.key;
        final row = entry.value;
        final color = _chartColor(index);

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 7),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.22)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  labelBuilder(row),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                valueBuilder(row),
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _ReportTable extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final List<_ReportColumn> columns;

  const _ReportTable({required this.rows, required this.columns});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const _ReportEmpty();
    if (Responsive.isMobile(context)) {
      return Column(
        children: rows.take(10).map((row) {
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: TecneroTheme.grisBorde),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: columns.map((column) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 76,
                        child: Text(
                          column.title,
                          style: const TextStyle(
                            fontSize: 11,
                            color: TecneroTheme.textoSecundario,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          column.value(row),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          );
        }).toList(),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 36,
        dataRowMinHeight: 42,
        dataRowMaxHeight: 48,
        columns: columns.map((c) => DataColumn(label: Text(c.title))).toList(),
        rows: rows.take(10).map((row) {
          return DataRow(
            cells: columns
                .map((c) => DataCell(
                      SizedBox(
                        width: c.title == 'Material' || c.title == 'Línea'
                            ? 240
                            : 120,
                        child: Text(
                          c.value(row),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ))
                .toList(),
          );
        }).toList(),
      ),
    );
  }
}

class _ReportColumn {
  final String title;
  final String Function(Map<String, dynamic>) value;

  const _ReportColumn(this.title, this.value);
}

class _ReportEmpty extends StatelessWidget {
  const _ReportEmpty();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 180,
      child: Center(
        child: Text('Sin datos en este periodo',
            style: TextStyle(color: TecneroTheme.textoSecundario)),
      ),
    );
  }
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return <String, dynamic>{};
}

List<dynamic> _list(dynamic value) => value is List ? value : const [];

String _str(Map<String, dynamic> map, String key, {String? alt}) {
  return (map[key] ?? (alt == null ? null : map[alt]) ?? '').toString();
}

double _num(Map<String, dynamic> map, String key) {
  return double.tryParse((map[key] ?? 0).toString()) ?? 0;
}

List<Map<String, dynamic>> _buildWeeklySummary(List<dynamic> data) {
  final rows = data.map(_map).toList()
    ..sort((a, b) =>
        _dateFromDay(_str(a, 'dia')).compareTo(_dateFromDay(_str(b, 'dia'))));
  final semanas = <int, List<Map<String, dynamic>>>{};

  for (final row in rows) {
    final date = _dateFromDay(_str(row, 'dia'));
    final semana = ((date.day - 1) ~/ 7) + 1;
    semanas.putIfAbsent(semana, () => []).add(row);
  }

  return semanas.entries.map((entry) {
    final items = entry.value;
    final first = _dateFromDay(_str(items.first, 'dia'));
    final last = _dateFromDay(_str(items.last, 'dia'));
    final total = items.fold<double>(
      0,
      (sum, row) => sum + _num(row, 'costo_total'),
    );
    final dias = items.length;

    return {
      'semana':
          'Semana ${entry.key} · ${DateFormat('dd/MM').format(first)} - ${DateFormat('dd/MM').format(last)}',
      'dias': dias,
      'total': total,
      'promedio': dias == 0 ? 0 : total / dias,
    };
  }).toList();
}

DateTime _dateFromDay(String value) {
  return DateTime.tryParse(value) ?? DateTime(1900);
}

String _formatCantidad(double value) {
  if (value % 1 == 0) return value.toInt().toString();
  return value.toStringAsFixed(2);
}

String _shortDate(String value) {
  if (value.length >= 10) return value.substring(5).replaceAll('-', '/');
  return value;
}

int _labelStep(int itemCount, double width) {
  if (itemCount <= 1) return 1;
  final maxLabels = (width / 70).floor().clamp(2, 10);
  return (itemCount / maxLabels).ceil().clamp(1, itemCount);
}

Color _chartColor(int index) {
  const colors = [
    TecneroTheme.naranja,
    Color(0xFF2563EB),
    Color(0xFF059669),
    Color(0xFF7C3AED),
    Color(0xFFDC2626),
    Color(0xFF0891B2),
  ];
  return colors[index % colors.length];
}
