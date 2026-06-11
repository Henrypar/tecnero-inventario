// Pantalla de materiales, compras, stock y precios para administracion y compras.
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';
import '../../services/providers.dart';
import '../../widgets/responsive.dart';

class PreciosScreen extends ConsumerStatefulWidget {
  const PreciosScreen({super.key});

  @override
  ConsumerState<PreciosScreen> createState() => _PreciosScreenState();
}

class _PreciosScreenState extends ConsumerState<PreciosScreen> {
  final _buscarCtrl = TextEditingController();
  String _busqueda = '';
  String _categoriaFiltro = 'todos';
  String _estadoFiltro = 'activos';
  String _stockFiltro = 'todos';

  final _fmtMoney = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  final _fmtDate = DateFormat('dd/MM/yyyy');

  @override
  void dispose() {
    _buscarCtrl.dispose();
    super.dispose();
  }

  Future<void> _abrirProducto({Map<String, dynamic>? material}) async {
    final guardado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _MaterialDialog(material: material),
    );

    if (guardado == true) {
      ref.invalidate(materialesConPreciosProvider);
      ref.invalidate(materialesProvider);
    }
  }

  Future<void> _abrirPrecio(Map<String, dynamic> material) async {
    final guardado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PrecioDialog(material: material),
    );

    if (guardado == true) {
      ref.invalidate(materialesConPreciosProvider);
      ref.invalidate(historialIngresosInventarioProvider);
    }
  }

  Future<void> _abrirStock(Map<String, dynamic> material) async {
    final guardado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _StockDialog(material: material),
    );

    if (guardado == true) {
      ref.invalidate(materialesConPreciosProvider);
      ref.invalidate(materialesProvider);
      ref.invalidate(historialIngresosInventarioProvider);
    }
  }

  Future<void> _abrirIngreso(List<Map<String, dynamic>> materiales) async {
    final guardado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _IngresoInventarioDialog(materiales: materiales),
    );

    if (guardado == true) {
      ref.invalidate(materialesConPreciosProvider);
      ref.invalidate(materialesProvider);
      ref.invalidate(historialIngresosInventarioProvider);
    }
  }

  Future<void> _abrirHistorialIngresos() async {
    await showDialog<void>(
      context: context,
      builder: (_) => const _HistorialIngresosDialog(),
    );
  }

  Future<void> _abrirConfigAlertas(
    List<Map<String, dynamic>> materiales,
  ) async {
    final guardado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ConfigAlertasStockDialog(materiales: materiales),
    );

    if (guardado == true) {
      ref.invalidate(materialesConPreciosProvider);
      ref.invalidate(materialesProvider);
    }
  }

  Future<void> _abrirDetalleProducto(Map<String, dynamic> material) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _ProductoDetalleDialog(
        material: material,
        fmtMoney: _fmtMoney,
        fmtDate: _fmtDate,
      ),
    );
  }

  Future<void> _desactivar(Map<String, dynamic> material) async {
    final nombre = _str(material, 'nombre');
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desactivar producto'),
        content: Text(
          '¿Quieres desactivar "$nombre"? Ya no aparecerá para nuevas solicitudes, pero queda en el historial.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.block_outlined, size: 18),
            label: const Text('Desactivar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await ref
          .read(apiServiceProvider)
          .desactivarMaterial(_str(material, 'id'));
      ref.invalidate(materialesConPreciosProvider);
      ref.invalidate(materialesProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Producto "$nombre" desactivado'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _mostrarError(context, e.toString());
    }
  }

  void _limpiarFiltros() {
    setState(() {
      _busqueda = '';
      _buscarCtrl.clear();
      _categoriaFiltro = 'todos';
      _estadoFiltro = 'activos';
      _stockFiltro = 'todos';
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
          child: _FiltrosCompras(
            buscarCtrl: _buscarCtrl,
            categoriaFiltro: _categoriaFiltro,
            estadoFiltro: _estadoFiltro,
            stockFiltro: _stockFiltro,
            onBuscar: (value) =>
                setState(() => _busqueda = value.trim().toLowerCase()),
            onCategoriaChanged: (value) =>
                setState(() => _categoriaFiltro = value),
            onEstadoChanged: (value) => setState(() => _estadoFiltro = value),
            onStockChanged: (value) => setState(() => _stockFiltro = value),
            onLimpiar: _limpiarFiltros,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final materialesAsync = ref.watch(materialesConPreciosProvider);
    final materialesDisponibles = materialesAsync.asData?.value ?? [];
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
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: isMobile
                          ? MediaQuery.sizeOf(context).width - 32
                          : 420,
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Compras',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Catálogo, precios actuales y reposición de stock',
                            style: TextStyle(
                              fontSize: 13,
                              color: TecneroTheme.textoSecundario,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _abrirHistorialIngresos,
                          icon: const Icon(Icons.history_outlined, size: 18),
                          label: const Text('Historial'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _abrirProducto(),
                          icon:
                              const Icon(Icons.add_business_outlined, size: 18),
                          label: const Text('Nuevo producto'),
                        ),
                        OutlinedButton.icon(
                          onPressed: materialesDisponibles.isEmpty
                              ? null
                              : () => _abrirConfigAlertas(
                                    materialesDisponibles,
                                  ),
                          icon: const Icon(
                            Icons.notifications_active_outlined,
                            size: 18,
                          ),
                          label: const Text('Configurar alertas'),
                        ),
                        ElevatedButton.icon(
                          onPressed: materialesDisponibles.isEmpty
                              ? null
                              : () => _abrirIngreso(materialesDisponibles),
                          icon: const Icon(Icons.playlist_add, size: 18),
                          label: const Text('Registrar ingreso'),
                        ),
                      ],
                    ),
                  ],
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
                  _FiltrosCompras(
                    buscarCtrl: _buscarCtrl,
                    categoriaFiltro: _categoriaFiltro,
                    estadoFiltro: _estadoFiltro,
                    stockFiltro: _stockFiltro,
                    onBuscar: (value) =>
                        setState(() => _busqueda = value.trim().toLowerCase()),
                    onCategoriaChanged: (value) =>
                        setState(() => _categoriaFiltro = value),
                    onEstadoChanged: (value) =>
                        setState(() => _estadoFiltro = value),
                    onStockChanged: (value) =>
                        setState(() => _stockFiltro = value),
                    onLimpiar: _limpiarFiltros,
                  ),
              ],
            ),
          ),
          Expanded(
            child: materialesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (lista) {
                final filtrada = _filtrar(lista);

                if (filtrada.isEmpty) {
                  return const _EmptyCompras();
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(materialesConPreciosProvider);
                    ref.invalidate(historialIngresosInventarioProvider);
                    await ref.read(materialesConPreciosProvider.future);
                  },
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      isMobile ? 12 : 20,
                      14,
                      isMobile ? 12 : 20,
                      24,
                    ),
                    children: [
                      _ResumenCompras(
                        materiales: filtrada,
                      ),
                      const SizedBox(height: 14),
                      ...filtrada.map(
                        (m) => _MaterialCard(
                          material: m,
                          fmtMoney: _fmtMoney,
                          fmtDate: _fmtDate,
                          onVerDetalle: () => _abrirDetalleProducto(m),
                          onEditar: () => _abrirProducto(material: m),
                          onPrecio: () => _abrirPrecio(m),
                          onStock: () => _abrirStock(m),
                          onDesactivar: () => _desactivar(m),
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

  List<Map<String, dynamic>> _filtrar(List<Map<String, dynamic>> lista) {
    return lista.where((m) {
      final activo = _bool(m, 'activo', fallback: true);
      final stock = _num(m, 'stockActual', 'stock_actual');
      final stockMinimo = _stockMinimoAlerta(m);
      final precio = _precio(m);
      final categoria = _str(m, 'categoria');
      final texto = [
        _str(m, 'codigo'),
        _str(m, 'nombre'),
        _str(m, 'unidadMedida', 'unidad_medida'),
        categoria,
      ].join(' ').toLowerCase();

      final matchBusqueda = _busqueda.isEmpty || texto.contains(_busqueda);
      final matchCategoria =
          _categoriaFiltro == 'todos' || categoria == _categoriaFiltro;
      final matchEstado = _estadoFiltro == 'todos' ||
          (_estadoFiltro == 'activos' && activo) ||
          (_estadoFiltro == 'inactivos' && !activo);
      final matchStock = _stockFiltro == 'todos' ||
          (_stockFiltro == 'bajo' && activo && stock <= stockMinimo) ||
          (_stockFiltro == 'sin_precio' && activo && precio == null);

      return matchBusqueda && matchCategoria && matchEstado && matchStock;
    }).toList()
      ..sort((a, b) {
        final activoA = _bool(a, 'activo', fallback: true);
        final activoB = _bool(b, 'activo', fallback: true);
        if (activoA != activoB) return activoA ? -1 : 1;

        final stockA = _num(a, 'stockActual', 'stock_actual');
        final stockB = _num(b, 'stockActual', 'stock_actual');
        final bajoA = stockA <= _stockMinimoAlerta(a);
        final bajoB = stockB <= _stockMinimoAlerta(b);
        if (bajoA != bajoB) return bajoA ? -1 : 1;

        return _str(a, 'nombre').compareTo(_str(b, 'nombre'));
      });
  }
}

class _FiltrosCompras extends StatelessWidget {
  final TextEditingController buscarCtrl;
  final String categoriaFiltro;
  final String estadoFiltro;
  final String stockFiltro;
  final ValueChanged<String> onBuscar;
  final ValueChanged<String> onCategoriaChanged;
  final ValueChanged<String> onEstadoChanged;
  final ValueChanged<String> onStockChanged;
  final VoidCallback onLimpiar;

  const _FiltrosCompras({
    required this.buscarCtrl,
    required this.categoriaFiltro,
    required this.estadoFiltro,
    required this.stockFiltro,
    required this.onBuscar,
    required this.onCategoriaChanged,
    required this.onEstadoChanged,
    required this.onStockChanged,
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
          width: isMobile ? double.infinity : 280,
          child: TextField(
            controller: buscarCtrl,
            decoration: const InputDecoration(
              hintText: 'Buscar código o producto...',
              prefixIcon: Icon(Icons.search, size: 18),
              isDense: true,
            ),
            onChanged: onBuscar,
          ),
        ),
        _FiltroDropdown(
          width: isMobile ? double.infinity : 170,
          value: categoriaFiltro,
          icon: Icons.category_outlined,
          items: const [
            DropdownMenuItem(value: 'todos', child: Text('Categorías')),
            DropdownMenuItem(value: 'produccion', child: Text('Producción')),
            DropdownMenuItem(value: 'epp', child: Text('EPP')),
            DropdownMenuItem(
                value: 'mantenimiento', child: Text('Mantenimiento')),
          ],
          onChanged: onCategoriaChanged,
        ),
        _FiltroDropdown(
          width: isMobile ? double.infinity : 150,
          value: estadoFiltro,
          icon: Icons.toggle_on_outlined,
          items: const [
            DropdownMenuItem(value: 'activos', child: Text('Activos')),
            DropdownMenuItem(value: 'inactivos', child: Text('Inactivos')),
            DropdownMenuItem(value: 'todos', child: Text('Todos')),
          ],
          onChanged: onEstadoChanged,
        ),
        _FiltroDropdown(
          width: isMobile ? double.infinity : 180,
          value: stockFiltro,
          icon: Icons.inventory_outlined,
          items: const [
            DropdownMenuItem(value: 'todos', child: Text('Todo stock')),
            DropdownMenuItem(value: 'bajo', child: Text('Stock bajo')),
            DropdownMenuItem(value: 'sin_precio', child: Text('Sin precio')),
          ],
          onChanged: onStockChanged,
        ),
        TextButton.icon(
          onPressed: onLimpiar,
          icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
          label: const Text('Limpiar'),
        ),
      ],
    );
  }
}

class _FiltroDropdown extends StatelessWidget {
  final double width;
  final String value;
  final IconData icon;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String> onChanged;

  const _FiltroDropdown({
    required this.width,
    required this.value,
    required this.icon,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, size: 18),
          isDense: true,
        ),
        selectedItemBuilder: (context) {
          return items.map((item) {
            final child = item.child;
            final text = child is Text ? child.data ?? '' : '';
            return Align(
              alignment: Alignment.centerLeft,
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            );
          }).toList();
        },
        items: items,
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      ),
    );
  }
}

