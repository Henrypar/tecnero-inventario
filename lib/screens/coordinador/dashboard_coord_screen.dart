// Resumen de costos para el coordinador de produccion.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';
import '../../services/providers.dart';
import '../../widgets/responsive.dart';

class DashboardCoordScreen extends ConsumerWidget {
  const DashboardCoordScreen({super.key});

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
                  'Costos de producción',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Resumen del mes actual',
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
                final totales = _asMap(data['totales']);
                final porLinea = _asList(data['por_linea'] ?? data['porLinea']);
                final topMats =
                    _asList(data['top_materiales'] ?? data['topMateriales']);

                final costoTotal = _numValue(
                  totales,
                  ['costoTotal', 'costo_total'],
                );

                final maxLinea = porLinea.isEmpty
                    ? 1.0
                    : porLinea
                        .map(
                          (l) => _numValue(
                            l,
                            ['costoTotal', 'costo_total'],
                          ),
                        )
                        .fold<double>(0, (a, b) => a > b ? a : b);

                return SingleChildScrollView(
                  padding: Responsive.pagePadding(context),
                  child: Column(
                    children: [
                      _HeroCostCard(
                        costoTotal: costoTotal,
                        totalSolicitudes: _numValue(
                          totales,
                          ['totalSolicitudes', 'total_solicitudes'],
                        ).toInt(),
                        entregadas: _numValue(
                          totales,
                          ['entregadas'],
                        ).toInt(),
                        fmt: fmt,
                      ),
                      const SizedBox(height: 20),
                      _ResponsiveTwoColumn(
                        leftFlex: 3,
                        rightFlex: 2,
                        left: _CostoPorLineaCard(
                          porLinea: porLinea,
                          maxLinea: maxLinea <= 0 ? 1 : maxLinea,
                          fmt: fmt,
                        ),
                        right: _TopMaterialesCard(
                          topMats: topMats,
                          fmt: fmt,
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

class _HeroCostCard extends StatelessWidget {
  final double costoTotal;
  final int totalSolicitudes;
  final int entregadas;
  final NumberFormat fmt;

  const _HeroCostCard({
    required this.costoTotal,
    required this.totalSolicitudes,
    required this.entregadas,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 18 : 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            TecneroTheme.azulOscuro,
            Color(0xFF185FA5),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Gasto total en materiales este mes',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    fmt.format(costoTotal),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Solo materiales, sin mano de obra',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _MiniMetric(
                        label: 'Solicitudes',
                        value: '$totalSolicitudes',
                      ),
                    ),
                    Expanded(
                      child: _MiniMetric(
                        label: 'Entregadas',
                        value: '$entregadas',
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
                      const Text(
                        'Gasto total en materiales este mes',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          fmt.format(costoTotal),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Solo materiales, sin mano de obra',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Wrap(
                  spacing: 18,
                  runSpacing: 12,
                  children: [
                    _MiniMetric(
                      label: 'Solicitudes',
                      value: '$totalSolicitudes',
                    ),
                    _MiniMetric(
                      label: 'Entregadas',
                      value: '$entregadas',
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _CostoPorLineaCard extends StatelessWidget {
  final List<dynamic> porLinea;
  final double maxLinea;
  final NumberFormat fmt;

  const _CostoPorLineaCard({
    required this.porLinea,
    required this.maxLinea,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Card(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Costo por línea de producción',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Para decidir si dar descuentos a clientes',
              style: TextStyle(
                fontSize: 11,
                color: TecneroTheme.textoSecundario,
              ),
            ),
            const SizedBox(height: 20),
            if (porLinea.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Sin datos este mes',
                    style: TextStyle(
                      color: TecneroTheme.textoSecundario,
                    ),
                  ),
                ),
              )
            else
              ...porLinea.map((l) {
                final costo = _numValue(l, ['costoTotal', 'costo_total']);
                final linea = _textValue(
                  l,
                  ['lineaNombre', 'linea_nombre'],
                  fallback: 'Sin línea',
                );
                final solicitudes = _numValue(
                  l,
                  ['totalSolicitudes', 'total_solicitudes'],
                ).toInt();

                final pct = maxLinea > 0 ? costo / maxLinea : 0.0;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 15),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              linea,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            fmt.format(costo),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: TecneroTheme.naranja,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: pct.clamp(0.0, 1.0),
                          minHeight: 8,
                          backgroundColor: TecneroTheme.grisClaro,
                          valueColor: const AlwaysStoppedAnimation(
                            TecneroTheme.naranja,
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '$solicitudes solicitudes',
                          style: const TextStyle(
                            fontSize: 10,
                            color: TecneroTheme.textoSecundario,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _TopMaterialesCard extends StatelessWidget {
  final List<dynamic> topMats;
  final NumberFormat fmt;

  const _TopMaterialesCard({
    required this.topMats,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Card(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Materiales más costosos',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Top 5 por gasto total',
              style: TextStyle(
                fontSize: 11,
                color: TecneroTheme.textoSecundario,
              ),
            ),
            const SizedBox(height: 16),
            if (topMats.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Sin datos',
                    style: TextStyle(
                      color: TecneroTheme.textoSecundario,
                    ),
                  ),
                ),
              )
            else
              ...topMats.take(5).toList().asMap().entries.map((e) {
                final i = e.key;
                final m = e.value;

                final colors = [
                  TecneroTheme.naranja,
                  TecneroTheme.azulOscuro,
                  TecneroTheme.azulMedio,
                  const Color(0xFF059669),
                  const Color(0xFFF59E0B),
                ];

                final color = colors[i % colors.length];

                final nombre = _textValue(
                  m,
                  ['materialNombre', 'material_nombre', 'nombre'],
                  fallback: 'Material',
                );

                final codigo = _textValue(
                  m,
                  ['materialCodigo', 'material_codigo', 'codigo'],
                );

                final cantidad = _numValue(
                  m,
                  ['cantidadTotal', 'cantidad_total'],
                );

                final unidad = _textValue(
                  m,
                  ['unidadMedida', 'unidad_medida'],
                );

                final costo = _numValue(
                  m,
                  ['costoTotal', 'costo_total'],
                );

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nombre,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                            Text(
                              [
                                if (codigo.isNotEmpty) codigo,
                                '${_formatCantidad(cantidad)} $unidad'.trim(),
                              ].join(' · '),
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
                      Text(
                        fmt.format(costo),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;

  const _MiniMetric({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 10,
          ),
        ),
      ],
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
        final compact =
            Responsive.isMobile(context) || constraints.maxWidth < 900;

        if (compact) {
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

/* Helpers seguros para evitar:
   TypeError: null: type 'Null' is not a subtype of type 'num'
*/

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

List<dynamic> _asList(dynamic value) {
  if (value is List) return value;
  return <dynamic>[];
}

double _numValue(dynamic source, List<String> keys) {
  if (source is Map) {
    for (final key in keys) {
      final value = source[key];

      if (value == null) continue;
      if (value is num) return value.toDouble();

      final parsed = double.tryParse(value.toString());
      if (parsed != null) return parsed;
    }
  }

  return 0;
}

String _textValue(
  dynamic source,
  List<String> keys, {
  String fallback = '',
}) {
  if (source is Map) {
    for (final key in keys) {
      final value = source[key];

      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
  }

  return fallback;
}

String _formatCantidad(double value) {
  if (value % 1 == 0) return value.toInt().toString();
  return value.toStringAsFixed(2);
}
