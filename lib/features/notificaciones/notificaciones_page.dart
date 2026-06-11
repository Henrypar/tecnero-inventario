// Pantalla de bandeja de notificaciones y configuracion de alertas de stock.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/models.dart';
import '../../services/providers.dart';
import '../../theme/app_theme.dart';

class NotificacionesPage extends ConsumerWidget {
  const NotificacionesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificaciones = ref.watch(notificacionesProvider);
    final usuario = ref.watch(usuarioActualProvider).asData?.value;
    final sesionActiva =
        usuario != null && ref.read(apiServiceProvider).token != null;
    final esAdmin = usuario?.rol == RolUsuario.admin;
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          if (esAdmin)
            TextButton.icon(
              onPressed: () => _abrirConfigAlertasStock(context, ref),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              icon: const Icon(Icons.notifications_active_outlined, size: 18),
              label: const Text('Configurar alertas'),
            ),
          TextButton.icon(
            onPressed: sesionActiva
                ? () async {
                    await ref
                        .read(notificacionesServiceProvider)
                        .marcarTodasComoLeidas();
                    ref.invalidate(notificacionesProvider);
                    ref.invalidate(contadorNotificacionesNoLeidasProvider);
                  }
                : null,
            icon: const Icon(Icons.done_all, size: 18),
            label: const Text('Marcar todas'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: notificaciones.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No tienes notificaciones todavía.'),
                  if (esAdmin) ...[
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: () => _abrirConfigAlertasStock(context, ref),
                      icon: const Icon(
                        Icons.notifications_active_outlined,
                        size: 18,
                      ),
                      label: const Text('Configurar alertas de stock'),
                    ),
                  ],
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = items[index];
              return _NotificacionTile(
                item: item,
                fecha: dateFormat.format(item.fechaCreacion),
                onMarcarLeida: item.leida
                    ? null
                    : () async {
                        await ref
                            .read(notificacionesServiceProvider)
                            .marcarComoLeida(item.id);
                        ref.invalidate(notificacionesProvider);
                        ref.invalidate(contadorNotificacionesNoLeidasProvider);
                      },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'No se pudieron cargar las notificaciones: $error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _abrirConfigAlertasStock(
  BuildContext context,
  WidgetRef ref,
) async {
  try {
    final materiales = await ref.read(materialesConPreciosProvider.future);
    if (!context.mounted) return;

    final guardado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ConfigAlertasStockDialog(materiales: materiales),
    );

    if (guardado == true) {
      ref.invalidate(materialesConPreciosProvider);
      ref.invalidate(materialesProvider);
    }
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('No se pudieron cargar los productos: $e'),
        backgroundColor: Colors.red,
      ),
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
  final _buscarCtrl = TextEditingController();
  final Map<String, TextEditingController> _controllers = {};
  String _busqueda = '';
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
    _buscarCtrl.dispose();
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
    final query = _busqueda.trim().toLowerCase();
    final materiales = widget.materiales.where((m) {
      if (!_bool(m, 'activo', fallback: true)) return false;
      final texto = [
        _str(m, 'codigo'),
        _str(m, 'nombre'),
        _str(m, 'unidadMedida', 'unidad_medida'),
      ].join(' ').toLowerCase();
      return query.isEmpty || texto.contains(query);
    }).toList()
      ..sort((a, b) => _str(a, 'nombre').compareTo(_str(b, 'nombre')));

    return AlertDialog(
      title: const Text('Configurar alertas de stock'),
      content: SizedBox(
        width: 760,
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: Column(
          children: [
            TextField(
              controller: _buscarCtrl,
              decoration: const InputDecoration(
                hintText: 'Buscar producto...',
                prefixIcon: Icon(Icons.search, size: 18),
              ),
              onChanged: (value) => setState(() => _busqueda = value),
            ),
            const SizedBox(height: 12),
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
                      'El admin será notificado cuando un despacho deje el stock en el umbral configurado o por debajo.',
                      style: TextStyle(
                        fontSize: 12,
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
                          width: 130,
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
              _ErrorBox(message: _error!),
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
          fontSize: 12,
          color: Color(0xFF991B1B),
        ),
      ),
    );
  }
}

class _NotificacionTile extends StatelessWidget {
  final NotificacionInterna item;
  final String fecha;
  final VoidCallback? onMarcarLeida;

  const _NotificacionTile({
    required this.item,
    required this.fecha,
    required this.onMarcarLeida,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: item.leida
            ? Colors.white
            : TecneroTheme.naranja.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: item.leida
              ? const Color(0xFFE5E7EB)
              : TecneroTheme.naranja.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            item.leida
                ? Icons.notifications_none
                : Icons.notifications_active_outlined,
            color: item.leida ? Colors.black45 : TecneroTheme.naranja,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.titulo,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    _TipoChip(tipo: item.tipo),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  item.mensaje,
                  style: const TextStyle(height: 1.35),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      fecha,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                    if (item.solicitudId != null)
                      Text(
                        'Solicitud vinculada',
                        style: TextStyle(
                          color:
                              TecneroTheme.azulOscuro.withValues(alpha: 0.75),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (onMarcarLeida != null)
                      TextButton.icon(
                        onPressed: onMarcarLeida,
                        icon: const Icon(Icons.done, size: 16),
                        label: const Text('Marcar leída'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TipoChip extends StatelessWidget {
  final String tipo;

  const _TipoChip({required this.tipo});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: TecneroTheme.azulOscuro.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        tipo.replaceAll('_', ' '),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _str(Map<String, dynamic> map, String key, [String? alt]) {
  return (map[key] ?? (alt == null ? null : map[alt]) ?? '').toString();
}

double _num(Map<String, dynamic> map, String key, [String? alt]) {
  return double.tryParse(
        (map[key] ?? (alt == null ? null : map[alt]) ?? 0).toString(),
      ) ??
      0;
}

bool _bool(Map<String, dynamic> map, String key, {bool fallback = false}) {
  final value = map[key];
  if (value is bool) return value;
  if (value == null) return fallback;
  return value.toString() == 'true';
}

double _stockMinimoAlerta(Map<String, dynamic> map) {
  return double.tryParse(
        (map['stockMinimoAlerta'] ?? map['stock_minimo_alerta'] ?? 5)
            .toString(),
      ) ??
      5;
}

String _formatCantidad(double value) {
  if (value % 1 == 0) return value.toInt().toString();
  return value.toStringAsFixed(2);
}