class _ResumenCompras extends StatelessWidget {
  final List<Map<String, dynamic>> materiales;

  const _ResumenCompras({
    required this.materiales,
  });

  @override
  Widget build(BuildContext context) {
    final activos =
        materiales.where((m) => _bool(m, 'activo', fallback: true)).length;
    final stockBajo = materiales.where((m) {
      return _bool(m, 'activo', fallback: true) &&
          _num(m, 'stockActual', 'stock_actual') <= _stockMinimoAlerta(m);
    }).length;
    final sinPrecio = materiales.where((m) {
      return _bool(m, 'activo', fallback: true) && _precio(m) == null;
    }).length;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _MetricChip(
          icon: Icons.inventory_2_outlined,
          label: 'Productos',
          value: '${materiales.length}',
          color: TecneroTheme.azulOscuro,
        ),
        _MetricChip(
          icon: Icons.check_circle_outline,
          label: 'Activos',
          value: '$activos',
          color: const Color(0xFF059669),
        ),
        _MetricChip(
          icon: Icons.warning_amber_outlined,
          label: 'Stock bajo',
          value: '$stockBajo',
          color: const Color(0xFFF59E0B),
        ),
        _MetricChip(
          icon: Icons.sell_outlined,
          label: 'Sin precio',
          value: '$sinPrecio',
          color: const Color(0xFFDC2626),
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
      width: Responsive.isMobile(context) ? double.infinity : 170,
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

class _MaterialCard extends StatelessWidget {
  final Map<String, dynamic> material;
  final NumberFormat fmtMoney;
  final DateFormat fmtDate;
  final VoidCallback onVerDetalle;
  final VoidCallback onEditar;
  final VoidCallback onPrecio;
  final VoidCallback onStock;
  final VoidCallback onDesactivar;

  const _MaterialCard({
    required this.material,
    required this.fmtMoney,
    required this.fmtDate,
    required this.onVerDetalle,
    required this.onEditar,
    required this.onPrecio,
    required this.onStock,
    required this.onDesactivar,
  });

  @override
  Widget build(BuildContext context) {
    final activo = _bool(material, 'activo', fallback: true);
    final stock = _num(material, 'stockActual', 'stock_actual');
    final stockMinimo = _stockMinimoAlerta(material);
    final precio = _precio(material);
    final costoPromedio = _num(material, 'costoPromedio', 'costo_promedio');
    final valorInventario =
        _num(material, 'valorInventario', 'valor_inventario');
    final fechaPrecio = _fechaPrecio(material);
    final stockBajo = stock <= stockMinimo;
    final isMobile = Responsive.isMobile(context);
    final borderColor = !activo
        ? TecneroTheme.textoSecundario
        : stockBajo
            ? const Color(0xFFF59E0B)
            : _categoriaStyle(_str(material, 'categoria')).color;

    return Card(
      color: activo ? Colors.white : const Color(0xFFF8FAFC),
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onVerDetalle,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: borderColor, width: 4),
            ),
          ),
          padding: EdgeInsets.all(isMobile ? 12 : 14),
          child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _MaterialInfo(
                            material: material,
                            activo: activo,
                            stockBajo: stockBajo,
                          ),
                        ),
                        _MaterialMenu(
                          activo: activo,
                          onHistorial: onVerDetalle,
                          onEditar: onEditar,
                          onPrecio: onPrecio,
                          onStock: onStock,
                          onDesactivar: onDesactivar,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _MaterialStats(
                      stock: stock,
                      stockMinimo: stockMinimo,
                      precio: precio,
                      costoPromedio: costoPromedio,
                      valorInventario: valorInventario,
                      fechaPrecio: fechaPrecio,
                      fmtMoney: fmtMoney,
                      fmtDate: fmtDate,
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: _MaterialInfo(
                        material: material,
                        activo: activo,
                        stockBajo: stockBajo,
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 420,
                      child: _MaterialStats(
                        stock: stock,
                        stockMinimo: stockMinimo,
                        precio: precio,
                        costoPromedio: costoPromedio,
                        valorInventario: valorInventario,
                        fechaPrecio: fechaPrecio,
                        fmtMoney: fmtMoney,
                        fmtDate: fmtDate,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _MaterialMenu(
                      activo: activo,
                      onHistorial: onVerDetalle,
                      onEditar: onEditar,
                      onPrecio: onPrecio,
                      onStock: onStock,
                      onDesactivar: onDesactivar,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _MaterialInfo extends StatelessWidget {
  final Map<String, dynamic> material;
  final bool activo;
  final bool stockBajo;

  const _MaterialInfo({
    required this.material,
    required this.activo,
    required this.stockBajo,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              _str(material, 'codigo'),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: TecneroTheme.azulOscuro,
              ),
            ),
            _CategoriaBadge(categoria: _str(material, 'categoria')),
            if (!activo) const _StatusBadge(label: 'INACTIVO'),
            if (stockBajo && activo)
              const _StatusBadge(
                label: 'STOCK BAJO',
                color: Color(0xFFF59E0B),
                background: Color(0xFFFEF3C7),
              ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          _str(material, 'nombre'),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Unidad: ${_str(material, 'unidadMedida', 'unidad_medida')}',
          style: const TextStyle(
            fontSize: 11,
            color: TecneroTheme.textoSecundario,
          ),
        ),
      ],
    );
  }
}

class _MaterialStats extends StatelessWidget {
  final double stock;
  final double stockMinimo;
  final double? precio;
  final double costoPromedio;
  final double valorInventario;
  final DateTime? fechaPrecio;
  final NumberFormat fmtMoney;
  final DateFormat fmtDate;

  const _MaterialStats({
    required this.stock,
    required this.stockMinimo,
    required this.precio,
    required this.costoPromedio,
    required this.valorInventario,
    required this.fechaPrecio,
    required this.fmtMoney,
    required this.fmtDate,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _InfoPill(
          icon: Icons.inventory_outlined,
          label: 'Stock actual',
          value: _formatCantidad(stock),
        ),
        _InfoPill(
          icon: Icons.notifications_active_outlined,
          label: 'Aviso bajo <=',
          value: _formatCantidad(stockMinimo),
          danger: stock <= stockMinimo,
        ),
        _InfoPill(
          icon: Icons.sell_outlined,
          label: 'Precio actual',
          value: precio == null ? 'Sin precio' : fmtMoney.format(precio),
          danger: precio == null,
        ),
        _InfoPill(
          icon: Icons.functions_outlined,
          label: 'Costo promedio',
          value: fmtMoney.format(costoPromedio),
        ),
        _InfoPill(
          icon: Icons.account_balance_wallet_outlined,
          label: 'Valor inventario',
          value: fmtMoney.format(valorInventario),
        ),
        _InfoPill(
          icon: Icons.event_outlined,
          label: 'Vigente desde',
          value: fechaPrecio == null
              ? 'No registrado'
              : fmtDate.format(fechaPrecio!),
        ),
      ],
    );
  }
}

class _MaterialMenu extends StatelessWidget {
  final bool activo;
  final VoidCallback onHistorial;
  final VoidCallback onEditar;
  final VoidCallback onPrecio;
  final VoidCallback onStock;
  final VoidCallback onDesactivar;

  const _MaterialMenu({
    required this.activo,
    required this.onHistorial,
    required this.onEditar,
    required this.onPrecio,
    required this.onStock,
    required this.onDesactivar,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_ProductoMenuAction>(
      tooltip: 'Opciones',
      icon: const Icon(Icons.more_vert),
      onSelected: (value) {
        switch (value) {
          case _ProductoMenuAction.historial:
            onHistorial();
            break;
          case _ProductoMenuAction.stock:
            onStock();
            break;
          case _ProductoMenuAction.precio:
            onPrecio();
            break;
          case _ProductoMenuAction.editar:
            onEditar();
            break;
          case _ProductoMenuAction.desactivar:
            onDesactivar();
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: _ProductoMenuAction.historial,
          child: _MenuRow(
              icon: Icons.insights_outlined, label: 'Ver historial y gráfica'),
        ),
        const PopupMenuItem(
          value: _ProductoMenuAction.stock,
          child: _MenuRow(icon: Icons.add_box_outlined, label: 'Agregar más'),
        ),
        const PopupMenuItem(
          value: _ProductoMenuAction.precio,
          child: _MenuRow(icon: Icons.attach_money, label: 'Actualizar precio'),
        ),
        const PopupMenuItem(
          value: _ProductoMenuAction.editar,
          child: _MenuRow(icon: Icons.edit_outlined, label: 'Editar producto'),
        ),
        if (activo) const PopupMenuDivider(),
        if (activo)
          const PopupMenuItem(
            value: _ProductoMenuAction.desactivar,
            child: _MenuRow(
              icon: Icons.block_outlined,
              label: 'Desactivar',
              color: Color(0xFFDC2626),
            ),
          ),
      ],
    );
  }
}

enum _ProductoMenuAction { historial, stock, precio, editar, desactivar }

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _MenuRow({
    required this.icon,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color ?? TecneroTheme.azulOscuro),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(color: color),
        ),
      ],
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool danger;

  const _InfoPill({
    required this.icon,
    required this.label,
    required this.value,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: Responsive.isMobile(context) ? double.infinity : 112,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: danger ? const Color(0xFFFEE2E2) : TecneroTheme.grisClaro,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: danger ? const Color(0xFFFCA5A5) : TecneroTheme.grisBorde,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 15,
            color:
                danger ? const Color(0xFFB91C1C) : TecneroTheme.textoSecundario,
          ),
          const SizedBox(width: 7),
          Expanded(
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
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: danger
                        ? const Color(0xFF991B1B)
                        : TecneroTheme.textoPrimario,
                    fontWeight: FontWeight.w800,
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

class _ProductoDetalleDialog extends ConsumerWidget {
  final Map<String, dynamic> material;
  final NumberFormat fmtMoney;
  final DateFormat fmtDate;

  const _ProductoDetalleDialog({
    required this.material,
    required this.fmtMoney,
    required this.fmtDate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historialAsync = ref.watch(historialIngresosInventarioProvider);
    final isMobile = Responsive.isMobile(context);
    final materialId = _str(material, 'id');
    final precioActual = _precio(material);
    final stockActual = _num(material, 'stockActual', 'stock_actual');
    final costoPromedio = _num(material, 'costoPromedio', 'costo_promedio');
    final valorInventario =
        _num(material, 'valorInventario', 'valor_inventario');
    final creado = _fechaCreacion(material);

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(22, 18, 12, 0),
      contentPadding: const EdgeInsets.fromLTRB(22, 12, 22, 8),
      actionsPadding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
      title: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _str(material, 'nombre'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Text(
                      _str(material, 'codigo'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: TecneroTheme.textoSecundario,
                      ),
                    ),
                    _CategoriaBadge(categoria: _str(material, 'categoria')),
                  ],
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
      content: SizedBox(
        width: isMobile ? MediaQuery.sizeOf(context).width * 0.92 : 860,
        height: isMobile ? MediaQuery.sizeOf(context).height * 0.72 : 620,
        child: historialAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (historial) {
            final movimientos = historial
                .where((m) =>
                    _movimientoPerteneceAMaterial(m, materialId, material))
                .toList()
              ..sort(
                  (a, b) => _fechaMovimiento(b).compareTo(_fechaMovimiento(a)));

            final puntos = _construirPuntosPrecio(material, movimientos);
            final ultimaEntrada =
                movimientos.isEmpty ? null : movimientos.first;
            final variacion = _variacionPrecio(puntos);

            return ListView(
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _DetalleMetric(
                      icon: Icons.inventory_outlined,
                      label: 'Stock actual',
                      value: _formatCantidad(stockActual),
                    ),
                    _DetalleMetric(
                      icon: Icons.sell_outlined,
                      label: 'Precio actual',
                      value: precioActual == null
                          ? 'Sin precio'
                          : fmtMoney.format(precioActual),
                      danger: precioActual == null,
                    ),
                    _DetalleMetric(
                      icon: Icons.calculate_outlined,
                      label: 'Costo promedio',
                      value: fmtMoney.format(costoPromedio),
                    ),
                    _DetalleMetric(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Valor inventario',
                      value: fmtMoney.format(valorInventario),
                    ),
                    _DetalleMetric(
                      icon: variacion >= 0
                          ? Icons.trending_up
                          : Icons.trending_down,
                      label: 'Variación',
                      value: puntos.length < 2
                          ? 'Sin datos'
                          : '${variacion >= 0 ? '+' : ''}${variacion.toStringAsFixed(1)}%',
                      danger: variacion > 0,
                      success: variacion < 0,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _ProductoMetaCard(
                  creado: creado,
                  ultimoIngreso: ultimaEntrada == null
                      ? null
                      : _fechaMovimiento(ultimaEntrada),
                  unidad: _str(material, 'unidadMedida', 'unidad_medida'),
                  activo: _bool(material, 'activo', fallback: true),
                  fmtDate: fmtDate,
                ),
                const SizedBox(height: 14),
                _PrecioChartCard(
                  puntos: puntos,
                  fmtMoney: fmtMoney,
                  fmtDate: fmtDate,
                ),
                const SizedBox(height: 14),
                Text(
                  'Historial de ingresos (${movimientos.length})',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: TecneroTheme.azulOscuro,
                  ),
                ),
                const SizedBox(height: 8),
                if (movimientos.isEmpty)
                  const _EmptyInline(
                    icon: Icons.history_outlined,
                    text: 'Aún no hay ingresos registrados para este producto.',
                  )
                else
                  ...movimientos.map((m) => _MovimientoProductoTile(
                      movimiento: m, fmtMoney: fmtMoney)),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

class _DetalleMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool danger;
  final bool success;

  const _DetalleMetric({
    required this.icon,
    required this.label,
    required this.value,
    this.danger = false,
    this.success = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger
        ? const Color(0xFFDC2626)
        : success
            ? const Color(0xFF059669)
            : TecneroTheme.azulOscuro;
    final bg = danger
        ? const Color(0xFFFEE2E2)
        : success
            ? const Color(0xFFD1FAE5)
            : Colors.white;

    return Container(
      width: Responsive.isMobile(context) ? double.infinity : 195,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
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
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
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

class _ProductoMetaCard extends StatelessWidget {
  final DateTime? creado;
  final DateTime? ultimoIngreso;
  final String unidad;
  final bool activo;
  final DateFormat fmtDate;

  const _ProductoMetaCard({
    required this.creado,
    required this.ultimoIngreso,
    required this.unidad,
    required this.activo,
    required this.fmtDate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: TecneroTheme.grisBorde),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _MiniInfo('Creado',
              creado == null ? 'No registrado' : fmtDate.format(creado!)),
          _MiniInfo(
              'Último ingreso',
              ultimoIngreso == null
                  ? 'Sin ingresos'
                  : fmtDate.format(ultimoIngreso!)),
          _MiniInfo('Unidad', unidad.isEmpty ? 'No registrada' : unidad),
          _MiniInfo('Estado', activo ? 'Activo' : 'Inactivo'),
        ],
      ),
    );
  }
}

class _PrecioChartCard extends StatelessWidget {
  final List<_PrecioPoint> puntos;
  final NumberFormat fmtMoney;
  final DateFormat fmtDate;

  const _PrecioChartCard({
    required this.puntos,
    required this.fmtMoney,
    required this.fmtDate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: TecneroTheme.grisBorde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.show_chart_outlined,
                  size: 18, color: TecneroTheme.azulOscuro),
              SizedBox(width: 8),
              Text(
                'Evolución de precio',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: TecneroTheme.azulOscuro,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (puntos.length < 2)
            const _EmptyInline(
              icon: Icons.show_chart_outlined,
              text:
                  'Registra más ingresos o cambios de precio para ver la tendencia.',
            )
          else ...[
            SizedBox(
              height: 180,
              width: double.infinity,
              child: CustomPaint(
                painter: _PrecioChartPainter(puntos: puntos),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${fmtDate.format(puntos.first.fecha)} · ${fmtMoney.format(puntos.first.precio)}',
                  style: const TextStyle(
                      fontSize: 11, color: TecneroTheme.textoSecundario),
                ),
                Text(
                  '${fmtDate.format(puntos.last.fecha)} · ${fmtMoney.format(puntos.last.precio)}',
                  style: const TextStyle(
                      fontSize: 11, color: TecneroTheme.textoSecundario),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PrecioChartPainter extends CustomPainter {
  final List<_PrecioPoint> puntos;

  _PrecioChartPainter({required this.puntos});

  @override
  void paint(Canvas canvas, Size size) {
    if (puntos.length < 2) return;

    const paddingLeft = 36.0;
    const paddingTop = 12.0;
    const paddingRight = 12.0;
    const paddingBottom = 26.0;

    final chart = Rect.fromLTWH(
      paddingLeft,
      paddingTop,
      size.width - paddingLeft - paddingRight,
      size.height - paddingTop - paddingBottom,
    );

    final prices = puntos.map((p) => p.precio).toList();
    var minPrice = prices.reduce(math.min);
    var maxPrice = prices.reduce(math.max);
    if (minPrice == maxPrice) {
      minPrice = math.max(0, minPrice - 1);
      maxPrice = maxPrice + 1;
    }

    final gridPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 1;
    final axisPaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 1.2;
    final linePaint = Paint()
      ..color = TecneroTheme.azulOscuro
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final fillPaint = Paint()
      ..color = TecneroTheme.azulOscuro.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    final dotPaint = Paint()
      ..color = TecneroTheme.naranja
      ..style = PaintingStyle.fill;

    for (var i = 0; i <= 3; i++) {
      final y = chart.top + chart.height * i / 3;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
    }

    canvas.drawLine(Offset(chart.left, chart.top),
        Offset(chart.left, chart.bottom), axisPaint);
    canvas.drawLine(Offset(chart.left, chart.bottom),
        Offset(chart.right, chart.bottom), axisPaint);

    Offset pointAt(int index) {
      final p = puntos[index];
      final x = chart.left + (chart.width * index / (puntos.length - 1));
      final normalized = (p.precio - minPrice) / (maxPrice - minPrice);
      final y = chart.bottom - normalized * chart.height;
      return Offset(x, y);
    }

    final path = Path();
    final area = Path();
    for (var i = 0; i < puntos.length; i++) {
      final point = pointAt(i);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
        area.moveTo(point.dx, chart.bottom);
        area.lineTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
        area.lineTo(point.dx, point.dy);
      }
    }
    area.lineTo(chart.right, chart.bottom);
    area.close();

    canvas.drawPath(area, fillPaint);
    canvas.drawPath(path, linePaint);

    for (var i = 0; i < puntos.length; i++) {
      final point = pointAt(i);
      canvas.drawCircle(point, 4, dotPaint);
    }

    void drawText(String text, Offset offset,
        {TextAlign align = TextAlign.left}) {
      final span = TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: 10,
          color: Color(0xFF64748B),
        ),
      );

      final tp = TextPainter(
        text: span,
        textDirection: ui.TextDirection.ltr,
        textAlign: align,
      )..layout();

      tp.paint(canvas, offset);
    }

    drawText('\$${maxPrice.toStringAsFixed(2)}', Offset(0, chart.top - 4));
    drawText('\$${minPrice.toStringAsFixed(2)}', Offset(0, chart.bottom - 10));
  }

  @override
  bool shouldRepaint(covariant _PrecioChartPainter oldDelegate) {
    return oldDelegate.puntos != puntos;
  }
}

class _MovimientoProductoTile extends StatelessWidget {
  final Map<String, dynamic> movimiento;
  final NumberFormat fmtMoney;

  const _MovimientoProductoTile({
    required this.movimiento,
    required this.fmtMoney,
  });

  @override
  Widget build(BuildContext context) {
    final fecha = _fechaMovimiento(movimiento);
    final fmt = DateFormat('dd/MM/yyyy HH:mm');
    final cantidad = _num(movimiento, 'cantidad');
    final precio = _num(movimiento, 'precioUnitario', 'precio_unitario');
    final stockAnterior = _num(movimiento, 'stockAnterior', 'stock_anterior');
    final stockNuevo = _num(movimiento, 'stockNuevo', 'stock_nuevo');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: TecneroTheme.grisBorde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add_box_outlined,
                    size: 16, color: Color(0xFF047857)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Ingreso de ${_formatCantidad(cantidad)} ${_str(movimiento, 'unidadMedida', 'unidad_medida')}',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                fmt.format(fecha),
                style: const TextStyle(
                    fontSize: 10, color: TecneroTheme.textoSecundario),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _MiniInfo('Precio', fmtMoney.format(precio)),
              _MiniInfo('Stock',
                  '${_formatCantidad(stockAnterior)} → ${_formatCantidad(stockNuevo)}'),
              _MiniInfo('Registró',
                  _str(movimiento, 'registradoPor', 'registrado_por')),
            ],
          ),
          if (_str(movimiento, 'observaciones').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Obs: ${_str(movimiento, 'observaciones')}',
              style: const TextStyle(
                  fontSize: 11, color: TecneroTheme.textoSecundario),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyInline extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptyInline({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TecneroTheme.grisClaro,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: TecneroTheme.grisBorde),
      ),
      child: Row(
        children: [
          Icon(icon, color: TecneroTheme.textoSecundario),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  fontSize: 12, color: TecneroTheme.textoSecundario),
            ),
          ),
        ],
      ),
    );
  }
}

class _IngresoItem {
  final Map<String, dynamic> material;
  final TextEditingController cantidadCtrl;
  final TextEditingController precioCtrl;

  _IngresoItem({required this.material})
      : cantidadCtrl = TextEditingController(),
        precioCtrl =
            TextEditingController(text: _precio(material)?.toString() ?? '');

  void dispose() {
    cantidadCtrl.dispose();
    precioCtrl.dispose();
  }
}

class _IngresoInventarioDialog extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> materiales;

  const _IngresoInventarioDialog({required this.materiales});

  @override
  ConsumerState<_IngresoInventarioDialog> createState() =>
      _IngresoInventarioDialogState();
}

class _IngresoInventarioDialogState
    extends ConsumerState<_IngresoInventarioDialog> {
  final _obsCtrl = TextEditingController();
  final List<_IngresoItem> _items = [];
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _obsCtrl.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _seleccionarProductos() async {
    final seleccion = await showDialog<List<Map<String, dynamic>>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SelectorProductosIngresoDialog(
        materiales: widget.materiales
            .where((m) => _bool(m, 'activo', fallback: true))
            .toList(),
        seleccionInicial: _items.map((i) => i.material).toList(),
      ),
    );

    if (seleccion == null) return;

    final nuevos = <_IngresoItem>[];

    for (final material in seleccion) {
      final actual = _items
          .where((item) => _str(item.material, 'id') == _str(material, 'id'));
      nuevos.add(
          actual.isNotEmpty ? actual.first : _IngresoItem(material: material));
    }

    for (final item in _items) {
      final sigue = nuevos.any(
          (nuevo) => _str(nuevo.material, 'id') == _str(item.material, 'id'));
      if (!sigue) item.dispose();
    }

    setState(() {
      _items
        ..clear()
        ..addAll(nuevos);
      _error = null;
    });
  }

  Future<void> _guardar() async {
    if (_items.isEmpty) {
      setState(() => _error = 'Selecciona al menos un producto');
      return;
    }

    final payload = <Map<String, dynamic>>[];

    for (final item in _items) {
      final cantidad =
          double.tryParse(item.cantidadCtrl.text.replaceAll(',', '.'));
      final precio = double.tryParse(item.precioCtrl.text.replaceAll(',', '.'));

      if (cantidad == null || cantidad <= 0) {
        setState(() =>
            _error = 'Revisa la cantidad de ${_str(item.material, 'nombre')}');
        return;
      }

      if (precio == null || precio <= 0) {
        setState(() =>
            _error = 'Revisa el precio de ${_str(item.material, 'nombre')}');
        return;
      }

      payload.add({
        'materialId': _str(item.material, 'id'),
        'cantidad': cantidad,
        'precio': precio,
      });
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      await ref.read(apiServiceProvider).registrarIngresoInventario(
            items: payload,
            observaciones:
                _obsCtrl.text.trim().isEmpty ? null : _obsCtrl.text.trim(),
          );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
      contentPadding: const EdgeInsets.fromLTRB(22, 12, 22, 8),
      actionsPadding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
      title: const Text('Registrar ingreso de inventario'),
      content: SizedBox(
        width: isMobile ? MediaQuery.sizeOf(context).width * 0.92 : 860,
        height: isMobile ? MediaQuery.sizeOf(context).height * 0.72 : 620,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _guardando ? null : _seleccionarProductos,
                    icon: const Icon(Icons.playlist_add_check, size: 18),
                    label: Text(_items.isEmpty
                        ? 'Seleccionar productos'
                        : 'Editar selección (${_items.length})'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _items.isEmpty
                  ? const _IngresoVacio()
                  : ListView.builder(
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return _IngresoItemCard(
                          item: item,
                          onRemove: _guardando
                              ? null
                              : () {
                                  setState(() {
                                    _items.removeAt(index);
                                    item.dispose();
                                  });
                                },
                        );
                      },
                    ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _obsCtrl,
              enabled: !_guardando,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Observaciones del ingreso',
                hintText: 'Ej: Compra proveedor, factura, guía...',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              _ErrorBox(_error!),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          onPressed: _guardando ? null : _guardar,
          icon: _guardando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.save_outlined, size: 18),
          label: Text(_guardando ? 'Guardando...' : 'Guardar ingreso'),
        ),
      ],
    );
  }
}

class _IngresoVacio extends StatelessWidget {
  const _IngresoVacio();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.playlist_add_outlined,
              size: 44, color: Colors.grey.shade300),
          const SizedBox(height: 10),
          const Text(
            'Selecciona los productos que ingresaron a bodega',
            textAlign: TextAlign.center,
            style: TextStyle(color: TecneroTheme.textoSecundario),
          ),
        ],
      ),
    );
  }
}

class _IngresoItemCard extends StatelessWidget {
  final _IngresoItem item;
  final VoidCallback? onRemove;

