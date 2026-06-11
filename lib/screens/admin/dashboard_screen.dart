// Dashboard de costos y analitica de materiales para administracion.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../theme/app_theme.dart';
import '../../services/providers.dart';
import '../../models/models.dart' as models;
import '../../widgets/responsive.dart';

enum _PeriodoFiltro {
  hoy,
  ayer,
  semana,
  mes,
  anio,
  personalizado,
}

enum _DatePickerMode { dia, rango }

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  late DateTime _desde;
  late DateTime _hasta;
  late Future<Map<String, dynamic>> _future;

  Set<String> _lineasIdsFiltro = {};
  _PeriodoFiltro _periodo = _PeriodoFiltro.hoy;

  final _fmtMoney = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  final _fmtMoneyShort = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
  final _fmtDate = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _desde = DateTime(now.year, now.month, now.day);
    _hasta = DateTime(now.year, now.month, now.day, 23, 59, 59);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(lineasProvider);
    });
    _load();
  }

  void _load() {
    _future = ref.read(apiServiceProvider).getDashboardData(
          desde: _desde,
          hasta: _hasta,
          lineaIds: _lineasIdsFiltro.isEmpty ? null : _lineasIdsFiltro.toList(),
        );
  }

  void _recargarDatos() {
    ref.invalidate(lineasProvider);
    setState(_load);
  }

  void _setRange(DateTime desde, DateTime hasta) {
    setState(() {
      _desde = DateTime(desde.year, desde.month, desde.day);
      _hasta = DateTime(hasta.year, hasta.month, hasta.day, 23, 59, 59);
      _load();
    });
  }

  void _cambiarPeriodo(_PeriodoFiltro periodo) {
    final now = DateTime.now();

    setState(() {
      _periodo = periodo;

      switch (periodo) {
        case _PeriodoFiltro.hoy:
          _desde = DateTime(now.year, now.month, now.day);
          _hasta = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case _PeriodoFiltro.ayer:
          final ayer = now.subtract(const Duration(days: 1));
          _desde = DateTime(ayer.year, ayer.month, ayer.day);
          _hasta = DateTime(ayer.year, ayer.month, ayer.day, 23, 59, 59);
          break;
        case _PeriodoFiltro.semana:
          final inicioSemana = now.subtract(Duration(days: now.weekday - 1));
          _desde =
              DateTime(inicioSemana.year, inicioSemana.month, inicioSemana.day);
          _hasta = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case _PeriodoFiltro.mes:
          _desde = DateTime(now.year, now.month, 1);
          _hasta = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
          break;
        case _PeriodoFiltro.anio:
          _desde = DateTime(now.year, 1, 1);
          _hasta = DateTime(now.year, 12, 31, 23, 59, 59);
          break;
        case _PeriodoFiltro.personalizado:
          break;
      }

      _load();
    });
  }

  Future<void> _seleccionarFechaUnificada() async {
    final rango = await showDialog<DateTimeRange>(
      context: context,
      builder: (_) => _UnifiedDatePickerDialog(
        initialStart: DateTime(_desde.year, _desde.month, _desde.day),
        initialEnd: DateTime(_hasta.year, _hasta.month, _hasta.day),
        dateThemeBuilder: _dateThemeBuilder,
      ),
    );

    if (rango == null) return;

    setState(() => _periodo = _PeriodoFiltro.personalizado);
    _setRange(rango.start, rango.end);
  }

  Widget _dateThemeBuilder(BuildContext context, Widget? child) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: const ColorScheme.light(
          primary: TecneroTheme.azulOscuro,
          onPrimary: Colors.white,
          surface: Colors.white,
          onSurface: TecneroTheme.textoPrimario,
        ),
      ),
      child: child!,
    );
  }

  void _abrirCalculadora(
    double gastoMateriales,
    List<dynamic> produccionUnitaria,
  ) {
    showDialog(
      context: context,
      builder: (_) => _CalculadoraCostosDialog(
        gastoMaterialesInicial: gastoMateriales,
        fmtMoney: _fmtMoney,
      ),
    );
  }

  Future<void> _exportarPdf(Map<String, dynamic> data) async {
    try {
      final pdf = pw.Document();
      final totales = _map(data['totales']);
      final porLinea = _list(data['por_linea']).map(_map).toList();
      final gastoPorDia = _list(data['gasto_por_dia']).map(_map).toList();
      final gastoLineaDia = _list(data['gasto_linea_dia']).map(_map).toList();
      final topCosto = _list(data['top_materiales']).map(_map).toList();
      final topCantidad =
          _list(data['top_materiales_cantidad']).map(_map).toList();
      final produccionUnitaria =
          _list(data['produccion_unitaria']).map(_map).toList();
      final ultimas = _list(data['ultimas_solicitudes']).map(_map).toList();

      PdfColor pdfColor(Color color) =>
          PdfColor(color.r, color.g, color.b, color.a);

    pw.Widget metric(String label, String value, String hint) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label,
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey700,
                )),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              hint,
              style: const pw.TextStyle(
                fontSize: 8,
                color: PdfColors.grey700,
              ),
            ),
          ],
        ),
      );
    }

    pw.Widget cell(String text, {bool bold = false}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      );
    }

    pw.Widget lineChip(String text, Color color) {
      return pw.Row(
        children: [
          pw.Container(
            width: 8,
            height: 8,
            decoration:
                pw.BoxDecoration(color: pdfColor(color), shape: pw.BoxShape.circle),
          ),
          pw.SizedBox(width: 6),
          pw.Expanded(
            child: pw.Text(
              text.isEmpty ? 'Sin línea' : text,
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
        ],
      );
    }

    List<Map<String, dynamic>> lineasDelMaterial(Map<String, dynamic> row) {
      final raw = row['lineas'] ?? row['detalle_lineas'] ?? row['lineas_produccion'];
      if (raw is List) {
        return raw
            .map((e) => _map(e))
            .where((e) => e.isNotEmpty)
            .toList();
      }
      if (raw is String && raw.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is List) {
            return decoded
                .map((e) => _map(e))
                .where((e) => e.isNotEmpty)
                .toList();
          }
        } catch (_) {
          return const [];
        }
      }
      return const [];
    }

    String nombreLinea(Map<String, dynamic> row) {
      final nombre = _str(row, 'linea_nombre', alt: 'lineaNombre');
      return nombre.isEmpty ? 'Sin línea' : nombre;
    }

    String unidadMaterial(Map<String, dynamic> row) {
      final unidad = _str(row, 'unidad_medida', alt: 'unidadMedida').isEmpty
          ? _str(row, 'unidad', alt: 'unidadMedida')
          : _str(row, 'unidad_medida', alt: 'unidadMedida');
      return unidad.isEmpty ? 'unid' : unidad;
    }

    String fechaPdf(dynamic value) {
      final parsed = DateTime.tryParse(value?.toString() ?? '');
      if (parsed == null) return value?.toString() ?? '';
      return _fmtDate.format(parsed);
    }

    pw.Widget lineaMiniChip(String text, Color color) {
      return pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Container(
            width: 8,
            height: 8,
            decoration: pw.BoxDecoration(
              color: pdfColor(color),
              shape: pw.BoxShape.circle,
            ),
          ),
          pw.SizedBox(width: 6),
          pw.Text(
            text,
            style: const pw.TextStyle(fontSize: 9),
          ),
        ],
      );
    }

    pw.Widget lineaDetallePdf(
      Map<String, dynamic> linea, {
      required bool mostrarCantidad,
      required int index,
    }) {
      final color = _lineaColor(index);
      final nombre = nombreLinea(linea);
      final cantidad = _num(linea, 'cantidad_total');
      final costo = _num(linea, 'costo_total');
      final valor = mostrarCantidad
          ? '${_formatCantidad(cantidad)} ${unidadMaterial(linea)}'
          : _fmtMoney.format(costo);

      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 5),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: 8,
              height: 8,
              margin: const pw.EdgeInsets.only(top: 4),
              decoration: pw.BoxDecoration(
                color: pdfColor(color),
                shape: pw.BoxShape.circle,
              ),
            ),
            pw.SizedBox(width: 6),
            pw.Expanded(
              child: pw.Text(
                nombre,
                style: const pw.TextStyle(fontSize: 9),
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Text(
              valor,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: pdfColor(color),
              ),
            ),
          ],
        ),
      );
    }

    pw.Widget materialesConDetallePdf({
      required String title,
      required List<Map<String, dynamic>> rows,
      required bool mostrarCantidad,
    }) {
      final filtrados = rows.where((row) {
        final cantidad = _num(row, 'cantidad_total');
        final costo = _num(row, 'costo_total');
        return cantidad > 0 || costo > 0;
      }).toList();

      return pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            if (filtrados.isEmpty)
              pw.Text(
                'Sin datos para este periodo.',
                style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              )
            else
              ...filtrados.asMap().entries.map((entry) {
                final index = entry.key;
                final row = entry.value;
                final material =
                    _str(row, 'material_nombre', alt: 'nombre').isEmpty
                        ? _str(row, 'nombre')
                        : _str(row, 'material_nombre', alt: 'nombre');
                final codigo = _str(row, 'codigo', alt: 'material_codigo');
                final cantidad = _num(row, 'cantidad_total');
                final costo = _num(row, 'costo_total');
                final lineas = lineasDelMaterial(row)
                    .where((linea) =>
                        _num(linea, 'cantidad_total') > 0 ||
                        _num(linea, 'costo_total') > 0)
                    .toList();

                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 8),
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        children: [
                          pw.Container(
                            width: 8,
                            height: 8,
                            decoration: pw.BoxDecoration(
                              color: pdfColor(_lineaColor(index)),
                              shape: pw.BoxShape.circle,
                            ),
                          ),
                          pw.SizedBox(width: 6),
                          pw.Expanded(
                            child: pw.Text(
                              codigo.isEmpty ? material : '$codigo · $material',
                              style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                          pw.SizedBox(width: 8),
                          pw.Text(
                            mostrarCantidad
                                ? '${_formatCantidad(cantidad)} ${unidadMaterial(row)}'
                                : _fmtMoney.format(costo),
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: pdfColor(_lineaColor(index)),
                            ),
                          ),
                        ],
                      ),
                      if (lineas.isNotEmpty) ...[
                        pw.SizedBox(height: 6),
                        pw.Container(
                          width: double.infinity,
                          padding: const pw.EdgeInsets.all(8),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.grey100,
                            borderRadius: pw.BorderRadius.circular(6),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'Detalle por línea de producción',
                                style: pw.TextStyle(
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.grey700,
                                ),
                              ),
                              pw.SizedBox(height: 5),
                              ...lineas.asMap().entries.map(
                                    (lineaEntry) => lineaDetallePdf(
                                      lineaEntry.value,
                                      mostrarCantidad: mostrarCantidad,
                                      index: lineaEntry.key,
                                    ),
                                  ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
          ],
        ),
      );
    }

    pw.Widget gastoLineaDiaPdf(List<Map<String, dynamic>> rows) {
      final filtrados = rows
          .where((row) => _num(row, 'costo_total') > 0)
          .toList()
        ..sort((a, b) => _str(a, 'dia').compareTo(_str(b, 'dia')));

      return pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Costo diario por línea',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Table(
              border:
                  pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: const {
                0: pw.FixedColumnWidth(78),
                1: pw.FlexColumnWidth(2),
                2: pw.FixedColumnWidth(72),
              },
              children: [
                pw.TableRow(
                  decoration:
                      const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    cell('Fecha', bold: true),
                    cell('Línea', bold: true),
                    cell('Costo', bold: true),
                  ],
                ),
                ...filtrados.asMap().entries.map(
                  (entry) => pw.TableRow(
                    children: [
                      cell(fechaPdf(_str(entry.value, 'dia'))),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: lineaMiniChip(
                          nombreLinea(entry.value),
                          _lineaColor(entry.key),
                        ),
                      ),
                      cell(_fmtMoney.format(_num(entry.value, 'costo_total'))),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    pw.Widget produccionUnitariaPdf(List<Map<String, dynamic>> rows) {
      final filtrados = rows
          .where((row) => _num(row, 'cantidad_producida') > 0)
          .toList();

      return pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Producción unitaria',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            if (filtrados.isEmpty)
              pw.Text(
                'Sin producción registrada en el periodo.',
                style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              )
            else
              pw.Table(
                border:
                    pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                columnWidths: const {
                  0: pw.FlexColumnWidth(2),
                  1: pw.FixedColumnWidth(52),
                  2: pw.FixedColumnWidth(72),
                  3: pw.FixedColumnWidth(72),
                },
                children: [
                  pw.TableRow(
                    decoration:
                        const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      cell('Línea', bold: true),
                      cell('Unid.', bold: true),
                      cell('Prod.', bold: true),
                      cell('Costo unit.', bold: true),
                    ],
                  ),
                  ...filtrados.asMap().entries.map(
                    (entry) {
                      final row = entry.value;
                      final color = _lineaColor(entry.key);
                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: lineaMiniChip(
                              nombreLinea(row),
                              color,
                            ),
                          ),
                          cell(unidadMaterial(row)),
                          cell(_formatCantidad(_num(row, 'cantidad_producida'))),
                          cell(_fmtMoney.format(_num(row, 'costo_unitario'))),
                        ],
                      );
                    },
                  ),
                ],
              ),
          ],
        ),
      );
    }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (context) => [
            pw.Text(
              'Dashboard de costos de producción',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Periodo: ${_fmtDate.format(_desde)} - ${_fmtDate.format(_hasta)}',
              style: const pw.TextStyle(fontSize: 10),
            ),
            if (_lineasIdsFiltro.isNotEmpty)
              pw.Text(
                'Líneas filtradas: ${_lineasIdsFiltro.length}',
                style: const pw.TextStyle(fontSize: 10),
              ),
            pw.SizedBox(height: 14),
            pw.Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                pw.SizedBox(
                  width: 165,
                  child: metric(
                    'Gasto materiales',
                    _fmtMoney.format(_num(totales, 'costo_total')),
                    'Salidas entregadas valorizadas',
                  ),
                ),
                pw.SizedBox(
                  width: 165,
                  child: metric(
                    'Entregas cerradas',
                    _num(totales, 'entregadas').toInt().toString(),
                    'Solicitudes ya despachadas',
                  ),
                ),
                pw.SizedBox(
                  width: 165,
                  child: metric(
                    'Promedio',
                    _fmtMoney.format(_num(totales, 'promedio_solicitud')),
                    'Costo promedio por pedido',
                  ),
                ),
                pw.SizedBox(
                  width: 165,
                  child: metric(
                    'Materiales usados',
                    _num(totales, 'materiales_consumidos').toInt().toString(),
                    'Ítems consumidos en el periodo',
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 14),
            pw.Text(
              'Costo por línea',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.6),
              columnWidths: const {
                0: pw.FlexColumnWidth(3),
                1: pw.FixedColumnWidth(70),
                2: pw.FixedColumnWidth(95),
                3: pw.FixedColumnWidth(65),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    cell('Línea', bold: true),
                    cell('Entregas', bold: true),
                    cell('Costo', bold: true),
                    cell('%', bold: true),
                  ],
                ),
                for (var i = 0; i < porLinea.length; i++)
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: lineChip(
                          _str(porLinea[i], 'linea_nombre', alt: 'lineaNombre'),
                          _lineaColor(i),
                        ),
                      ),
                      cell(_num(porLinea[i], 'total_solicitudes').toInt().toString()),
                      cell(_fmtMoney.format(_num(porLinea[i], 'costo_total'))),
                      cell(
                        _num(totales, 'costo_total') > 0
                            ? '${((_num(porLinea[i], 'costo_total') / _num(totales, 'costo_total')) * 100).toStringAsFixed(1)}%'
                            : '0%',
                      ),
                    ],
                  ),
              ],
            ),
            pw.SizedBox(height: 14),
            gastoLineaDiaPdf(gastoLineaDia),
            pw.SizedBox(height: 14),
            produccionUnitariaPdf(produccionUnitaria),
            pw.SizedBox(height: 14),
            materialesConDetallePdf(
              title: 'Materiales por costo',
              rows: topCosto,
              mostrarCantidad: false,
            ),
            pw.SizedBox(height: 14),
            materialesConDetallePdf(
              title: 'Materiales por cantidad',
              rows: topCantidad,
              mostrarCantidad: true,
            ),
            pw.SizedBox(height: 14),
            pw.Text(
              'Últimos consumos registrados',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.6),
              columnWidths: const {
                0: pw.FixedColumnWidth(74),
                1: pw.FlexColumnWidth(1.5),
                2: pw.FlexColumnWidth(1.2),
                3: pw.FixedColumnWidth(80),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    cell('Fecha', bold: true),
                    cell('Línea', bold: true),
                    cell('Estado', bold: true),
                    cell('Costo', bold: true),
                  ],
                ),
                ...ultimas.take(8).map(
                  (row) => pw.TableRow(
                    children: [
                      cell(_str(row, 'fecha')),
                      cell(_str(row, 'linea_nombre', alt: 'lineaNombre')),
                      cell(_str(row, 'estado')),
                      cell(_fmtMoney.format(_num(row, 'costo_total'))),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 14),
            pw.Text(
              'Gasto por día',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.6),
              columnWidths: const {
                0: pw.FixedColumnWidth(90),
                1: pw.FixedColumnWidth(110),
                2: pw.FixedColumnWidth(110),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    cell('Fecha', bold: true),
                    cell('Costo', bold: true),
                    cell('Solicitudes', bold: true),
                  ],
                ),
                ...gastoPorDia.take(10).map(
                  (row) => pw.TableRow(
                    children: [
                      cell(_str(row, 'dia')),
                      cell(_fmtMoney.format(_num(row, 'costo_total'))),
                      cell(_num(row, 'total_solicitudes').toInt().toString()),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );

      final bytes = await pdf.save();
      final ok = await Printing.sharePdf(
        bytes: bytes,
        filename:
            'dashboard-costos-${_fmtDate.format(_desde).replaceAll('/', '-')}-${_fmtDate.format(_hasta).replaceAll('/', '-')}.pdf',
      );

      if (!ok) {
        throw Exception(
          'El navegador bloqueó la descarga del PDF. Revisa permisos de descarga o ventanas emergentes.',
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF generado y descargado'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
          showCloseIcon: true,
        ),
      );
    } catch (e, st) {
      debugPrint('No se pudo exportar el PDF: $e');
      debugPrintStack(stackTrace: st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo descargar el PDF: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          showCloseIcon: true,
          closeIconColor: Colors.white,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // El dashboard se recarga cuando cambia el contador global de refresco,
    // por ejemplo cuando entra una notificación que altera solicitudes o stock.
    ref.listen<int>(dashboardRefreshProvider, (previous, next) {
      if (previous != next && mounted) {
        setState(_load);
      }
    });

    final lineasAsync = ref.watch(lineasProvider);

    return Scaffold(
      backgroundColor: TecneroTheme.grisClaro,
      body: Column(
        children: [
          _Header(
            desde: _desde,
            hasta: _hasta,
            fmtDate: _fmtDate,
            onRefresh: _recargarDatos,
          ),
          _Filtros(
            periodo: _periodo,
            desde: _desde,
            hasta: _hasta,
            lineasIds: _lineasIdsFiltro,
            lineas: lineasAsync.asData?.value ?? const [],
            onPeriodoChanged: _cambiarPeriodo,
            onFechaPersonalizada: _seleccionarFechaUnificada,
            onLineasChanged: (value) {
              setState(() {
                _lineasIdsFiltro = value;
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
                  return _ErrorWidget(message: snapshot.error.toString());
                }

                // El dashboard combina varios agregados calculados en backend.
                final data = snapshot.data ?? <String, dynamic>{};
                final totales = _map(data['totales']);
                final porLinea = _list(data['por_linea']);
                final gastoPorDia = _list(data['gasto_por_dia']);
                final gastoLineaDia = _list(data['gasto_linea_dia']);
                final topCosto = _list(data['top_materiales']);
                final topCantidad = _list(data['top_materiales_cantidad']);
                final variacionPrecios = _list(data['variacion_precios']);
                final produccionUnitaria = _list(data['produccion_unitaria']);
                final ultimas = _list(data['ultimas_solicitudes']);
                final produccionSinCargar = produccionUnitaria.isNotEmpty &&
                    produccionUnitaria.every((raw) =>
                        _num(_map(raw), 'cantidad_producida') <= 0);
                final necesitaProduccion =
                    produccionUnitaria.isEmpty || produccionSinCargar;

                final gastoTotal = _num(totales, 'costo_total');
                final totalEntregadas = _num(totales, 'entregadas');
                final promedioSolicitud = _num(totales, 'promedio_solicitud');
                final materialesConsumidos =
                    _num(totales, 'materiales_consumidos');
                final lineaMasCara = _lineaMasCara(porLinea);
                final materialMasCaro = _materialMasCaro(topCosto);
                final tendenciaGasto = _tendenciaGasto(gastoPorDia);

                return SingleChildScrollView(
                  padding: Responsive.pagePadding(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ActionBar(
                        gastoTotal: gastoTotal,
                        fmtMoney: _fmtMoney,
                        onCalculadora: () =>
                            _abrirCalculadora(gastoTotal, produccionUnitaria),
                        onPdf: () => _exportarPdf(data),
                      ),
                      const SizedBox(height: 16),
                      _ExecutiveSummary(
                        fmtMoney: _fmtMoney,
                        gastoTotal: gastoTotal,
                        entregadas: totalEntregadas,
                        promedioSolicitud: promedioSolicitud,
                        materialesConsumidos: materialesConsumidos,
                        lineaMasCara: lineaMasCara,
                        materialMasCaro: materialMasCaro,
                        tendenciaGasto: tendenciaGasto,
                      ),
                      const SizedBox(height: 16),
                      _SectionCard(
                        title: 'Costo real por día y línea de producción',
                        subtitle:
                            'La leyenda muestra qué color pertenece a cada línea. Útil para ver cuándo y dónde se consume más material.',
                        child: gastoPorDia.isEmpty && gastoLineaDia.isEmpty
                            ? const _EmptyState(
                                msg: 'Sin consumos entregados en el periodo')
                            : _CostoDiaLineaChart(
                                gastoPorDia: gastoPorDia,
                                gastoLineaDia: gastoLineaDia,
                                fmtMoney: _fmtMoneyShort,
                                lineaSeleccionada: _lineasIdsFiltro.isNotEmpty,
                              ),
                      ),
                      const SizedBox(height: 16),
                      _SectionCard(
                        title: 'Costo unitario por producción',
                        subtitle:
                            'Cruza las unidades producidas con los materiales despachados para ver costo por cilindro, asa, base o reparación.',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (necesitaProduccion) ...[
                              _ProduccionPendienteNotice(
                                onAbrirProduccion: () =>
                                    context.go('/admin/produccion'),
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (produccionUnitaria.isEmpty)
                              const _EmptyState(
                                msg: 'Ingresa la cantidad producida para calcular el costo unitario. Si todavía no la tienes, puedes dejarla pendiente y volver luego.',
                              )
                            else
                              _TablaCostoUnitarioProduccion(
                                data: produccionUnitaria,
                                fmtMoney: _fmtMoney,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SectionCard(
                        title: 'Simulador de gastos adicionales',
                        subtitle:
                            'Agrega gastos adicionales (personal, etc.) para ver el costo total real del periodo.',
                        child: _SimuladorGastosAdicionales(
                          gastoMateriales: gastoTotal,
                          fmtMoney: _fmtMoney,
                          produccionUnitaria: produccionUnitaria,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _ResponsiveTwoColumn(
                        leftFlex: 3,
                        rightFlex: 2,
                        left: _SectionCard(
                          title: 'Costo por línea de producción',
                          subtitle:
                              'Comparación entre fabricación de cilindros, reparación, asas, bases y válvulas.',
                          child: porLinea.isEmpty
                              ? const _EmptyState(msg: 'Sin datos por línea')
                              : _LineasCostoPanel(
                                  porLinea: porLinea,
                                  fmtMoney: _fmtMoney,
                                  fmtMoneyShort: _fmtMoneyShort,
                                ),
                        ),
                        right: _SectionCard(
                          title: 'Lectura de costos',
                          subtitle:
                              'Resumen directo del periodo filtrado para revisar consumo, compras y precio.',
                          child: _CostInsightPanel(
                            gastoTotal: gastoTotal,
                            promedioSolicitud: promedioSolicitud,
                            entregadas: totalEntregadas,
                            lineaMasCara: lineaMasCara,
                            materialMasCaro: materialMasCaro,
                            fmtMoney: _fmtMoney,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _ResponsiveTwoColumn(
                        left: _SectionCard(
                          title: 'Materiales por gasto del periodo',
                          subtitle:
                              'Todos los materiales despachados, ordenados por costo real FIFO. Toca un material para ver el detalle por línea.',
                          child: topCosto.isEmpty
                              ? const _EmptyState(
                                  msg: 'Sin datos de materiales')
                              : _TablaMaterialesCriticos(
                                  data: topCosto,
                                  tipo: _TipoTablaMaterial.costo,
                                  fmt: _fmtMoney,
                                ),
                        ),
                        right: _SectionCard(
                          title: 'Materiales por cantidad usada',
                          subtitle:
                              'Todos los materiales despachados, ordenados por consumo físico. Toca un material para ver el detalle por línea.',
                          child: topCantidad.isEmpty
                              ? const _EmptyState(
                                  msg: 'Sin datos de cantidades')
                              : _TablaMaterialesCriticos(
                                  data: topCantidad,
                                  tipo: _TipoTablaMaterial.cantidad,
                                  fmt: _fmtMoney,
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _ResponsiveTwoColumn(
                        left: _SectionCard(
                          title: 'Gasto diario del periodo',
                          subtitle:
                              'Días con mayor salida de bodega valorizada.',
                          child: gastoPorDia.isEmpty
                              ? const _EmptyState(msg: 'Sin datos diarios')
                              : _TablaGastoPorDia(
                                  data: gastoPorDia, fmt: _fmtMoney),
                        ),
                        right: _SectionCard(
                          title: 'Últimos consumos registrados',
                          subtitle:
                              'Movimientos recientes para auditar qué línea pidió y cuánto costó.',
                          child: ultimas.isEmpty
                              ? const _EmptyState(
                                  msg: 'Sin solicitudes recientes')
                              : _TablaUltimasSolicitudes(
                                  data: ultimas, fmt: _fmtMoney),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SectionCard(
                        title: 'Precios usados por material',
                        subtitle:
                            'Precio promedio calculado con el costo real despachado. Ayuda a revisar si un material subió o está encareciendo una línea.',
                        child: topCosto.isEmpty
                            ? const _EmptyState(msg: 'Sin precios históricos')
                            : _TablaPreciosMateriales(
                                data: topCosto,
                                cambiosPrecio: variacionPrecios,
                                fmt: _fmtMoney,
                              ),
                      ),
                      const SizedBox(height: 16),
                      _SectionCard(
                        title: 'Cambios de precio recientes',
                        subtitle:
                            'Solo aparecen materiales cuyo precio realmente cambió. Rojo subió, verde bajó.',
                        child: variacionPrecios.isEmpty
                            ? const _EmptyState(
                                msg:
                                    'No hay materiales con cambio de precio registrado')
                            : _TablaVariacionPrecios(
                                data: variacionPrecios,
                                fmt: _fmtMoney,
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

class _Header extends StatelessWidget {
  final DateTime desde;
  final DateTime hasta;
  final DateFormat fmtDate;
  final VoidCallback onRefresh;

  const _Header({
    required this.desde,
    required this.hasta,
    required this.fmtDate,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Container(
      color: Colors.white,
      padding: Responsive.headerPadding(context),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _HeaderTitle(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _DateBadge(
                          text:
                              '${fmtDate.format(desde)} - ${fmtDate.format(hasta)}'),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: onRefresh,
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Actualizar',
                    ),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                const Expanded(child: _HeaderTitle()),
                _DateBadge(
                    text:
                        '${fmtDate.format(desde)} - ${fmtDate.format(hasta)}'),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Actualizar',
                ),
              ],
            ),
    );
  }
}

class _UnifiedDatePickerDialog extends StatefulWidget {
  final DateTime initialStart;
  final DateTime initialEnd;
  final TransitionBuilder dateThemeBuilder;

  const _UnifiedDatePickerDialog({
    required this.initialStart,
    required this.initialEnd,
    required this.dateThemeBuilder,
  });

  @override
  State<_UnifiedDatePickerDialog> createState() =>
      _UnifiedDatePickerDialogState();
}

class _UnifiedDatePickerDialogState extends State<_UnifiedDatePickerDialog> {
  late DateTime _start;
  late DateTime _end;
  late DateTime _visibleMonth;

  bool _selectingEnd = false;

  final _fmtDate = DateFormat('dd/MM/yyyy');
  final _fmtMonth = DateFormat('MMMM yyyy');

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void initState() {
    super.initState();

    _start = DateTime(
      widget.initialStart.year,
      widget.initialStart.month,
      widget.initialStart.day,
    );

    _end = DateTime(
      widget.initialEnd.year,
      widget.initialEnd.month,
      widget.initialEnd.day,
    );

    if (_end.isAfter(_today)) {
      _end = _today;
    }

    if (_start.isAfter(_end)) {
      _start = _end;
    }

    _visibleMonth = DateTime(_start.year, _start.month, 1);
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isDisabled(DateTime day) {
    return day.isAfter(_today);
  }

  bool _isBetween(DateTime day) {
    final min = _start.isBefore(_end) ? _start : _end;
    final max = _start.isBefore(_end) ? _end : _start;

    return day.isAfter(min) && day.isBefore(max);
  }

  bool _isSelected(DateTime day) {
    return _sameDay(day, _start) || _sameDay(day, _end);
  }

  bool _isInRange(DateTime day) {
    return _isSelected(day) || _isBetween(day);
  }

  void _onDateSelected(DateTime value) {
    if (_isDisabled(value)) return;

    final selected = DateTime(value.year, value.month, value.day);

    setState(() {
      if (!_selectingEnd) {
        _start = selected;
        _end = selected;
        _selectingEnd = true;
        return;
      }

      if (selected.isBefore(_start)) {
        _end = _start;
        _start = selected;
      } else {
        _end = selected;
      }

      _selectingEnd = false;
    });
  }

  void _previousMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    if (!_canGoNextMonth) return;

    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 1);
    });
  }

  bool get _canGoNextMonth {
    final currentMonth = DateTime(_today.year, _today.month, 1);
    final nextMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 1);

    return !nextMonth.isAfter(currentMonth);
  }

  String _labelSeleccion() {
    if (_sameDay(_start, _end)) {
      return 'Fecha seleccionada: ${_fmtDate.format(_start)}';
    }

    return 'Rango seleccionado: ${_fmtDate.format(_start)} - ${_fmtDate.format(_end)}';
  }

  String _ayudaSeleccion() {
    if (_selectingEnd) {
      return 'Ahora toca la fecha final para seleccionar varios días.';
    }

    return 'Toca una fecha para iniciar una nueva selección.';
  }

  List<DateTime?> _daysForMonth() {
    final firstDay = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final lastDay = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0);

    final offset = firstDay.weekday % 7;
    final totalDays = lastDay.day;
    final totalCells = ((offset + totalDays) / 7).ceil() * 7;

    return List.generate(totalCells, (index) {
      final dayNumber = index - offset + 1;

      if (dayNumber < 1 || dayNumber > totalDays) {
        return null;
      }

      return DateTime(_visibleMonth.year, _visibleMonth.month, dayNumber);
    });
  }

  Widget _buildDay(DateTime? day) {
    if (day == null) {
      return const SizedBox(height: 42);
    }

    final disabled = _isDisabled(day);
    final selected = _isSelected(day);
    final between = _isBetween(day);
    final inRange = _isInRange(day);

    final Color textColor;
    final Color backgroundColor;
    final FontWeight fontWeight;

    if (disabled) {
      textColor = Colors.grey.shade400;
      backgroundColor = Colors.transparent;
      fontWeight = FontWeight.w500;
    } else if (selected) {
      textColor = Colors.white;
      backgroundColor = TecneroTheme.azulOscuro;
      fontWeight = FontWeight.w900;
    } else if (between) {
      textColor = TecneroTheme.azulOscuro;
      backgroundColor = TecneroTheme.azulOscuro.withValues(alpha: 0.12);
      fontWeight = FontWeight.w800;
    } else {
      textColor = TecneroTheme.textoPrimario;
      backgroundColor = Colors.transparent;
      fontWeight = FontWeight.w500;
    }

    return InkWell(
      onTap: disabled ? null : () => _onDateSelected(day),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: selected ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: selected ? null : BorderRadius.circular(999),
          border: inRange && !selected
              ? Border.all(
                  color: TecneroTheme.azulOscuro.withValues(alpha: 0.12),
                )
              : null,
        ),
        child: Text(
          '${day.day}',
          style: TextStyle(
            fontSize: 13,
            color: textColor,
            fontWeight: fontWeight,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final days = _daysForMonth();

    return AlertDialog(
      title: const Text('Seleccionar fecha'),
      content: SizedBox(
        width:
            (MediaQuery.sizeOf(context).width - 48).clamp(280, 430).toDouble(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: TecneroTheme.grisBorde),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _labelSeleccion(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: TecneroTheme.azulOscuro,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _ayudaSeleccion(),
                    style: const TextStyle(
                      fontSize: 11,
                      color: TecneroTheme.textoSecundario,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _fmtMonth.format(_visibleMonth),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: TecneroTheme.textoPrimario,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _previousMonth,
                  icon: const Icon(Icons.chevron_left),
                  tooltip: 'Mes anterior',
                ),
                IconButton(
                  onPressed: _canGoNextMonth ? _nextMonth : null,
                  icon: const Icon(Icons.chevron_right),
                  tooltip: 'Mes siguiente',
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Row(
              children: [
                _WeekDayLabel('D'),
                _WeekDayLabel('L'),
                _WeekDayLabel('M'),
                _WeekDayLabel('M'),
                _WeekDayLabel('J'),
                _WeekDayLabel('V'),
                _WeekDayLabel('S'),
              ],
            ),
            const SizedBox(height: 6),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: days.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
              ),
              itemBuilder: (_, index) => _buildDay(days[index]),
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
            Navigator.pop(
              context,
              DateTimeRange(
                start: _start,
                end: _end,
              ),
            );
          },
          icon: const Icon(Icons.check_outlined, size: 18),
          label: const Text('Aplicar'),
          style: ElevatedButton.styleFrom(
            backgroundColor: TecneroTheme.naranja,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _WeekDayLabel extends StatelessWidget {
  final String text;

  const _WeekDayLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            color: TecneroTheme.textoSecundario,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
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
          'Dashboard de costos de producción',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: TecneroTheme.textoPrimario,
          ),
        ),
        SizedBox(height: 2),
        Text(
          'Control en tiempo real de consumo de bodega, costo por línea y materiales críticos',
          style: TextStyle(fontSize: 13, color: TecneroTheme.textoSecundario),
        ),
      ],
    );
  }
}

class _DateBadge extends StatelessWidget {
  final String text;

  const _DateBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: TecneroTheme.azulOscuro,
          fontWeight: FontWeight.w700,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _Filtros extends StatelessWidget {
  final _PeriodoFiltro periodo;
  final DateTime desde;
  final DateTime hasta;
  final Set<String> lineasIds;
  final List<models.LineaProduccion> lineas;
  final ValueChanged<_PeriodoFiltro> onPeriodoChanged;
  final VoidCallback onFechaPersonalizada;
  final ValueChanged<Set<String>> onLineasChanged;

  const _Filtros({
    required this.periodo,
    required this.desde,
    required this.hasta,
    required this.lineasIds,
    required this.lineas,
    required this.onPeriodoChanged,
    required this.onFechaPersonalizada,
    required this.onLineasChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    Widget buildFilters(bool compact) {
      final periodoDropdown = SizedBox(
        width: compact ? double.infinity : 210,
        child: DropdownButtonFormField<_PeriodoFiltro>(
          initialValue: periodo,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Periodo rápido',
            prefixIcon: Icon(Icons.filter_alt_outlined, size: 18),
            isDense: true,
          ),
          items: const [
            DropdownMenuItem(value: _PeriodoFiltro.hoy, child: Text('Hoy')),
            DropdownMenuItem(value: _PeriodoFiltro.ayer, child: Text('Ayer')),
            DropdownMenuItem(
              value: _PeriodoFiltro.semana,
              child: Text('Esta semana'),
            ),
            DropdownMenuItem(
              value: _PeriodoFiltro.mes,
              child: Text('Este mes'),
            ),
            DropdownMenuItem(
              value: _PeriodoFiltro.anio,
              child: Text('Este año'),
            ),
            DropdownMenuItem(
              value: _PeriodoFiltro.personalizado,
              child: Text('Personalizado'),
            ),
          ],
          onChanged: (value) {
            if (value == null) return;
            if (value == _PeriodoFiltro.personalizado) {
              onFechaPersonalizada();
            } else {
              onPeriodoChanged(value);
            }
          },
        ),
      );

      final lineaDropdown = SizedBox(
        width: compact ? double.infinity : 390,
        child: _LineasMultiSelectDropdown(
          lineasIds: lineasIds,
          lineas: lineas,
          onChanged: onLineasChanged,
        ),
      );

      final fechaButton = SizedBox(
        width: compact ? double.infinity : 180,
        child: OutlinedButton.icon(
          onPressed: onFechaPersonalizada,
          icon: const Icon(Icons.calendar_today_outlined, size: 17),
          label: const Text('Fecha o rango'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        ),
      );

      if (compact) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            periodoDropdown,
            const SizedBox(height: 10),
            lineaDropdown,
            const SizedBox(height: 10),
            fechaButton,
          ],
        );
      }

      return Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          periodoDropdown,
          lineaDropdown,
          fechaButton,
        ],
      );
    }

    return Container(
      color: Colors.white,
      padding:
          EdgeInsets.fromLTRB(isMobile ? 16 : 28, 0, isMobile ? 16 : 28, 16),
      child: isMobile
          ? SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    builder: (_) => Padding(
                      padding: EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 16,
                        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                      ),
                      child: SingleChildScrollView(child: buildFilters(true)),
                    ),
                  );
                },
                icon: const Icon(Icons.tune_outlined, size: 18),
                label: const Text('Filtros del dashboard'),
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) =>
                  buildFilters(constraints.maxWidth < 900),
            ),
    );
  }
}

class _LineasMultiSelectDropdown extends StatelessWidget {
  final Set<String> lineasIds;
  final List<models.LineaProduccion> lineas;
  final ValueChanged<Set<String>> onChanged;

  const _LineasMultiSelectDropdown({
    required this.lineasIds,
    required this.lineas,
    required this.onChanged,
  });

  bool get _todasSeleccionadas => lineasIds.isEmpty;

  String _resumen() {
    if (_todasSeleccionadas) return 'Todas seleccionadas';
    if (lineasIds.length == 1) {
      final linea = lineas.where((l) => lineasIds.contains(l.id)).toList();
      if (linea.isNotEmpty) return linea.first.nombre;
    }
    return '${lineasIds.length} líneas seleccionadas';
  }

  Future<void> _abrirSelector(BuildContext context) async {
    final seleccionInicial = Set<String>.from(lineasIds);

    final resultado = await showDialog<Set<String>>(
      context: context,
      builder: (_) => _LineasSelectorDialog(
        lineas: lineas,
        initialSelected: seleccionInicial,
      ),
    );

    if (resultado == null) return;
    onChanged(resultado);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
        InkWell(
          onTap: () => _abrirSelector(context),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: double.infinity,
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: TecneroTheme.grisBorde),
            ),
            child: Row(
              children: [
                Icon(
                  _todasSeleccionadas
                      ? Icons.done_all_outlined
                      : Icons.checklist_outlined,
                  size: 18,
                  color: TecneroTheme.naranja,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _resumen(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: TecneroTheme.textoPrimario,
                    ),
                  ),
                ),
                const Icon(
                  Icons.keyboard_arrow_down_outlined,
                  color: TecneroTheme.textoSecundario,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LineasSelectorDialog extends StatefulWidget {
  final List<models.LineaProduccion> lineas;
  final Set<String> initialSelected;

  const _LineasSelectorDialog({
    required this.lineas,
    required this.initialSelected,
  });

  @override
  State<_LineasSelectorDialog> createState() => _LineasSelectorDialogState();
}

class _LineasSelectorDialogState extends State<_LineasSelectorDialog> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.initialSelected);
  }

  bool get _todas => _selected.isEmpty;

  void _toggleTodas() {
    setState(() => _selected.clear());
  }

  void _toggleLinea(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  Widget _optionRow({
    required bool checked,
    required String text,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
        child: Row(
          children: [
            Checkbox(
              value: checked,
              onChanged: (_) => onTap(),
              activeColor: TecneroTheme.naranja,
            ),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: checked ? FontWeight.w900 : FontWeight.w600,
                  color: checked
                      ? TecneroTheme.azulOscuro
                      : TecneroTheme.textoPrimario,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Dialog(
      insetPadding: EdgeInsets.all(isMobile ? 12 : 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 440,
          maxHeight: MediaQuery.sizeOf(context).height * 0.86,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: TecneroTheme.naranja.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.factory_outlined,
                      color: TecneroTheme.naranja,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Líneas de producción',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'Selecciona una o varias líneas',
                          style: TextStyle(
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
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _optionRow(
                        checked: _todas,
                        text: 'Todas',
                        onTap: _toggleTodas,
                      ),
                      const Divider(height: 8),
                      ...widget.lineas.map(
                        (linea) => _optionRow(
                          checked: _todas || _selected.contains(linea.id),
                          text: linea.nombre,
                          onTap: () => _toggleLinea(linea.id),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => Navigator.pop(context, _selected),
                    icon: const Icon(Icons.check_outlined, size: 18),
                    label: const Text('Aplicar'),
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

class _ActionBar extends StatelessWidget {
  final double gastoTotal;
  final NumberFormat fmtMoney;
  final VoidCallback onCalculadora;
  final VoidCallback onPdf;

  const _ActionBar({
    required this.gastoTotal,
    required this.fmtMoney,
    required this.onCalculadora,
    required this.onPdf,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 14 : 18),
      decoration: BoxDecoration(
        color: TecneroTheme.azulOscuro,
        borderRadius: BorderRadius.circular(16),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.analytics_outlined,
                    color: Colors.white, size: 22),
                const SizedBox(height: 10),
                const Text(
                  'Costo de materiales del periodo',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  fmtMoney.format(gastoTotal),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: onCalculadora,
                          icon: const Icon(Icons.calculate_outlined, size: 17),
                          label: const Text('Calcular costo unitario'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: TecneroTheme.naranja,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: onPdf,
                          icon: const Icon(Icons.picture_as_pdf_outlined,
                              size: 17),
                          label: const Text('Descargar PDF'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white54),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child:
                      const Icon(Icons.analytics_outlined, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Costo de materiales del periodo',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      Text(
                        fmtMoney.format(gastoTotal),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: onCalculadora,
                  icon: const Icon(Icons.calculate_outlined, size: 17),
                  label: const Text('Calcular costo unitario'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TecneroTheme.naranja,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: onPdf,
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 17),
                  label: const Text('Descargar PDF'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ExecutiveSummary extends StatelessWidget {
  final NumberFormat fmtMoney;
  final double gastoTotal;
  final double entregadas;
  final double promedioSolicitud;
  final double materialesConsumidos;
  final _LineaResumen? lineaMasCara;
  final _MaterialResumen? materialMasCaro;
  final _TendenciaGasto? tendenciaGasto;

  const _ExecutiveSummary({
    required this.fmtMoney,
    required this.gastoTotal,
    required this.entregadas,
    required this.promedioSolicitud,
    required this.materialesConsumidos,
    required this.lineaMasCara,
    required this.materialMasCaro,
    required this.tendenciaGasto,
  });

  @override
  Widget build(BuildContext context) {
    return _ResponsiveMetricGrid(
      children: [
        _MetricCard(
          label: 'Gasto materiales',
          value: fmtMoney.format(gastoTotal),
          hint: 'Salidas entregadas valorizadas',
          icon: Icons.attach_money,
          color: TecneroTheme.naranja,
        ),
        _MetricCard(
          label: 'Entregas cerradas',
          value: entregadas.toInt().toString(),
          hint: 'Solicitudes ya despachadas',
          icon: Icons.local_shipping_outlined,
          color: const Color(0xFF059669),
        ),
        _MetricCard(
          label: 'Variación diaria',
          value: tendenciaGasto == null
              ? 'Sin comparar'
              : tendenciaGasto!.formatoVariacion,
          hint: tendenciaGasto == null
              ? 'Necesita al menos 2 días'
              : 'Antes: ${fmtMoney.format(tendenciaGasto!.anterior)} · Ahora: ${fmtMoney.format(tendenciaGasto!.actual)}',
          icon: tendenciaGasto != null && tendenciaGasto!.variacion >= 0
              ? Icons.trending_up_outlined
              : Icons.trending_down_outlined,
          color: tendenciaGasto != null && tendenciaGasto!.variacion >= 0
              ? TecneroTheme.naranja
              : const Color(0xFF059669),
        ),
        _MetricCard(
          label: 'Promedio por pedido',
          value: fmtMoney.format(promedioSolicitud),
          hint: 'Costo promedio por solicitud',
          icon: Icons.calculate_outlined,
          color: const Color(0xFF2563EB),
        ),
        _MetricCard(
          label: 'Materiales usados',
          value: materialesConsumidos.toInt().toString(),
          hint: 'Ítems consumidos en producción',
          icon: Icons.inventory_2_outlined,
          color: const Color(0xFF7C3AED),
        ),
        _MetricCard(
          label: 'Línea más costosa',
          value: lineaMasCara == null
              ? 'Sin datos'
              : fmtMoney.format(lineaMasCara!.costo),
          hint: lineaMasCara?.nombre ?? 'Sin línea registrada',
          icon: Icons.factory_outlined,
          color: const Color(0xFF0891B2),
        ),
        _MetricCard(
          label: 'Material crítico',
          value: materialMasCaro == null
              ? 'Sin datos'
              : fmtMoney.format(materialMasCaro!.costo),
          hint: materialMasCaro?.nombre ?? 'Sin material registrado',
          icon: Icons.warning_amber_outlined,
          color: const Color(0xFFDC2626),
        ),
      ],
    );
  }
}

class _ResponsiveMetricGrid extends StatelessWidget {
  final List<Widget> children;

  const _ResponsiveMetricGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final width = constraints.maxWidth;
        final columns = width < 620
            ? 1
            : width < 960
                ? 2
                : width < 1280
                    ? 3
                    : 6;
        const spacing = 12.0;
        final itemWidth = (width - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: children
              .map(
                (child) => SizedBox(
                  width: itemWidth,
                  height: Responsive.isMobile(context) ? 136 : 128,
                  child: child,
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String hint;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.hint,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TecneroTheme.grisBorde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const Spacer(),
            ],
          ),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: isMobile ? 17 : 18,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 11,
                color: TecneroTheme.textoPrimario,
                fontWeight: FontWeight.w800),
          ),
          Text(
            hint,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 10, color: TecneroTheme.textoSecundario),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(Responsive.isMobile(context) ? 14 : 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: TecneroTheme.textoPrimario,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                  fontSize: 12, color: TecneroTheme.textoSecundario),
            ),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: child),
          ],
        ),
      ),
    );
  }
}

class _CostoDiaLineaChart extends StatelessWidget {
  final List<dynamic> gastoPorDia;
  final List<dynamic> gastoLineaDia;
  final NumberFormat fmtMoney;
  final bool lineaSeleccionada;

  const _CostoDiaLineaChart({
    required this.gastoPorDia,
    required this.gastoLineaDia,
    required this.fmtMoney,
    required this.lineaSeleccionada,
  });

  @override
  Widget build(BuildContext context) {
    final dias = _diasOrdenados(gastoPorDia, gastoLineaDia);
    final resumenLineas = _resumenPorLinea(gastoLineaDia);
    final lineas = resumenLineas.map((e) => e.key).take(5).toList();
    final matriz = _matrizPorDiaLinea(gastoLineaDia);
    final maxY = _maxPorDia(dias, matriz);
    final grupos = _barGroups(dias, lineas, matriz);

    if (dias.isEmpty) {
      return const _EmptyState(msg: 'No hay consumos para graficar');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LineLegend(lineas: lineas, totals: resumenLineas, fmtMoney: fmtMoney),
        const SizedBox(height: 12),
        SizedBox(
          height: Responsive.isMobile(context) ? 300 : 360,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxY <= 0 ? 10.0 : maxY * 1.22,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY <= 0 ? 2.0 : (maxY / 4),
                getDrawingHorizontalLine: (_) => const FlLine(
                  color: TecneroTheme.grisBorde,
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border.all(color: TecneroTheme.grisBorde),
              ),
              titlesData: FlTitlesData(
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: Responsive.isMobile(context) ? 44.0 : 58.0,
                    getTitlesWidget: (value, meta) => Text(
                      fmtMoney.format(value),
                      style: const TextStyle(
                          fontSize: 9, color: TecneroTheme.textoSecundario),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 34.0,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= dias.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _diaCorto(dias[index]),
                          style: const TextStyle(
                              fontSize: 10,
                              color: TecneroTheme.textoSecundario),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => Colors.white,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final dia = groupIndex >= 0 && groupIndex < dias.length
                        ? _diaCorto(dias[groupIndex])
                        : '';
                    return BarTooltipItem(
                      '$dia\nTotal: ${fmtMoney.format(rod.toY)}',
                      const TextStyle(
                        color: TecneroTheme.textoPrimario,
                        fontWeight: FontWeight.w800,
                      ),
                    );
                  },
                ),
              ),
              barGroups: grupos,
            ),
          ),
        ),
        const SizedBox(height: 14),
        _DetalleDiaLinea(
            detalles: _detallesPorDia(gastoLineaDia), fmtMoney: fmtMoney),
      ],
    );
  }

  List<String> _diasOrdenados(List<dynamic> gastoPorDia, List<dynamic> data) {
    final set = <String>{};
    for (final row in gastoPorDia) {
      final m = _map(row);
      final dia = _str(m, 'dia');
      if (dia.isNotEmpty) set.add(dia);
    }
    for (final row in data) {
      final m = _map(row);
      final dia = _str(m, 'dia');
      if (dia.isNotEmpty) set.add(dia);
    }
    return set.toList()..sort();
  }

  Map<String, Map<String, double>> _matrizPorDiaLinea(List<dynamic> data) {
    final matriz = <String, Map<String, double>>{};
    for (final raw in data) {
      final row = _map(raw);
      final dia = _str(row, 'dia');
      final linea = _str(row, 'linea_nombre', alt: 'lineaNombre').isEmpty
          ? 'Sin línea'
          : _str(row, 'linea_nombre', alt: 'lineaNombre');
      final costo = _num(row, 'costo_total');
      if (dia.isEmpty) continue;
      matriz.putIfAbsent(dia, () => <String, double>{});
      matriz[dia]![linea] = (matriz[dia]![linea] ?? 0) + costo;
    }
    return matriz;
  }

  double _maxPorDia(
      List<String> dias, Map<String, Map<String, double>> matriz) {
    var max = 0.0;
    for (final dia in dias) {
      final total = (matriz[dia] ?? {}).values.fold(0.0, (a, b) => a + b);
      if (total > max) max = total;
    }
    return max;
  }

  List<BarChartGroupData> _barGroups(
    List<String> dias,
    List<String> lineas,
    Map<String, Map<String, double>> matriz,
  ) {
    final barWidth = dias.length <= 3
        ? 56.0
        : dias.length <= 7
            ? 38.0
            : 24.0;

    return List.generate(dias.length, (index) {
      final dia = dias[index];
      final values = matriz[dia] ?? <String, double>{};
      var fromY = 0.0;
      final stacks = <BarChartRodStackItem>[];

      for (var i = 0; i < lineas.length; i++) {
        final value = values[lineas[i]] ?? 0;
        if (value <= 0) continue;
        stacks.add(BarChartRodStackItem(fromY, fromY + value, _lineaColor(i)));
        fromY += value;
      }

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: fromY,
            width: barWidth,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            color: TecneroTheme.azulOscuro.withValues(alpha: 0.08),
            rodStackItems: stacks,
          ),
        ],
      );
    });
  }

  List<MapEntry<String, double>> _resumenPorLinea(List<dynamic> data) {
    final totals = <String, double>{};
    for (final raw in data) {
      final row = _map(raw);
      final linea = _str(row, 'linea_nombre', alt: 'lineaNombre').isEmpty
          ? 'Sin línea'
          : _str(row, 'linea_nombre', alt: 'lineaNombre');
      totals[linea] = (totals[linea] ?? 0) + _num(row, 'costo_total');
    }
    return totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }

  List<MapEntry<String, List<MapEntry<String, double>>>> _detallesPorDia(
      List<dynamic> data) {
    final matriz = _matrizPorDiaLinea(data);
    final dias = matriz.keys.toList()..sort((a, b) => b.compareTo(a));

    return dias.map((dia) {
      final lineas = matriz[dia]!.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return MapEntry(dia, lineas);
    }).toList();
  }
}

class _LineLegend extends StatelessWidget {
  final List<String> lineas;
  final List<MapEntry<String, double>> totals;
  final NumberFormat fmtMoney;

  const _LineLegend({
    required this.lineas,
    required this.totals,
    required this.fmtMoney,
  });

  @override
  Widget build(BuildContext context) {
    final totalMap = {for (final e in totals) e.key: e.value};

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(lineas.length, (index) {
        final color = _lineaColor(index);
        final linea = lineas[index];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 10,
                  height: 10,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(
                '$linea: ${fmtMoney.format(totalMap[linea] ?? 0)}',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w800, color: color),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _DetalleDiaLinea extends StatelessWidget {
  final List<MapEntry<String, List<MapEntry<String, double>>>> detalles;
  final NumberFormat fmtMoney;

  const _DetalleDiaLinea({required this.detalles, required this.fmtMoney});

  @override
  Widget build(BuildContext context) {
    if (detalles.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: detalles.take(7).map((entry) {
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: TecneroTheme.grisBorde),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _diaCorto(entry.key),
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: TecneroTheme.azulOscuro),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: entry.value.asMap().entries.map((entryLinea) {
                  final index = entryLinea.key;
                  final linea = entryLinea.value;
                  final color = _lineaColor(index);
                  return _ChartChip(
                      label: linea.key,
                      value: fmtMoney.format(linea.value),
                      color: color);
                }).toList(),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _ChartChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ChartChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
            fontSize: 10.5, color: color, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _LineasCostoPanel extends StatelessWidget {
  final List<dynamic> porLinea;
  final NumberFormat fmtMoney;
  final NumberFormat fmtMoneyShort;

  const _LineasCostoPanel({
    required this.porLinea,
    required this.fmtMoney,
    required this.fmtMoneyShort,
  });

  @override
  Widget build(BuildContext context) {
    final rows = porLinea.map((raw) => _map(raw)).toList()
      ..sort(
          (a, b) => _num(b, 'costo_total').compareTo(_num(a, 'costo_total')));

    final double total = rows.fold<double>(
      0.0,
      (sum, row) => sum + _num(row, 'costo_total'),
    );

    final double maxCosto = rows.fold<double>(0.0, (max, row) {
      final double costo = _num(row, 'costo_total');
      return costo > max ? costo : max;
    });

    return Column(
      children: rows.asMap().entries.map((entry) {
        final index = entry.key;
        final row = entry.value;

        final nombre = _str(row, 'linea_nombre', alt: 'lineaNombre').isEmpty
            ? 'Sin línea'
            : _str(row, 'linea_nombre', alt: 'lineaNombre');

        final double costo = _num(row, 'costo_total');
        final double solicitudes = _num(row, 'total_solicitudes');

        final double pct = total > 0 ? ((costo / total) * 100) : 0.0;

        final double progress =
            maxCosto > 0 ? (costo / maxCosto).clamp(0.0, 1.0).toDouble() : 0.0;

        final color = _lineaColor(index);

        return Container(
          margin: const EdgeInsets.only(bottom: 13),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      nombre,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${fmtMoney.format(costo)} · ${pct.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 9,
                  backgroundColor: const Color(0xFFF1F5F9),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${solicitudes.toInt()} solicitudes · Referencia: ${fmtMoneyShort.format(costo)}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: TecneroTheme.textoSecundario,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _CostInsightPanel extends StatelessWidget {
  final double gastoTotal;
  final double promedioSolicitud;
  final double entregadas;
  final _LineaResumen? lineaMasCara;
  final _MaterialResumen? materialMasCaro;
  final NumberFormat fmtMoney;

  const _CostInsightPanel({
    required this.gastoTotal,
    required this.promedioSolicitud,
    required this.entregadas,
    required this.lineaMasCara,
    required this.materialMasCaro,
    required this.fmtMoney,
  });

  @override
  Widget build(BuildContext context) {
    final costoPorEntrega = entregadas > 0 ? gastoTotal / entregadas : 0;
    final participacionLinea = gastoTotal > 0 && lineaMasCara != null
        ? (lineaMasCara!.costo / gastoTotal) * 100
        : 0.0;
    final participacionMaterial = gastoTotal > 0 && materialMasCaro != null
        ? (materialMasCaro!.costo / gastoTotal) * 100
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InsightItem(
          icon: Icons.factory_outlined,
          title: 'Línea con mayor costo',
          value: lineaMasCara == null
              ? 'Sin datos'
              : '${lineaMasCara!.nombre}\n${fmtMoney.format(lineaMasCara!.costo)} · ${participacionLinea.toStringAsFixed(1)}% del gasto',
          color: const Color(0xFF2563EB),
        ),
        _InsightItem(
          icon: Icons.inventory_outlined,
          title: 'Material con mayor peso',
          value: materialMasCaro == null
              ? 'Sin datos'
              : '${materialMasCaro!.nombre}\n${fmtMoney.format(materialMasCaro!.costo)} · ${participacionMaterial.toStringAsFixed(1)}% del gasto',
          color: const Color(0xFFDC2626),
        ),
        _InsightItem(
          icon: Icons.price_check_outlined,
          title: 'Costo promedio por despacho',
          value: '${fmtMoney.format(costoPorEntrega)} por entrega cerrada',
          color: const Color(0xFF059669),
        ),
        const _InsightItem(
          icon: Icons.calculate_outlined,
          title: 'Cálculo de costo unitario',
          value:
              'Usa la calculadora con el gasto filtrado, unidades producidas, mano de obra y gastos adicionales.',
          color: TecneroTheme.naranja,
        ),
      ],
    );
  }
}

class _InsightItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _InsightItem({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                      fontSize: 11, color: color, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    color: TecneroTheme.textoPrimario,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
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

enum _TipoTablaMaterial { costo, cantidad }

class _TablaMaterialesCriticos extends StatelessWidget {
  final List<dynamic> data;
  final _TipoTablaMaterial tipo;
  final NumberFormat fmt;

  const _TablaMaterialesCriticos({
    required this.data,
    required this.tipo,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final rows = data.map((raw) => _map(raw)).toList();

    final double maxValue = rows.fold<double>(0.0, (max, row) {
      final double value = tipo == _TipoTablaMaterial.costo
          ? _num(row, 'costo_total')
          : _num(row, 'cantidad_total');
      return value > max ? value : max;
    });

    return Column(
      children: rows.asMap().entries.map((entry) {
        final index = entry.key;
        final row = entry.value;
        return _MaterialCriticoCard(
          row: row,
          index: index,
          tipo: tipo,
          fmt: fmt,
          maxValue: maxValue,
        );
      }).toList(),
    );
  }
}

class _MaterialCriticoCard extends StatefulWidget {
  final Map<String, dynamic> row;
  final int index;
  final _TipoTablaMaterial tipo;
  final NumberFormat fmt;
  final double maxValue;

  const _MaterialCriticoCard({
    required this.row,
    required this.index,
    required this.tipo,
    required this.fmt,
    required this.maxValue,
  });

  @override
  State<_MaterialCriticoCard> createState() => _MaterialCriticoCardState();
}

class _MaterialCriticoCardState extends State<_MaterialCriticoCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final codigo = _str(row, 'codigo', alt: 'material_codigo');
    final material = _str(row, 'material_nombre', alt: 'nombre').isEmpty
        ? _str(row, 'nombre')
        : _str(row, 'material_nombre', alt: 'nombre');

    final double cantidad = _num(row, 'cantidad_total');
    final unidad = _str(row, 'unidad_medida', alt: 'unidadMedida');
    final double costo = _num(row, 'costo_total');

    final double value =
        widget.tipo == _TipoTablaMaterial.costo ? costo : cantidad;

    final double pct = widget.maxValue > 0
        ? (value / widget.maxValue).clamp(0.0, 1.0).toDouble()
        : 0.0;

    final color = _lineaColor(widget.index);
    final lineas = _lineasDelMaterial(row);
    final titulo = codigo.isEmpty ? material : '$codigo · $material';

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: TecneroTheme.grisBorde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          titulo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.tipo == _TipoTablaMaterial.costo
                            ? widget.fmt.format(costo)
                            : '${_formatCantidad(cantidad)} $unidad',
                        style: TextStyle(
                          fontSize: 12,
                          color: color,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up_outlined
                            : Icons.keyboard_arrow_down_outlined,
                        size: 20,
                        color: TecneroTheme.azulOscuro,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 7,
                      backgroundColor: Colors.white,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Cantidad total: ${_formatCantidad(cantidad)} $unidad · Costo total: ${widget.fmt.format(costo)}',
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: TecneroTheme.textoSecundario,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _DetalleLineasMaterial(
              lineas: lineas,
              costoTotal: costo,
              cantidadTotal: cantidad,
              unidad: unidad,
              fmt: widget.fmt,
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _lineasDelMaterial(Map<String, dynamic> row) {
    final raw = row['lineas'] ??
        row['detalle_lineas'] ??
        row['lineas_produccion'] ??
        row['por_linea'];

    if (raw is List) {
      return raw.map((e) => _map(e)).where((e) => e.isNotEmpty).toList();
    }

    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded
              .map((e) => _map(e))
              .where((e) => e.isNotEmpty)
              .toList();
        }
      } catch (_) {
        return const [];
      }
    }

    return const [];
  }
}

class _DetalleLineasMaterial extends StatelessWidget {
  final List<Map<String, dynamic>> lineas;
  final double costoTotal;
  final double cantidadTotal;
  final String unidad;
  final NumberFormat fmt;

  const _DetalleLineasMaterial({
    required this.lineas,
    required this.costoTotal,
    required this.cantidadTotal,
    required this.unidad,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    if (lineas.isEmpty) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: TecneroTheme.grisBorde),
        ),
        child: const Text(
          'No llegó el detalle por línea desde el backend. Reinicia el backend y confirma que top_materiales tenga el campo lineas.',
          style: TextStyle(
            fontSize: 11,
            color: TecneroTheme.textoSecundario,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final ordenadas = lineas.toList()
      ..sort(
          (a, b) => _num(b, 'costo_total').compareTo(_num(a, 'costo_total')));

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: TecneroTheme.grisBorde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Detalle por línea de producción',
            style: const TextStyle(
              fontSize: 11,
              color: TecneroTheme.azulOscuro,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          ...ordenadas.asMap().entries.map((entry) {
            final index = entry.key;
            final linea = entry.value;
            final color = _lineaColor(index);
            final lineaNombre =
                _str(linea, 'linea_nombre', alt: 'lineaNombre').isEmpty
                    ? 'Sin línea'
                    : _str(linea, 'linea_nombre', alt: 'lineaNombre');
            final lineaCantidad = _num(linea, 'cantidad_total');
            final lineaCosto = _num(linea, 'costo_total');
            final pctCosto =
                costoTotal > 0 ? (lineaCosto / costoTotal) * 100 : 0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 420;

                  final left = Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          lineaNombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                            color: TecneroTheme.textoPrimario,
                          ),
                        ),
                      ),
                    ],
                  );

                  final right = Column(
                    crossAxisAlignment: compact
                        ? CrossAxisAlignment.start
                        : CrossAxisAlignment.end,
                    children: [
                      Text(
                        fmt.format(lineaCosto),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: color,
                        ),
                      ),
                      Text(
                        '${_formatCantidad(lineaCantidad)} $unidad · ${pctCosto.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 10,
                          color: TecneroTheme.textoSecundario,
                        ),
                      ),
                    ],
                  );

                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        left,
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.only(left: 18),
                          child: right,
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: left),
                      const SizedBox(width: 8),
                      right,
                    ],
                  );
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _TablaPreciosMateriales extends StatelessWidget {
  final List<dynamic> data;
  final List<dynamic> cambiosPrecio;
  final NumberFormat fmt;

  const _TablaPreciosMateriales({
    required this.data,
    required this.cambiosPrecio,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final rows = data.map((raw) => _map(raw)).toList();
    final cambiosPorCodigo = <String, Map<String, dynamic>>{};

    for (final raw in cambiosPrecio) {
      final cambio = _map(raw);
      final codigo = _str(cambio, 'codigo');
      if (codigo.isNotEmpty) cambiosPorCodigo[codigo] = cambio;
    }

    return Column(
      children: rows.map((row) {
        final codigo = _str(row, 'codigo', alt: 'material_codigo');
        final material = _str(row, 'material_nombre', alt: 'nombre').isEmpty
            ? _str(row, 'nombre')
            : _str(row, 'material_nombre', alt: 'nombre');
        final cantidad = _num(row, 'cantidad_total');
        final unidad = _str(row, 'unidad_medida', alt: 'unidadMedida');
        final costo = _num(row, 'costo_total');
        final precioPromedio = cantidad > 0 ? costo / cantidad : 0.0;
        final cambioPrecio = cambiosPorCodigo[codigo];
        final precioMinUsado = _num(row, 'precio_min_usado');
        final precioMaxUsado = _num(row, 'precio_max_usado');
        final preciosUsados = _num(row, 'precios_usados').toInt();

        return Container(
          margin: const EdgeInsets.only(bottom: 9),
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: TecneroTheme.grisBorde),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 560;
              final title = codigo.isEmpty ? material : '$codigo · $material';

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (cambioPrecio != null) ...[
                      const SizedBox(height: 6),
                      _CambioPrecioBadge(cambio: cambioPrecio),
                    ],
                    if (precioMaxUsado > 0) ...[
                      const SizedBox(height: 6),
                      _PrecioUsadoBadge(
                        precioMin: precioMinUsado,
                        precioMax: precioMaxUsado,
                        preciosUsados: preciosUsados,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _MiniStat(
                          label: 'Precio prom.',
                          value: fmt.format(precioPromedio),
                          color: TecneroTheme.naranja,
                        ),
                        _MiniStat(
                          label: 'Consumido',
                          value: '${_formatCantidad(cantidad)} $unidad',
                          color: const Color(0xFF2563EB),
                        ),
                        _MiniStat(
                          label: 'Total',
                          value: fmt.format(costo),
                          color: const Color(0xFF059669),
                        ),
                      ],
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (cambioPrecio != null) ...[
                          const SizedBox(height: 6),
                          _CambioPrecioBadge(cambio: cambioPrecio),
                        ],
                        if (precioMaxUsado > 0) ...[
                          const SizedBox(height: 6),
                          _PrecioUsadoBadge(
                            precioMin: precioMinUsado,
                            precioMax: precioMaxUsado,
                            preciosUsados: preciosUsados,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: _InlineValue(
                      label: 'Precio prom.',
                      value: fmt.format(precioPromedio),
                      color: TecneroTheme.naranja,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: _InlineValue(
                      label: 'Cantidad',
                      value: '${_formatCantidad(cantidad)} $unidad',
                      color: const Color(0xFF2563EB),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: _InlineValue(
                      label: 'Costo',
                      value: fmt.format(costo),
                      color: const Color(0xFF059669),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      }).toList(),
    );
  }
}

class _CambioPrecioBadge extends StatelessWidget {
  final Map<String, dynamic> cambio;

  const _CambioPrecioBadge({required this.cambio});

  @override
  Widget build(BuildContext context) {
    final anterior = _num(cambio, 'precio_anterior');
    final actual = _num(cambio, 'precio_actual');
    final variacion = _num(cambio, 'variacion_pct');
    final subio = variacion > 0;
    final color = subio ? const Color(0xFFDC2626) : const Color(0xFF059669);
    final label = subio ? 'VIGENTE SUBIÓ' : 'VIGENTE BAJÓ';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        '$label ${variacion.abs().toStringAsFixed(1)}% · ${anterior.toStringAsFixed(2)} -> ${actual.toStringAsFixed(2)}',
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _PrecioUsadoBadge extends StatelessWidget {
  final double precioMin;
  final double precioMax;
  final int preciosUsados;

  const _PrecioUsadoBadge({
    required this.precioMin,
    required this.precioMax,
    required this.preciosUsados,
  });

  @override
  Widget build(BuildContext context) {
    final mezclado =
        preciosUsados > 1 && (precioMax - precioMin).abs() > 0.0001;
    final color = mezclado ? TecneroTheme.naranja : TecneroTheme.azulOscuro;
    final texto = mezclado
        ? 'FIFO MEZCLÓ $preciosUsados PRECIOS · ${precioMin.toStringAsFixed(2)} - ${precioMax.toStringAsFixed(2)}'
        : 'FIFO USÓ LOTE A ${precioMax.toStringAsFixed(2)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _TablaVariacionPrecios extends StatelessWidget {
  final List<dynamic> data;
  final NumberFormat fmt;

  const _TablaVariacionPrecios({
    required this.data,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final rows = data.map((raw) => _map(raw)).toList();

    return Column(
      children: rows.map((row) {
        final codigo = _str(row, 'codigo');
        final material = _str(row, 'material_nombre', alt: 'nombre');
        final anterior = _num(row, 'precio_anterior');
        final actual = _num(row, 'precio_actual');
        final variacion = _num(row, 'variacion_pct');
        final subio = variacion >= 0;
        final color = subio ? const Color(0xFFDC2626) : const Color(0xFF059669);
        final icon =
            subio ? Icons.trending_up_outlined : Icons.trending_down_outlined;

        return Container(
          margin: const EdgeInsets.only(bottom: 9),
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.18)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      codigo.isEmpty ? material : '$codigo · $material',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${fmt.format(anterior)} -> ${fmt.format(actual)}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: TecneroTheme.textoSecundario,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${subio ? '+' : ''}${variacion.toStringAsFixed(1)}%',
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

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool highlight;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: highlight
            ? TecneroTheme.naranja.withValues(alpha: 0.15)
            : color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(9),
        border: highlight
            ? Border.all(color: TecneroTheme.naranja, width: 1.5)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: highlight ? TecneroTheme.naranja : color,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color:
                  highlight ? TecneroTheme.naranja : TecneroTheme.textoPrimario,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineValue extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool highlight;

  const _InlineValue({
    required this.label,
    required this.value,
    required this.color,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color:
                highlight ? TecneroTheme.naranja : TecneroTheme.textoSecundario,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            color: highlight ? TecneroTheme.naranja : color,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _TablaGastoPorDia extends StatelessWidget {
  final List<dynamic> data;
  final NumberFormat fmt;

  const _TablaGastoPorDia({required this.data, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final rows = data.map((raw) => _map(raw)).toList()
      ..sort((a, b) => _str(b, 'dia').compareTo(_str(a, 'dia')));

    return Column(
      children: rows.take(10).map((row) {
        return _SimpleDataRow(
          title: _diaCorto(_str(row, 'dia')),
          subtitle:
              '${_num(row, 'total_solicitudes').toInt()} solicitudes entregadas',
          trailing: fmt.format(_num(row, 'costo_total')),
          icon: Icons.calendar_today_outlined,
          color: TecneroTheme.azulOscuro,
        );
      }).toList(),
    );
  }
}

class _TablaUltimasSolicitudes extends StatelessWidget {
  final List<dynamic> data;
  final NumberFormat fmt;

  const _TablaUltimasSolicitudes({required this.data, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final rows = data.take(8).map((raw) => _map(raw)).toList();

    return Column(
      children: rows.map((row) {
        final numero = _str(row, 'numero');
        final linea = _str(row, 'linea_nombre', alt: 'lineaNombre');
        final estado = _str(row, 'estado');
        final costo = _num(row, 'costo_total');

        return _SimpleDataRow(
          title: numero.isEmpty ? 'Solicitud' : numero,
          subtitle:
              '${linea.isEmpty ? 'Sin línea' : linea} · ${estado.toUpperCase()}',
          trailing: fmt.format(costo),
          icon: Icons.receipt_long_outlined,
          color: _estadoColor(estado),
        );
      }).toList(),
    );
  }
}

class _SimpleDataRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final String trailing;
  final IconData icon;
  final Color color;

  const _SimpleDataRow({
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: TecneroTheme.grisBorde),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w900),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 10.5, color: TecneroTheme.textoSecundario),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            trailing,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w900, color: color),
          ),
        ],
      ),
    );
  }
}

class _TablaCostoUnitarioProduccion extends StatelessWidget {
  final List<dynamic> data;
  final NumberFormat fmtMoney;

  const _TablaCostoUnitarioProduccion({
    required this.data,
    required this.fmtMoney,
  });

  @override
  Widget build(BuildContext context) {
    final rows = _agruparPorLinea(data);

    return Column(
      children: rows.map((row) {
        final lineas = _fechasDelGrupo(row);
        final fechasTexto = lineas.isEmpty
            ? 'Sin fechas'
            : lineas.map(_diaCorto).join(' · ');
        final linea = _str(row, 'linea_nombre', alt: 'lineaNombre');
        final unidad = _str(row, 'unidad');
        final cantidad = _num(row, 'cantidad_producida');
        final costoMateriales = _num(row, 'costo_materiales');
        final costoUnitario =
            cantidad > 0 ? costoMateriales / cantidad : 0.0;
        final despachos = _num(row, 'despachos').toInt();

        return _ProduccionUnitarioCard(
          fechas: fechasTexto,
          linea: linea,
          unidad: unidad,
          cantidad: cantidad,
          costoMateriales: costoMateriales,
          costoUnitario: costoUnitario,
          despachos: despachos,
          fmtMoney: fmtMoney,
        );
      }).toList(),
    );
  }

  List<Map<String, dynamic>> _agruparPorLinea(List<dynamic> rawData) {
    final grupos = <String, Map<String, dynamic>>{};

    for (final raw in rawData) {
      final row = _map(raw);
      final lineaId = _str(row, 'linea_id');
      final lineaNombre = _str(row, 'linea_nombre', alt: 'lineaNombre');
      final unidad = _str(row, 'unidad');
      final key = '$lineaId|$lineaNombre|$unidad';

      final grupo = grupos.putIfAbsent(key, () {
        return <String, dynamic>{
          'linea_id': lineaId,
          'linea_nombre': lineaNombre,
          'unidad': unidad,
          'cantidad_producida': 0.0,
          'costo_materiales': 0.0,
          'despachos': 0,
          'fechas': <String>[],
        };
      });

      grupo['cantidad_producida'] =
          _num(grupo, 'cantidad_producida') + _num(row, 'cantidad_producida');
      grupo['costo_materiales'] =
          _num(grupo, 'costo_materiales') + _num(row, 'costo_materiales');
      grupo['despachos'] =
          _num(grupo, 'despachos').toInt() + _num(row, 'despachos').toInt();

      final fechas = List<String>.from(grupo['fechas'] as List);
      for (final fecha in _fechasDelGrupo(row)) {
        if (fecha.isNotEmpty && !fechas.contains(fecha)) {
          fechas.add(fecha);
        }
      }
      fechas.sort((a, b) => b.compareTo(a));
      grupo['fechas'] = fechas;
    }

    final rows = grupos.values.toList()
      ..sort((a, b) {
        final fechaA = _fechaGrupoMasReciente(a);
        final fechaB = _fechaGrupoMasReciente(b);
        final cmpFecha = fechaB.compareTo(fechaA);
        if (cmpFecha != 0) return cmpFecha;

        return _str(a, 'linea_nombre')
            .toLowerCase()
            .compareTo(_str(b, 'linea_nombre').toLowerCase());
      });

    return rows;
  }

  List<String> _fechasDelGrupo(Map<String, dynamic> row) {
    final raw = row['fechas'];
    if (raw is List) {
      return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded
              .map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toList();
        }
      } catch (_) {
        return [raw];
      }
    }
    return const [];
  }

  DateTime _fechaGrupoMasReciente(Map<String, dynamic> row) {
    final fechas = _fechasDelGrupo(row);
    if (fechas.isEmpty) return DateTime.fromMillisecondsSinceEpoch(0);

    final parsed = fechas
        .map((dia) => DateTime.tryParse(dia) ?? DateTime.fromMillisecondsSinceEpoch(0))
        .toList()
      ..sort((a, b) => b.compareTo(a));

    return parsed.first;
  }
}

class _ProduccionPendienteNotice extends StatelessWidget {
  final VoidCallback onAbrirProduccion;

  const _ProduccionPendienteNotice({
    required this.onAbrirProduccion,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF6E8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF7C948)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          const SizedBox(
            width: 520,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Falta registrar producción para este filtro',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: TecneroTheme.azulOscuro,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Si tienes la cantidad producida, regístrala en Producción para calcular el costo unitario real. Si todavía no la tienes, puedes dejarla pendiente y volver más tarde.',
                  style: TextStyle(
                    fontSize: 12,
                    color: TecneroTheme.textoSecundario,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: onAbrirProduccion,
            icon: const Icon(Icons.add_chart_outlined, size: 18),
            label: const Text('Ir a Producción'),
            style: ElevatedButton.styleFrom(
              backgroundColor: TecneroTheme.azulOscuro,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProduccionUnitarioCard extends StatefulWidget {
  final String fechas;
  final String linea;
  final String unidad;
  final double cantidad;
  final double costoMateriales;
  final double costoUnitario;
  final int despachos;
  final NumberFormat fmtMoney;

  const _ProduccionUnitarioCard({
    required this.fechas,
    required this.linea,
    required this.unidad,
    required this.cantidad,
    required this.costoMateriales,
    required this.costoUnitario,
    required this.despachos,
    required this.fmtMoney,
  });

  @override
  State<_ProduccionUnitarioCard> createState() =>
      _ProduccionUnitarioCardState();
}

class _ProduccionUnitarioCardState extends State<_ProduccionUnitarioCard> {
  late TextEditingController _cantidadCtrl;
  late double _cantidadEditada;
  late double _costoUnitarioCalculado;

  @override
  void initState() {
    super.initState();
    _cantidadEditada = widget.cantidad;
    _costoUnitarioCalculado = widget.costoUnitario;
    _cantidadCtrl =
        TextEditingController(text: _formatCantidad(_cantidadEditada));
    _cantidadCtrl.addListener(_recalcularCostoUnitario);
  }

  @override
  void dispose() {
    _cantidadCtrl.removeListener(_recalcularCostoUnitario);
    _cantidadCtrl.dispose();
    super.dispose();
  }

  void _recalcularCostoUnitario() {
    final nuevaCantidad =
        double.tryParse(_cantidadCtrl.text.replaceAll(',', '.')) ?? 0;
    setState(() {
      _cantidadEditada = nuevaCantidad;
      _costoUnitarioCalculado =
          nuevaCantidad > 0 ? widget.costoMateriales / nuevaCantidad : 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.linea.isEmpty ? 'Sin linea' : widget.linea;
    final subtitulo = widget.fechas.isEmpty
        ? 'Sin fechas registradas'
        : 'Fechas: ${widget.fechas}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TecneroTheme.grisBorde),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _UnitIcon(color: TecneroTheme.naranja),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: TecneroTheme.azulOscuro,
                            ),
                          ),
                          Text(
                            '$subtitulo · ${widget.despachos} despachos',
                            style: const TextStyle(
                              fontSize: 11,
                              color: TecneroTheme.textoSecundario,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _CantidadEditadaField(
                  controller: _cantidadCtrl,
                  unidad: widget.unidad,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MiniStat(
                      label: 'Materiales',
                      value: widget.fmtMoney.format(widget.costoMateriales),
                      color: const Color(0xFF059669),
                    ),
                    _MiniStat(
                      label: 'Costo unit.',
                      value: widget.fmtMoney.format(_costoUnitarioCalculado),
                      color: TecneroTheme.naranja,
                      highlight: _cantidadEditada != widget.cantidad,
                    ),
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              _UnitIcon(color: TecneroTheme.naranja),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: TecneroTheme.azulOscuro,
                      ),
                    ),
                    Text(
                      '$subtitulo · ${widget.despachos} despachos cerrados',
                      style: const TextStyle(
                        fontSize: 11,
                        color: TecneroTheme.textoSecundario,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: _CantidadEditadaField(
                  controller: _cantidadCtrl,
                  unidad: widget.unidad,
                ),
              ),
              Expanded(
                flex: 2,
                child: _InlineValue(
                  label: 'Materiales',
                  value: widget.fmtMoney.format(widget.costoMateriales),
                  color: const Color(0xFF059669),
                ),
              ),
              Expanded(
                flex: 2,
                child: _InlineValue(
                  label: 'Costo unit.',
                  value: widget.fmtMoney.format(_costoUnitarioCalculado),
                  color: TecneroTheme.naranja,
                  highlight: _cantidadEditada != widget.cantidad,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CantidadEditadaField extends StatelessWidget {
  final TextEditingController controller;
  final String unidad;

  const _CantidadEditadaField({
    required this.controller,
    required this.unidad,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Producción (editable)',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: TecneroTheme.textoSecundario,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            suffixText: unidad,
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: TecneroTheme.grisBorde),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: TecneroTheme.grisBorde),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: TecneroTheme.naranja),
            ),
          ),
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}

class _UnitIcon extends StatelessWidget {
  final Color color;

  const _UnitIcon({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        Icons.precision_manufacturing_outlined,
        color: color,
        size: 20,
      ),
    );
  }
}

class _ResponsiveTwoColumn extends StatelessWidget {
  final Widget left;
  final Widget right;
  final int leftFlex;
  final int rightFlex;

  const _ResponsiveTwoColumn({
    required this.left,
    required this.right,
    this.leftFlex = 1,
    this.rightFlex = 1,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final isCompact = constraints.maxWidth < 1120;

        if (isCompact) {
          return Column(
            children: [
              SizedBox(width: double.infinity, child: left),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: right),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: leftFlex, child: left),
            const SizedBox(width: 16),
            Expanded(flex: rightFlex, child: right),
          ],
        );
      },
    );
  }
}

class _CalculadoraCostosDialog extends StatefulWidget {
  final double gastoMaterialesInicial;
  final NumberFormat fmtMoney;

  const _CalculadoraCostosDialog({
    required this.gastoMaterialesInicial,
    required this.fmtMoney,
  });

  @override
  State<_CalculadoraCostosDialog> createState() =>
      _CalculadoraCostosDialogState();
}

class _CalculadoraCostosDialogState extends State<_CalculadoraCostosDialog> {
  late final TextEditingController _materialesCtrl;

  final _unidadesCtrl = TextEditingController(text: '100');
  final _manoObraCtrl = TextEditingController(text: '0');
  final _energiaCtrl = TextEditingController(text: '0');
  final _otrosCtrl = TextEditingController(text: '0');

  double _parse(TextEditingController c) {
    final value = c.text.trim().replaceAll(',', '.');
    return double.tryParse(value) ?? 0;
  }

  @override
  void initState() {
    super.initState();
    _materialesCtrl = TextEditingController(
      text: widget.gastoMaterialesInicial.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _materialesCtrl.dispose();
    _unidadesCtrl.dispose();
    _manoObraCtrl.dispose();
    _energiaCtrl.dispose();
    _otrosCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    final materiales = _parse(_materialesCtrl);
    final unidades = _parse(_unidadesCtrl);
    final manoObra = _parse(_manoObraCtrl);
    final energia = _parse(_energiaCtrl);
    final otros = _parse(_otrosCtrl);

    final costoTotal = materiales + manoObra + energia + otros;
    final costoUnitario = unidades > 0 ? costoTotal / unidades : 0.0;

    final porcentajeMateriales =
        costoTotal > 0 ? (materiales / costoTotal) * 100 : 0.0;

    final porcentajeManoObra =
        costoTotal > 0 ? (manoObra / costoTotal) * 100 : 0.0;

    final porcentajeEnergia =
        costoTotal > 0 ? (energia / costoTotal) * 100 : 0.0;

    final porcentajeOtros = costoTotal > 0 ? (otros / costoTotal) * 100 : 0.0;

    return Dialog(
      insetPadding: EdgeInsets.all(isMobile ? 10 : 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CalculatorHeader(
                onClose: () => Navigator.pop(context),
              ),
              const SizedBox(height: 18),
              _CalculatorNotice(
                costoMateriales: widget.fmtMoney.format(materiales),
              ),
              const SizedBox(height: 18),
              const _CalculatorSectionTitle(
                icon: Icons.inventory_2_outlined,
                title: 'Datos para calcular el costo',
                subtitle:
                    'Ingresa unidades producidas y gastos adicionales para obtener el costo real por unidad.',
              ),
              const SizedBox(height: 12),
              _ResponsiveFieldsRow(
                children: [
                  _CalcField(
                    label: 'Costo de materiales',
                    controller: _materialesCtrl,
                    prefix: '\$',
                    onChanged: () => setState(() {}),
                  ),
                  _CalcField(
                    label: 'Unidades producidas',
                    controller: _unidadesCtrl,
                    prefix: '',
                    onChanged: () => setState(() {}),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _ResponsiveFieldsRow(
                children: [
                  _CalcField(
                    label: 'Mano de obra',
                    controller: _manoObraCtrl,
                    prefix: '\$',
                    onChanged: () => setState(() {}),
                  ),
                  _CalcField(
                    label: 'Energía / servicios',
                    controller: _energiaCtrl,
                    prefix: '\$',
                    onChanged: () => setState(() {}),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _CalcField(
                label: 'Otros gastos',
                controller: _otrosCtrl,
                prefix: '\$',
                helper:
                    'Ejemplo: transporte, mantenimiento, empaque, reproceso o gastos indirectos.',
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 22),
              _ResponsiveResultGrid(
                children: [
                  _ResultBox(
                    label: 'Costo total',
                    value: widget.fmtMoney.format(costoTotal),
                    color: TecneroTheme.azulOscuro,
                  ),
                  _ResultBox(
                    label: 'Costo por unidad',
                    value: widget.fmtMoney.format(costoUnitario),
                    color: TecneroTheme.naranja,
                  ),
                  _ResultBox(
                    label: 'Materiales',
                    value: '${porcentajeMateriales.toStringAsFixed(1)}%',
                    color: const Color(0xFF2563EB),
                  ),
                  _ResultBox(
                    label: 'Mano de obra',
                    value: '${porcentajeManoObra.toStringAsFixed(1)}%',
                    color: const Color(0xFF059669),
                  ),
                  _ResultBox(
                    label: 'Energía / servicios',
                    value: '${porcentajeEnergia.toStringAsFixed(1)}%',
                    color: const Color(0xFF0891B2),
                  ),
                  _ResultBox(
                    label: 'Otros gastos',
                    value: '${porcentajeOtros.toStringAsFixed(1)}%',
                    color: const Color(0xFF7C3AED),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _CalculatorVerdict(
                ok: unidades > 0,
                text: unidades > 0
                    ? 'Con ${_formatCantidad(unidades)} unidades producidas, el costo estimado por unidad es ${widget.fmtMoney.format(costoUnitario)}.'
                    : 'Ingresa una cantidad válida de unidades producidas para calcular el costo unitario.',
              ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.check_outlined, size: 18),
                  label: const Text('Entendido'),
                  style: FilledButton.styleFrom(
                    backgroundColor: TecneroTheme.azulOscuro,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalculatorHeader extends StatelessWidget {
  final VoidCallback onClose;

  const _CalculatorHeader({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: TecneroTheme.naranja.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.calculate_outlined,
            color: TecneroTheme.naranja,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Calculadora de costo unitario',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: TecneroTheme.textoPrimario,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Calcula cuánto cuesta producir cada unidad según materiales, mano de obra y gastos del periodo.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.25,
                  color: TecneroTheme.textoSecundario,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onClose,
          icon: const Icon(Icons.close),
          tooltip: 'Cerrar',
        ),
      ],
    );
  }
}

class _CalculatorNotice extends StatelessWidget {
  final String costoMateriales;

  const _CalculatorNotice({required this.costoMateriales});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline,
            color: Color(0xFF2563EB),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Se cargó automáticamente el costo de materiales del periodo: $costoMateriales. Puedes modificarlo para simular otro escenario.',
              style: const TextStyle(
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w700,
                color: TecneroTheme.azulOscuro,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalculatorSectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _CalculatorSectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: TecneroTheme.azulOscuro),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: TecneroTheme.textoPrimario,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: TecneroTheme.textoSecundario,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ResponsiveFieldsRow extends StatelessWidget {
  final List<Widget> children;

  const _ResponsiveFieldsRow({required this.children});

  @override
  Widget build(BuildContext context) {
    if (Responsive.isMobile(context)) {
      return Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) const SizedBox(height: 12),
          ],
        ],
      );
    }

    return Row(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          Expanded(child: children[i]),
          if (i != children.length - 1) const SizedBox(width: 12),
        ],
      ],
    );
  }
}

class _CalcField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String prefix;
  final String? helper;
  final VoidCallback onChanged;

  const _CalcField({
    required this.label,
    required this.controller,
    required this.prefix,
    this.helper,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        helperMaxLines: 2,
        prefixText: prefix.isEmpty ? null : '$prefix ',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

class _ResponsiveResultGrid extends StatelessWidget {
  final List<Widget> children;

  const _ResponsiveResultGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    if (Responsive.isMobile(context)) {
      return Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) const SizedBox(height: 12),
          ],
        ],
      );
    }

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.45,
      children: children,
    );
  }
}

class _CalculatorVerdict extends StatelessWidget {
  final bool ok;
  final String text;

  const _CalculatorVerdict({
    required this.ok,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final color = ok ? const Color(0xFF059669) : const Color(0xFFDC2626);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ok ? Icons.check_circle_outline : Icons.warning_amber_outlined,
            color: color,
            size: 19,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ResultBox(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TecneroTheme.grisBorde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: TecneroTheme.textoSecundario)),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w900, color: color),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String msg;

  const _EmptyState({required this.msg});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          msg,
          style: const TextStyle(
              color: TecneroTheme.textoSecundario, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _ErrorWidget extends StatelessWidget {
  final String message;

  const _ErrorWidget({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Text('Error: $message',
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center),
      ),
    );
  }
}

class _LineaResumen {
  final String nombre;
  final double costo;

  const _LineaResumen(this.nombre, this.costo);
}

class _MaterialResumen {
  final String nombre;
  final double costo;

  const _MaterialResumen(this.nombre, this.costo);
}

class _TendenciaGasto {
  final double anterior;
  final double actual;
  final double variacion;

  const _TendenciaGasto({
    required this.anterior,
    required this.actual,
    required this.variacion,
  });

  String get formatoVariacion {
    final sign = variacion > 0 ? '+' : '';
    return '$sign${variacion.toStringAsFixed(1)}%';
  }
}

_LineaResumen? _lineaMasCara(List<dynamic> porLinea) {
  if (porLinea.isEmpty) return null;
  final rows = porLinea.map((e) => _map(e)).toList()
    ..sort((a, b) => _num(b, 'costo_total').compareTo(_num(a, 'costo_total')));
  final row = rows.first;
  final nombre = _str(row, 'linea_nombre', alt: 'lineaNombre').isEmpty
      ? 'Sin línea'
      : _str(row, 'linea_nombre', alt: 'lineaNombre');
  return _LineaResumen(nombre, _num(row, 'costo_total'));
}

_MaterialResumen? _materialMasCaro(List<dynamic> topCosto) {
  if (topCosto.isEmpty) return null;
  final rows = topCosto.map((e) => _map(e)).toList()
    ..sort((a, b) => _num(b, 'costo_total').compareTo(_num(a, 'costo_total')));
  final row = rows.first;
  final nombre = _str(row, 'material_nombre', alt: 'nombre').isEmpty
      ? _str(row, 'nombre')
      : _str(row, 'material_nombre', alt: 'nombre');
  return _MaterialResumen(nombre, _num(row, 'costo_total'));
}

_TendenciaGasto? _tendenciaGasto(List<dynamic> gastoPorDia) {
  final rows = gastoPorDia.map((e) => _map(e)).toList()
    ..sort((a, b) => _str(a, 'dia').compareTo(_str(b, 'dia')));

  if (rows.length < 2) return null;

  final anterior = _num(rows[rows.length - 2], 'costo_total');
  final actual = _num(rows.last, 'costo_total');

  final variacion = anterior > 0
      ? ((actual - anterior) / anterior) * 100
      : actual > 0
          ? 100.0
          : 0.0;

  return _TendenciaGasto(
    anterior: anterior,
    actual: actual,
    variacion: variacion,
  );
}

List<dynamic> _list(dynamic value) {
  if (value is List) return value;
  return const [];
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return <String, dynamic>{};
}

String _str(Map<String, dynamic> map, String key, {String? alt}) {
  final value = map[key] ?? (alt == null ? null : map[alt]);
  if (value == null) return '';
  return value.toString();
}

double _num(Map<String, dynamic> map, String key, {String? alt}) {
  final value = map[key] ?? (alt == null ? null : map[alt]);
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}

String _formatCantidad(double value) {
  if (value % 1 == 0) return value.toInt().toString();
  return value.toStringAsFixed(2);
}

String _diaCorto(String dia) {
  final parts = dia.split('-');
  if (parts.length == 3) return '${parts[2]}/${parts[1]}';
  return dia;
}

Color _estadoColor(String estado) {
  switch (estado.toLowerCase()) {
    case 'entregada':
    case 'entregado':
      return const Color(0xFF059669);
    case 'aprobada':
    case 'aprobado':
      return const Color(0xFF2563EB);
    case 'rechazada':
    case 'rechazado':
      return const Color(0xFFDC2626);
    case 'pendiente':
      return const Color(0xFFF59E0B);
    default:
      return TecneroTheme.azulOscuro;
  }
}

Color _lineaColor(int index) {
  const colors = [
    TecneroTheme.naranja,
    Color(0xFF2563EB),
    Color(0xFF059669),
    Color(0xFF7C3AED),
    Color(0xFFF59E0B),
    Color(0xFF0891B2),
    Color(0xFFDC2626),
  ];
  return colors[index % colors.length];
}

class _SimuladorGastosAdicionales extends StatefulWidget {
  final double gastoMateriales;
  final NumberFormat fmtMoney;
  final List<dynamic> produccionUnitaria;

  const _SimuladorGastosAdicionales({
    required this.gastoMateriales,
    required this.fmtMoney,
    required this.produccionUnitaria,
  });

  @override
  State<_SimuladorGastosAdicionales> createState() =>
      _SimuladorGastosAdicionalesState();
}

class _SimuladorGastosAdicionalesState
    extends State<_SimuladorGastosAdicionales> {
  late final TextEditingController _personalCtrl;
  late final TextEditingController _otrosCtrl;
  late final TextEditingController _unidadesCtrl;

  @override
  void initState() {
    super.initState();
    final unidades = _unidadesProducidasDelFiltro();
    _personalCtrl = TextEditingController();
    _otrosCtrl = TextEditingController();
    _unidadesCtrl = TextEditingController(
      text: unidades > 0 ? _formatCantidad(unidades) : '',
    );
  }

  @override
  void dispose() {
    _personalCtrl.dispose();
    _otrosCtrl.dispose();
    _unidadesCtrl.dispose();
    super.dispose();
  }

  double _parse(TextEditingController ctrl) {
    return double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0;
  }

  double _unidadesProducidasDelFiltro() {
    double total = 0;

    for (final raw in widget.produccionUnitaria) {
      final row = _map(raw);
      final cantidadTotal = _num(row, 'cantidad_total');
      final cantidadProducida = _num(row, 'cantidad_producida');
      final produccionTotal = _num(row, 'produccion_total');

      if (cantidadTotal > 0) {
        total += cantidadTotal;
      } else if (cantidadProducida > 0) {
        total += cantidadProducida;
      } else {
        total += produccionTotal;
      }
    }

    return total;
  }

  String _unidadReferencia() {
    final unidades = <String>{};

    for (final raw in widget.produccionUnitaria) {
      final row = _map(raw);
      final unidad = _str(row, 'unidad');
      if (unidad.isNotEmpty) unidades.add(unidad);
    }

    if (unidades.length == 1) return unidades.first;
    if (unidades.length > 1) return 'unidades mixtas';
    return 'unidades';
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final gastoPersonal = _parse(_personalCtrl);
    final gastoOtros = _parse(_otrosCtrl);
    final unidades = _parse(_unidadesCtrl);

    final gastoTotal = widget.gastoMateriales + gastoPersonal + gastoOtros;
    final costoUnitario = unidades > 0 ? gastoTotal / unidades : 0.0;
    final unidad = _unidadReferencia();

    final inputs = [
      TextField(
        controller: _personalCtrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(
          labelText: 'Gastos de personal',
          prefixIcon: Icon(Icons.groups_outlined, size: 18),
        ),
      ),
      TextField(
        controller: _otrosCtrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(
          labelText: 'Otros gastos',
          prefixIcon: Icon(Icons.attach_money_outlined, size: 18),
        ),
      ),
      TextField(
        controller: _unidadesCtrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(
          labelText: 'Unidades producidas del filtro',
          prefixIcon: Icon(Icons.precision_manufacturing_outlined, size: 18),
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = isMobile || constraints.maxWidth < 720;

            if (compact) {
              return Column(
                children: [
                  for (final input in inputs) ...[
                    input,
                    if (input != inputs.last) const SizedBox(height: 10),
                  ],
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: inputs[0]),
                const SizedBox(width: 10),
                Expanded(child: inputs[1]),
                const SizedBox(width: 10),
                Expanded(child: inputs[2]),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: TecneroTheme.naranja.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: TecneroTheme.naranja.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            children: [
              _GastoRow(
                label: 'Materiales filtrados',
                value: widget.gastoMateriales,
                fmtMoney: widget.fmtMoney,
                isOriginal: true,
              ),
              const SizedBox(height: 8),
              _GastoRow(
                label: 'Personal',
                value: gastoPersonal,
                fmtMoney: widget.fmtMoney,
              ),
              const SizedBox(height: 8),
              _GastoRow(
                label: 'Otros',
                value: gastoOtros,
                fmtMoney: widget.fmtMoney,
              ),
              const Divider(height: 22),
              _GastoRow(
                label: 'Total simulado',
                value: gastoTotal,
                fmtMoney: widget.fmtMoney,
                isTotal: true,
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: TecneroTheme.grisBorde),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.calculate_outlined,
                      size: 18,
                      color: TecneroTheme.naranja,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        unidades > 0
                            ? 'Costo unitario simulado: ${widget.fmtMoney.format(costoUnitario)} por $unidad'
                            : 'Ingresa unidades producidas para calcular costo unitario',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: TecneroTheme.azulOscuro,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (gastoPersonal > 0 || gastoOtros > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: TecneroTheme.naranja.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: TecneroTheme.naranja,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Este es un cálculo simulado. Los gastos adicionales no se guardan en el sistema.',
                          style: TextStyle(
                            fontSize: 11,
                            color: TecneroTheme.textoSecundario,
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
      ],
    );
  }
}

class _GastoRow extends StatelessWidget {
  final String label;
  final double value;
  final NumberFormat fmtMoney;
  final bool isOriginal;
  final bool isTotal;

  const _GastoRow({
    required this.label,
    required this.value,
    required this.fmtMoney,
    this.isOriginal = false,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 14 : 12,
            fontWeight: isTotal ? FontWeight.w900 : FontWeight.w600,
            color: isTotal
                ? TecneroTheme.naranja
                : (isOriginal
                    ? TecneroTheme.textoSecundario
                    : TecneroTheme.textoPrimario),
          ),
        ),
        Text(
          fmtMoney.format(value),
          style: TextStyle(
            fontSize: isTotal ? 16 : 13,
            fontWeight: FontWeight.w900,
            color: isTotal
                ? TecneroTheme.naranja
                : (isOriginal
                    ? TecneroTheme.textoSecundario
                    : TecneroTheme.textoPrimario),
          ),
        ),
      ],
    );
  }
}