  const _IngresoItemCard({required this.item, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final material = item.material;
    final precioActual = _precio(material);
    final style = _categoriaStyle(_str(material, 'categoria'));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: style.color.withValues(alpha: 0.35)),
      ),
      child: Responsive.isMobile(context)
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _IngresoMaterialInfo(material: material),
                const SizedBox(height: 10),
                _IngresoInputs(item: item, precioActual: precioActual),
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
                Expanded(child: _IngresoMaterialInfo(material: material)),
                const SizedBox(width: 12),
                SizedBox(
                  width: 310,
                  child: _IngresoInputs(item: item, precioActual: precioActual),
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

class _IngresoMaterialInfo extends StatelessWidget {
  final Map<String, dynamic> material;

  const _IngresoMaterialInfo({required this.material});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _str(material, 'nombre'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
            _CategoriaBadge(categoria: _str(material, 'categoria')),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            Text(
              _str(material, 'codigo'),
              style: const TextStyle(
                  fontSize: 11, color: TecneroTheme.textoSecundario),
            ),
            Text(
              'Stock: ${_formatCantidad(_num(material, 'stockActual', 'stock_actual'))}',
              style: const TextStyle(
                  fontSize: 11, color: TecneroTheme.textoSecundario),
            ),
            Text(
              _str(material, 'unidadMedida', 'unidad_medida'),
              style: const TextStyle(
                  fontSize: 11, color: TecneroTheme.textoSecundario),
            ),
          ],
        ),
      ],
    );
  }
}

class _IngresoInputs extends StatelessWidget {
  final _IngresoItem item;
  final double? precioActual;

  const _IngresoInputs({required this.item, required this.precioActual});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: item.cantidadCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Cantidad que ingresa',
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: item.precioCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Precio unitario',
              prefixText: '\$ ',
              helperText: precioActual == null
                  ? 'Sin precio actual'
                  : 'Actual: ${precioActual!.toStringAsFixed(2)}',
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          ),
        ),
      ],
    );
  }
}

class _SelectorProductosIngresoDialog extends StatefulWidget {
  final List<Map<String, dynamic>> materiales;
  final List<Map<String, dynamic>> seleccionInicial;

  const _SelectorProductosIngresoDialog({
    required this.materiales,
    required this.seleccionInicial,
  });

  @override
  State<_SelectorProductosIngresoDialog> createState() =>
      _SelectorProductosIngresoDialogState();
}

class _SelectorProductosIngresoDialogState
    extends State<_SelectorProductosIngresoDialog> {
  final _buscarCtrl = TextEditingController();
  final Set<String> _ids = {};
  String _categoriaFiltro = 'todos';

  @override
  void initState() {
    super.initState();
    _ids.addAll(widget.seleccionInicial.map((m) => _str(m, 'id')));
  }

  @override
  void dispose() {
    _buscarCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtrados {
    final q = _buscarCtrl.text.trim().toLowerCase();
    return widget.materiales.where((m) {
      final categoria = _str(m, 'categoria');
      final texto = '${_str(m, 'codigo')} ${_str(m, 'nombre')}'.toLowerCase();
      final matchCategoria =
          _categoriaFiltro == 'todos' || categoria == _categoriaFiltro;
      final matchTexto = q.isEmpty || texto.contains(q);
      return matchCategoria && matchTexto;
    }).toList()
      ..sort((a, b) => _str(a, 'nombre').compareTo(_str(b, 'nombre')));
  }

  @override
  Widget build(BuildContext context) {
    final filtrados = _filtrados;
    final isMobile = Responsive.isMobile(context);

    return AlertDialog(
      title: const Text('Seleccionar productos'),
      content: SizedBox(
        width: isMobile ? MediaQuery.sizeOf(context).width * 0.92 : 720,
        height: isMobile ? MediaQuery.sizeOf(context).height * 0.72 : 560,
        child: Column(
          children: [
            TextField(
              controller: _buscarCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Buscar producto o código...',
                prefixIcon: Icon(Icons.search, size: 18),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _CategoriaFilterChip(
                    label: 'Todos',
                    value: 'todos',
                    selected: _categoriaFiltro == 'todos',
                    onSelected: (value) =>
                        setState(() => _categoriaFiltro = value)),
                _CategoriaFilterChip(
                    label: 'Producción',
                    value: 'produccion',
                    selected: _categoriaFiltro == 'produccion',
                    onSelected: (value) =>
                        setState(() => _categoriaFiltro = value)),
                _CategoriaFilterChip(
                    label: 'EPP',
                    value: 'epp',
                    selected: _categoriaFiltro == 'epp',
                    onSelected: (value) =>
                        setState(() => _categoriaFiltro = value)),
                _CategoriaFilterChip(
                    label: 'Mantenimiento',
                    value: 'mantenimiento',
                    selected: _categoriaFiltro == 'mantenimiento',
                    onSelected: (value) =>
                        setState(() => _categoriaFiltro = value)),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: filtrados.isEmpty
                  ? const Center(child: Text('Sin resultados'))
                  : ListView.separated(
                      itemCount: filtrados.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final material = filtrados[index];
                        final id = _str(material, 'id');
                        final selected = _ids.contains(id);
                        final style =
                            _categoriaStyle(_str(material, 'categoria'));

                        return CheckboxListTile(
                          value: selected,
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                _ids.add(id);
                              } else {
                                _ids.remove(id);
                              }
                            });
                          },
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _str(material, 'nombre'),
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _CategoriaBadge(
                                  categoria: _str(material, 'categoria')),
                            ],
                          ),
                          subtitle: Text(
                              '${_str(material, 'codigo')} · Stock: ${_formatCantidad(_num(material, 'stockActual', 'stock_actual'))}'),
                          activeColor: style.color,
                          controlAffinity: ListTileControlAffinity.leading,
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
            final seleccion = widget.materiales
                .where((m) => _ids.contains(_str(m, 'id')))
                .toList();
            Navigator.pop(context, seleccion);
          },
          icon: const Icon(Icons.check, size: 18),
          label: Text('Confirmar (${_ids.length})'),
        ),
      ],
    );
  }
}

class _CategoriaFilterChip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final ValueChanged<String> onSelected;

  const _CategoriaFilterChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final style = _categoriaStyle(value);
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(value),
      selectedColor: value == 'todos' ? TecneroTheme.azulOscuro : style.bg,
      checkmarkColor: value == 'todos' ? Colors.white : style.color,
      side: BorderSide(
          color: value == 'todos'
              ? TecneroTheme.grisBorde
              : style.color.withValues(alpha: 0.35)),
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: selected
            ? (value == 'todos' ? Colors.white : style.color)
            : TecneroTheme.textoPrimario,
      ),
    );
  }
}

class _HistorialIngresosDialog extends ConsumerWidget {
  const _HistorialIngresosDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historial = ref.watch(historialIngresosInventarioProvider);
    final isMobile = Responsive.isMobile(context);

    return AlertDialog(
      title: const Text('Historial de ingresos'),
      content: SizedBox(
        width: isMobile ? MediaQuery.sizeOf(context).width * 0.92 : 820,
        height: isMobile ? MediaQuery.sizeOf(context).height * 0.72 : 620,
        child: historial.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (lista) {
            if (lista.isEmpty) {
              return const Center(
                child: Text(
                  'Aún no hay ingresos registrados',
                  style: TextStyle(color: TecneroTheme.textoSecundario),
                ),
              );
            }

            final grupos = _agruparMovimientosPorDia(lista);
            return ListView(
              children: grupos.entries
                  .map((entry) => _HistorialDiaSection(
                      fecha: entry.key, movimientos: entry.value))
                  .toList(),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

class _HistorialDiaSection extends StatelessWidget {
  final DateTime fecha;
  final List<Map<String, dynamic>> movimientos;

  const _HistorialDiaSection({
    required this.fecha,
    required this.movimientos,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy HH:mm');
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _labelDia(fecha),
              style: const TextStyle(
                  fontWeight: FontWeight.w800, color: TecneroTheme.azulOscuro),
            ),
          ),
          ...movimientos.map((m) {
            final cantidad = _num(m, 'cantidad');
            final precio = _num(m, 'precioUnitario', 'precio_unitario');
            final fecha = _fechaMovimiento(m);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: TecneroTheme.grisBorde),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _str(m, 'materialNombre', 'material_nombre'),
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        fmt.format(fecha),
                        style: const TextStyle(
                            fontSize: 10, color: TecneroTheme.textoSecundario),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 5,
                    children: [
                      _MiniInfo('Código',
                          _str(m, 'materialCodigo', 'material_codigo')),
                      _MiniInfo('Ingresó',
                          '${_formatCantidad(cantidad)} ${_str(m, 'unidadMedida', 'unidad_medida')}'),
                      _MiniInfo('Precio', '\$${precio.toStringAsFixed(2)}'),
                      _MiniInfo('Stock',
                          '${_formatCantidad(_num(m, 'stockAnterior', 'stock_anterior'))} → ${_formatCantidad(_num(m, 'stockNuevo', 'stock_nuevo'))}'),
                      _MiniInfo('Registró',
                          _str(m, 'registradoPor', 'registrado_por')),
                    ],
                  ),
                  if (_str(m, 'observaciones').isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Obs: ${_str(m, 'observaciones')}',
                      style: const TextStyle(
                          fontSize: 11, color: TecneroTheme.textoSecundario),
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
}

class _MiniInfo extends StatelessWidget {
  final String label;
  final String value;

  const _MiniInfo(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: TecneroTheme.grisClaro,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: TecneroTheme.textoPrimario,
        ),
      ),
    );
  }
}

class _MaterialDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic>? material;

  const _MaterialDialog({this.material});

  @override
  ConsumerState<_MaterialDialog> createState() => _MaterialDialogState();
}

class _MaterialDialogState extends ConsumerState<_MaterialDialog> {
  late final TextEditingController _codigoCtrl;
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _unidadCtrl;
  late final TextEditingController _stockCtrl;
  late final TextEditingController _stockMinimoCtrl;
  late final TextEditingController _precioCtrl;
  late String _categoria;
  late bool _activo;
  bool _guardando = false;
  String? _error;

  bool get _editando => widget.material != null;

  @override
  void initState() {
    super.initState();
    final m = widget.material;
    _codigoCtrl =
        TextEditingController(text: m == null ? '' : _str(m, 'codigo'));
    _nombreCtrl =
        TextEditingController(text: m == null ? '' : _str(m, 'nombre'));
    _unidadCtrl = TextEditingController(
        text: m == null ? '' : _str(m, 'unidadMedida', 'unidad_medida'));
    _stockCtrl = TextEditingController(
        text: m == null
            ? '0'
            : _formatCantidad(_num(m, 'stockActual', 'stock_actual')));
    _stockMinimoCtrl = TextEditingController(
        text: m == null ? '5' : _formatCantidad(_stockMinimoAlerta(m)));
    _precioCtrl = TextEditingController();
    _categoria = m == null ? 'produccion' : _str(m, 'categoria');
    _activo = m == null ? true : _bool(m, 'activo', fallback: true);
  }

  @override
  void dispose() {
    _codigoCtrl.dispose();
    _nombreCtrl.dispose();
    _unidadCtrl.dispose();
    _stockCtrl.dispose();
    _stockMinimoCtrl.dispose();
    _precioCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final stock = double.tryParse(_stockCtrl.text.replaceAll(',', '.')) ?? 0;
    final stockMinimo =
        double.tryParse(_stockMinimoCtrl.text.replaceAll(',', '.')) ?? 5;
    final precio = _precioCtrl.text.trim().isEmpty
        ? null
        : double.tryParse(_precioCtrl.text.replaceAll(',', '.'));

    if (_codigoCtrl.text.trim().isEmpty ||
        _nombreCtrl.text.trim().isEmpty ||
        _unidadCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Completa código, nombre y unidad');
      return;
    }

    if (!_editando && stock < 0) {
      setState(() => _error = 'El stock inicial no puede ser negativo');
      return;
    }

    if (stockMinimo < 0) {
      setState(() => _error = 'El aviso de stock bajo no puede ser negativo');
      return;
    }

    if (!_editando && _precioCtrl.text.trim().isNotEmpty && precio == null) {
      setState(() => _error = 'Ingresa un precio inicial válido');
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      if (_editando) {
        await ref.read(apiServiceProvider).actualizarMaterial(
              id: _str(widget.material!, 'id'),
              codigo: _codigoCtrl.text.trim(),
              nombre: _nombreCtrl.text.trim(),
              unidadMedida: _unidadCtrl.text.trim(),
              categoria: _categoria,
              stockMinimoAlerta: stockMinimo,
              activo: _activo,
            );
      } else {
        await ref.read(apiServiceProvider).crearMaterial(
              codigo: _codigoCtrl.text.trim(),
              nombre: _nombreCtrl.text.trim(),
              unidadMedida: _unidadCtrl.text.trim(),
              categoria: _categoria,
              stockActual: stock,
              stockMinimoAlerta: stockMinimo,
              precio: precio,
            );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    return AlertDialog(
      title: Text(_editando ? 'Editar producto' : 'Nuevo producto'),
      content: SizedBox(
        width: isMobile ? MediaQuery.sizeOf(context).width * 0.9 : 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _codigoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Código',
                  prefixIcon: Icon(Icons.qr_code_2_outlined, size: 18),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _nombreCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre del producto',
                  prefixIcon: Icon(Icons.inventory_2_outlined, size: 18),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _unidadCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Unidad',
                          hintText: 'kg, unidad, metro...'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _categoria,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Categoría'),
                      items: const [
                        DropdownMenuItem(
                            value: 'produccion', child: Text('Producción')),
                        DropdownMenuItem(value: 'epp', child: Text('EPP')),
                        DropdownMenuItem(
                            value: 'mantenimiento',
                            child: Text('Mantenimiento')),
                      ],
                      onChanged: _guardando
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() => _categoria = value);
                              }
                            },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _CategoriaPreview(categoria: _categoria),
              const SizedBox(height: 10),
              TextField(
                controller: _stockMinimoCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Avisar stock <=',
                  helperText:
                      'El admin recibirá una notificación al llegar a este stock.',
                  prefixIcon:
                      Icon(Icons.notifications_active_outlined, size: 18),
                ),
              ),
              if (!_editando) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _stockCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Stock inicial',
                          prefixIcon: Icon(Icons.add_box_outlined, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _precioCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                            labelText: 'Precio inicial', prefixText: '\$ '),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                const SizedBox(height: 10),
                SwitchListTile(
                  value: _activo,
                  onChanged: _guardando
                      ? null
                      : (value) => setState(() => _activo = value),
                  title: const Text('Producto activo'),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                _ErrorBox(_error!),
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
          onPressed: _guardando ? null : _guardar,
          icon: _guardando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.save_outlined, size: 18),
          label: Text(_guardando ? 'Guardando...' : 'Guardar'),
        ),
      ],
    );
  }
}

class _ConfigAlertasStockDialog extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> materiales;

  const _ConfigAlertasStockDialog({
    required this.materiales,
  });

  @override
  ConsumerState<_ConfigAlertasStockDialog> createState() =>
      _ConfigAlertasStockDialogState();
}

class _ConfigAlertasStockDialogState
    extends ConsumerState<_ConfigAlertasStockDialog> {
  final Map<String, TextEditingController> _controllers = {};
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final material in widget.materiales) {
      final id = _str(material, 'id');
      if (id.isEmpty) continue;
      _controllers[id] = TextEditingController(
        text: _formatCantidad(_stockMinimoAlerta(material)),
      );
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    final cambios = <Map<String, dynamic>>[];

    for (final material in widget.materiales) {
      final id = _str(material, 'id');
      final controller = _controllers[id];
      if (id.isEmpty || controller == null) continue;

      final valor = double.tryParse(controller.text.replaceAll(',', '.'));
      if (valor == null || valor < 0) {
        setState(
          () => _error =
              'Revisa "${_str(material, 'nombre')}": el umbral debe ser 0 o mayor.',
        );
        return;
      }

      if (valor != _stockMinimoAlerta(material)) {
        cambios.add({
          'material': material,
          'stockMinimo': valor,
        });
      }
    }

    if (cambios.isEmpty) {
      if (mounted) Navigator.pop(context, false);
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      final api = ref.read(apiServiceProvider);
      for (final cambio in cambios) {
        final material = cambio['material'] as Map<String, dynamic>;
        await api.actualizarMaterial(
          id: _str(material, 'id'),
          codigo: _str(material, 'codigo'),
          nombre: _str(material, 'nombre'),
          unidadMedida: _str(material, 'unidadMedida', 'unidad_medida'),
          categoria: _str(material, 'categoria'),
          stockMinimoAlerta: cambio['stockMinimo'] as double,
          activo: _bool(material, 'activo', fallback: true),
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final materiales = widget.materiales
        .where((m) => _bool(m, 'activo', fallback: true))
        .toList()
      ..sort((a, b) => _str(a, 'nombre').compareTo(_str(b, 'nombre')));

    return AlertDialog(
      title: const Text('Configurar alertas de stock'),
      content: SizedBox(
        width: isMobile ? MediaQuery.sizeOf(context).width * 0.9 : 720,
        height: isMobile ? MediaQuery.sizeOf(context).height * 0.72 : 560,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFED7AA)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.notifications_active_outlined,
                    color: TecneroTheme.naranja,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'El admin recibirá una notificación cuando un despacho deje el stock en el umbral configurado o por debajo.',
                      style: TextStyle(
                        fontSize: 12,
                        color: TecneroTheme.textoPrimario,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: materiales.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final material = materiales[index];
                  final id = _str(material, 'id');
                  final stock = _num(material, 'stockActual', 'stock_actual');
                  final unidad =
                      _str(material, 'unidadMedida', 'unidad_medida');
                  final stockBajo = stock <= _stockMinimoAlerta(material);

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: stockBajo
                          ? const Color(0xFFFFFBEB)
                          : TecneroTheme.grisClaro,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: stockBajo
                            ? const Color(0xFFFCD34D)
                            : TecneroTheme.grisBorde,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          stockBajo
                              ? Icons.warning_amber_outlined
                              : Icons.inventory_2_outlined,
                          color: stockBajo
                              ? const Color(0xFFF59E0B)
                              : TecneroTheme.azulOscuro,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _str(material, 'nombre'),
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_str(material, 'codigo')} · Stock actual: ${_formatCantidad(stock)} $unidad',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: TecneroTheme.textoSecundario,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: isMobile ? 92 : 130,
                          child: TextField(
                            controller: _controllers[id],
                            enabled: !_guardando,
                            textAlign: TextAlign.right,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Avisar <=',
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _ErrorBox(_error!),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context, false),
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
              : const Icon(Icons.save_outlined, size: 18),
          label: Text(_guardando ? 'Guardando...' : 'Guardar alertas'),
        ),
      ],
    );
  }
}

class _CategoriaPreview extends StatelessWidget {
  final String categoria;

  const _CategoriaPreview({required this.categoria});

  @override
  Widget build(BuildContext context) {
    final style = _categoriaStyle(categoria);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: style.color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(style.icon, color: style.color, size: 18),
          const SizedBox(width: 8),
          Text(
            'Etiqueta: ${style.label}',
            style: TextStyle(color: style.color, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _PrecioDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic> material;

  const _PrecioDialog({required this.material});

  @override
  ConsumerState<_PrecioDialog> createState() => _PrecioDialogState();
}

class _PrecioDialogState extends ConsumerState<_PrecioDialog> {
  late final TextEditingController _precioCtrl;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final precio = _precio(widget.material);
    _precioCtrl = TextEditingController(text: precio?.toString() ?? '');
  }

  @override
  void dispose() {
    _precioCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final precio = double.tryParse(_precioCtrl.text.replaceAll(',', '.'));
    if (precio == null || precio <= 0) {
      setState(() => _error = 'Ingresa un precio válido');
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      final usuario = await ref.read(apiServiceProvider).getUsuarioActual();
      await ref.read(apiServiceProvider).actualizarPrecio(
            materialId: _str(widget.material, 'id'),
            nuevoPrecio: precio,
            registradoPor: usuario?.nombre ?? 'Compras',
          );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Actualizar precio'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_str(widget.material, 'nombre'),
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          TextField(
            controller: _precioCtrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
                labelText: 'Nuevo precio', prefixText: '\$ '),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _ErrorBox(_error!),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          onPressed: _guardando ? null : _guardar,
          icon: const Icon(Icons.save_outlined, size: 18),
          label: const Text('Guardar precio'),
        ),
      ],
    );
  }
}

class _StockDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic> material;

  const _StockDialog({required this.material});

  @override
  ConsumerState<_StockDialog> createState() => _StockDialogState();
}

class _StockDialogState extends ConsumerState<_StockDialog> {
  final _cantidadCtrl = TextEditingController();
  late final TextEditingController _precioCtrl;
  final _obsCtrl = TextEditingController();
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _precioCtrl =
        TextEditingController(text: _precio(widget.material)?.toString() ?? '');
  }

  @override
  void dispose() {
    _cantidadCtrl.dispose();
    _precioCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final cantidad = double.tryParse(_cantidadCtrl.text.replaceAll(',', '.'));
    final precio = double.tryParse(_precioCtrl.text.replaceAll(',', '.'));

    if (cantidad == null || cantidad <= 0) {
      setState(() => _error = 'Ingresa una cantidad válida');
      return;
    }

    if (precio == null || precio <= 0) {
      setState(() => _error = 'Ingresa un precio válido');
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      await ref.read(apiServiceProvider).registrarIngresoInventario(
        observaciones:
            _obsCtrl.text.trim().isEmpty ? null : _obsCtrl.text.trim(),
        items: [
          {
            'materialId': _str(widget.material, 'id'),
            'cantidad': cantidad,
            'precio': precio,
          },
        ],
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stock = _num(widget.material, 'stockActual', 'stock_actual');

    return AlertDialog(
      title: const Text('Agregar más inventario'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_str(widget.material, 'nombre'),
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                'Stock actual: ${_formatCantidad(stock)}',
                style: const TextStyle(
                    fontSize: 12, color: TecneroTheme.textoSecundario),
              ),
              const SizedBox(width: 8),
              _CategoriaBadge(categoria: _str(widget.material, 'categoria')),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _cantidadCtrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Cantidad que ingresa',
              prefixIcon: Icon(Icons.add_box_outlined, size: 18),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _precioCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
                labelText: 'Precio unitario', prefixText: '\$ '),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _obsCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
                labelText: 'Observación',
                hintText: 'Factura, proveedor, guía...'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _ErrorBox(_error!),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          onPressed: _guardando ? null : _guardar,
          icon: const Icon(Icons.save_outlined, size: 18),
          label: const Text('Guardar ingreso'),
        ),
      ],
    );
  }
}

class _CategoriaBadge extends StatelessWidget {
  final String categoria;

  const _CategoriaBadge({required this.categoria});

  @override
  Widget build(BuildContext context) {
    final data = _categoriaStyle(categoria);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: data.bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: data.color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(data.icon, size: 11, color: data.color),
          const SizedBox(width: 4),
          Text(
            data.label,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w800, color: data.color),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color background;

  const _StatusBadge({
    required this.label,
    this.color = const Color(0xFF64748B),
    this.background = const Color(0xFFE2E8F0),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style:
            TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;

  const _ErrorBox(this.message);

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
        style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B)),
      ),
    );
  }
}

class _EmptyCompras extends StatelessWidget {
  const _EmptyCompras();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          const Text(
            'No hay productos para mostrar',
            style: TextStyle(color: TecneroTheme.textoSecundario),
          ),
        ],
      ),
    );
  }
}

class _CategoriaStyle {
  final String label;
  final Color bg;
  final Color color;
  final IconData icon;

  const _CategoriaStyle({
    required this.label,
    required this.bg,
    required this.color,
    required this.icon,
  });
}

_CategoriaStyle _categoriaStyle(String categoria) {
  return switch (categoria) {
    'produccion' => const _CategoriaStyle(
        label: 'Producción',
        bg: Color(0xFFDBEAFE),
        color: Color(0xFF1D4ED8),
        icon: Icons.precision_manufacturing_outlined,
      ),
    'epp' => const _CategoriaStyle(
        label: 'EPP',
        bg: Color(0xFFFEF3C7),
        color: Color(0xFFD97706),
        icon: Icons.health_and_safety_outlined,
      ),
    'mantenimiento' => const _CategoriaStyle(
        label: 'Mantenimiento',
        bg: Color(0xFFEDE9FE),
        color: Color(0xFF6D28D9),
        icon: Icons.handyman_outlined,
      ),
    _ => const _CategoriaStyle(
        label: 'Sin categoría',
        bg: Color(0xFFF3F4F6),
        color: Color(0xFF374151),
        icon: Icons.category_outlined,
      ),
  };
}

class _PrecioPoint {
  final DateTime fecha;
  final double precio;

  const _PrecioPoint({required this.fecha, required this.precio});
}

String _str(Map<String, dynamic> map, String key, [String? alt]) {
  return (map[key] ?? (alt == null ? null : map[alt]) ?? '').toString();
}

double _num(Map<String, dynamic> map, String key, [String? alt]) {
  return double.tryParse(
          (map[key] ?? (alt == null ? null : map[alt]) ?? 0).toString()) ??
      0;
}

double _stockMinimoAlerta(Map<String, dynamic> map) {
  return double.tryParse(
        (map['stockMinimoAlerta'] ?? map['stock_minimo_alerta'] ?? 5)
            .toString(),
      ) ??
      5;
}

bool _bool(Map<String, dynamic> map, String key, {bool fallback = false}) {
  final value = map[key];
  if (value is bool) return value;
  if (value == null) return fallback;
  return value.toString() == 'true';
}

double? _precio(Map<String, dynamic> map) {
  final value = map['precioActual'] ?? map['precio_actual'];
  if (value == null) return null;
  return double.tryParse(value.toString());
}

DateTime? _fechaPrecio(Map<String, dynamic> map) {
  final value = map['precioFechaVigencia'] ??
      map['precio_fecha_vigencia'] ??
      map['fechaVigencia'] ??
      map['fecha_vigencia'];
  if (value == null) return null;
  return DateTime.tryParse(value.toString())?.toLocal();
}

DateTime? _fechaCreacion(Map<String, dynamic> map) {
  final value = map['createdAt'] ??
      map['created_at'] ??
      map['fechaCreacion'] ??
      map['fecha_creacion'] ??
      map['creadoEn'] ??
      map['creado_en'];
  if (value == null) return null;
  return DateTime.tryParse(value.toString())?.toLocal();
}

DateTime _fechaMovimiento(Map<String, dynamic> map) {
  final value = map['fecha'] ??
      map['createdAt'] ??
      map['created_at'] ??
      DateTime.now().toIso8601String();
  return DateTime.tryParse(value.toString())?.toLocal() ?? DateTime.now();
}

Map<DateTime, List<Map<String, dynamic>>> _agruparMovimientosPorDia(
    List<Map<String, dynamic>> movimientos) {
  final grupos = <DateTime, List<Map<String, dynamic>>>{};

  for (final movimiento in movimientos) {
    final fecha = _fechaMovimiento(movimiento);
    final dia = DateTime(fecha.year, fecha.month, fecha.day);
    grupos.putIfAbsent(dia, () => []).add(movimiento);
  }

  return Map.fromEntries(
      grupos.entries.toList()..sort((a, b) => b.key.compareTo(a.key)));
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

bool _movimientoPerteneceAMaterial(
  Map<String, dynamic> movimiento,
  String materialId,
  Map<String, dynamic> material,
) {
  final idMovimiento = _str(movimiento, 'materialId', 'material_id');
  if (idMovimiento.isNotEmpty && idMovimiento == materialId) return true;

  final codigoMovimiento =
      _str(movimiento, 'materialCodigo', 'material_codigo');
  final codigoMaterial = _str(material, 'codigo');
  if (codigoMovimiento.isNotEmpty && codigoMovimiento == codigoMaterial) {
    return true;
  }

  final nombreMovimiento =
      _str(movimiento, 'materialNombre', 'material_nombre').toLowerCase();
  final nombreMaterial = _str(material, 'nombre').toLowerCase();
  return nombreMovimiento.isNotEmpty && nombreMovimiento == nombreMaterial;
}

List<_PrecioPoint> _construirPuntosPrecio(
  Map<String, dynamic> material,
  List<Map<String, dynamic>> movimientos,
) {
  final puntos = <_PrecioPoint>[];

  for (final movimiento in movimientos) {
    final precio = _num(movimiento, 'precioUnitario', 'precio_unitario');
    if (precio > 0) {
      puntos.add(
          _PrecioPoint(fecha: _fechaMovimiento(movimiento), precio: precio));
    }
  }

  final precioActual = _precio(material);
  final fechaActual = _fechaPrecio(material) ?? DateTime.now();
  if (precioActual != null && precioActual > 0) {
    final yaExiste = puntos.any(
        (p) => _mismoDia(p.fecha, fechaActual) && p.precio == precioActual);
    if (!yaExiste) {
      puntos.add(_PrecioPoint(fecha: fechaActual, precio: precioActual));
    }
  }

  puntos.sort((a, b) => a.fecha.compareTo(b.fecha));

  final compactos = <_PrecioPoint>[];
  for (final punto in puntos) {
    if (compactos.isEmpty ||
        compactos.last.precio != punto.precio ||
        !_mismoDia(compactos.last.fecha, punto.fecha)) {
      compactos.add(punto);
    }
  }

  return compactos;
}

double _variacionPrecio(List<_PrecioPoint> puntos) {
  if (puntos.length < 2) return 0;
  final primero = puntos.first.precio;
  final ultimo = puntos.last.precio;
  if (primero == 0) return 0;
  return ((ultimo - primero) / primero) * 100;
}

void _mostrarError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
      behavior: SnackBarBehavior.floating,
    ),
  );
}
