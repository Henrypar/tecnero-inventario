// Pantalla para crear una nueva solicitud de materiales por linea.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../services/providers.dart';
import '../../services/api_service.dart';
import '../../models/models.dart' as models;

class NuevaSolicitudScreen extends ConsumerStatefulWidget {
  const NuevaSolicitudScreen({super.key});

  @override
  ConsumerState<NuevaSolicitudScreen> createState() =>
      _NuevaSolicitudScreenState();
}

class _ItemRow {
  final String rowId;
  models.Material material;
  double cantidad;

  _ItemRow({
    required this.material,
    this.cantidad = 1,
  }) : rowId = UniqueKey().toString();
}

class _NuevaSolicitudScreenState extends ConsumerState<NuevaSolicitudScreen> {
  models.LineaProduccion? _lineaSeleccionada;
  final List<_ItemRow> _items = [];
  final _obsCtrl = TextEditingController();

  bool _enviando = false;
  bool _cargandoSugeridos = false;
  bool _dialogoAbierto = false;
  String? _error;
  String? _exito;

  @override
  void dispose() {
    _obsCtrl.dispose();
    super.dispose();
  }

  String _normalizarTexto(String value) {
    return value
        .toLowerCase()
        .trim()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ä', 'a')
        .replaceAll('ë', 'e')
        .replaceAll('ï', 'i')
        .replaceAll('ö', 'o')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n');
  }

  String _categoriaLabel(models.Material m) {
    final c = _normalizarTexto(m.codigo);
    final n = _normalizarTexto(m.nombre);

    if (c.startsWith('a-segu') ||
        n.contains('guante') ||
        n.contains('careta') ||
        n.contains('mascarilla') ||
        n.contains('gafa') ||
        n.contains('monogafa') ||
        n.contains('mandil') ||
        n.contains('tapones') ||
        n.contains('protector') ||
        n.contains('vidrio')) {
      return 'EPP';
    }

    if (c.startsWith('r-matl') ||
        n.contains('suelda 6011') ||
        n.contains('suelda 7018') ||
        n.contains('cemento de contacto')) {
      return 'Mantenimiento';
    }

    return 'Producción';
  }

  Color _categoriaColor(String cat) {
    switch (cat) {
      case 'EPP':
        return const Color(0xFFFFF1B8);
      case 'Mantenimiento':
        return const Color(0xFFD9F7BE);
      default:
        return const Color(0xFFE5E7EB);
    }
  }

  void _actualizarMaterialesSeleccionados(List<models.Material> seleccionados) {
    final nuevos = <_ItemRow>[];

    for (final mat in seleccionados) {
      final existente = _items.where((i) => i.material.id == mat.id);

      if (existente.isNotEmpty) {
        nuevos.add(existente.first);
      } else {
        nuevos.add(_ItemRow(material: mat));
      }
    }

    setState(() {
      _items
        ..clear()
        ..addAll(nuevos);
      _error = null;
      _exito = null;
    });
  }

  Future<void> _abrirSelectorMateriales(
      List<models.Material> materiales) async {
    if (_dialogoAbierto) return;
    _dialogoAbierto = true;

    final seleccionados = await showDialog<List<models.Material>>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (dialogContext) => _MaterialesDialog(
        materiales: materiales,
        seleccionInicial: _items.map((e) => e.material).toList(),
        categoriaLabel: _categoriaLabel,
        categoriaColor: _categoriaColor,
        normalizarTexto: _normalizarTexto,
      ),
    );

    _dialogoAbierto = false;

    if (!mounted || seleccionados == null) return;

    _actualizarMaterialesSeleccionados(seleccionados);
  }

  Future<void> _preguntarCargarSugeridos() async {
    if (_dialogoAbierto || _cargandoSugeridos) return;

    if (_lineaSeleccionada == null) {
      setState(() {
        _error = 'Primero selecciona una línea de producción';
        _exito = null;
      });
      return;
    }

    final lineaActual = _lineaSeleccionada!;

    _dialogoAbierto = true;

    final confirmar = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Cargar materiales sugeridos?'),
        content: Text(
          'Para "${lineaActual.nombre}" se cargará la lista configurada en la base de datos.\n\n'
          'Luego puedes agregar, quitar o cambiar cantidades antes de enviar.',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext, rootNavigator: true).pop(false),
            child: const Text('No, elegir manualmente'),
          ),
          ElevatedButton.icon(
            onPressed: () =>
                Navigator.of(dialogContext, rootNavigator: true).pop(true),
            icon: const Icon(Icons.playlist_add_check, size: 18),
            label: const Text('Sí, cargar lista'),
          ),
        ],
      ),
    );

    _dialogoAbierto = false;

    if (!mounted || confirmar != true) return;

    setState(() {
      _cargandoSugeridos = true;
      _error = null;
      _exito = null;
    });

    try {
      final sugeridos =
          await ApiService().getMaterialesPorLinea(lineaActual.id);

      if (!mounted) return;

      if (sugeridos.isEmpty) {
        setState(() {
          _error =
              'La línea "${lineaActual.nombre}" no tiene materiales asociados. Puedes seleccionarlos manualmente.';
          _exito = null;
        });
        return;
      }

      final idsAgregados = <String>{};
      final nuevos = <_ItemRow>[];

      for (final sugerido in sugeridos) {
        if (!idsAgregados.add(sugerido.material.id)) continue;

        nuevos.add(
          _ItemRow(
            material: sugerido.material,
            cantidad:
                sugerido.cantidadSugerida <= 0 ? 1 : sugerido.cantidadSugerida,
          ),
        );
      }

      setState(() {
        _items
          ..clear()
          ..addAll(nuevos);

        _exito =
            'Se cargaron ${nuevos.length} materiales asociados a ${lineaActual.nombre}.';
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar los materiales sugeridos: $e';
        _exito = null;
      });
    } finally {
      if (mounted) {
        setState(() => _cargandoSugeridos = false);
      }
    }
  }

  void _removeItem(int i) {
    setState(() {
      _items.removeAt(i);
      _error = null;
      _exito = null;
    });
  }

  Future<void> _enviar() async {
    if (_lineaSeleccionada == null) {
      setState(() => _error = 'Selecciona una línea de producción');
      return;
    }

    if (_items.isEmpty) {
      setState(() => _error = 'Selecciona al menos un material');
      return;
    }

    if (_items.any((i) => i.cantidad <= 0)) {
      setState(() => _error = 'Las cantidades deben ser mayores a 0');
      return;
    }

    final ids = _items.map((i) => i.material.id).toList();

    if (ids.length != ids.toSet().length) {
      setState(() => _error = 'No puedes repetir el mismo material');
      return;
    }

    setState(() {
      _enviando = true;
      _error = null;
      _exito = null;
    });

    try {
      final usuario = await ApiService().getUsuarioActual();

      if (usuario == null) {
        setState(() => _error = 'No se pudo obtener el usuario');
        return;
      }

      await ApiService().crearSolicitud(
        solicitanteId: usuario.id,
        solicitanteNombre: usuario.nombre,
        lineaId: _lineaSeleccionada!.id,
        lineaNombre: _lineaSeleccionada!.nombre,
        observaciones: _obsCtrl.text.trim().isEmpty ? null : _obsCtrl.text,
        items: _items
            .map(
              (i) => {
                'materialId': i.material.id,
                'materialNombre': i.material.nombre,
                'materialCodigo': i.material.codigo,
                'unidadMedida': i.material.unidadMedida,
                'cantidad': i.cantidad,
              },
            )
            .toList(),
      );

      setState(() {
        _exito = 'Solicitud enviada a bodega';
        _lineaSeleccionada = null;
        _items.clear();
        _obsCtrl.clear();
      });

      ref.invalidate(solicitudesPendientesProvider);
      ref.invalidate(misSolicitudesProvider);
    } catch (e) {
      setState(() => _error = 'Error al enviar: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _enviando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lineas = ref.watch(lineasProvider);
    final materiales = ref.watch(materialesProvider);
    final isMobile = MediaQuery.sizeOf(context).width < 720;
    final paso1Listo = _lineaSeleccionada != null;
    final paso2Listo = _items.isNotEmpty;

    return Scaffold(
      backgroundColor: TecneroTheme.grisClaro,
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 28,
              vertical: isMobile ? 12 : 18,
            ),
            child: isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Nueva solicitud',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _MobileStepStrip(
                        paso1Listo: paso1Listo,
                        paso2Listo: paso2Listo,
                      ),
                    ],
                  )
                : Row(
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nueva solicitud de materiales',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Completa los pasos para solicitar materiales a bodega',
                            style: TextStyle(
                              fontSize: 13,
                              color: TecneroTheme.textoSecundario,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      _PasoIndicador(
                        numero: 1,
                        label: 'Línea',
                        activo: paso1Listo,
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 24,
                        height: 2,
                        color: paso1Listo
                            ? TecneroTheme.naranja
                            : TecneroTheme.grisBorde,
                      ),
                      const SizedBox(width: 8),
                      _PasoIndicador(
                        numero: 2,
                        label: 'Materiales',
                        activo: paso2Listo,
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 24,
                        height: 2,
                        color: paso2Listo
                            ? TecneroTheme.naranja
                            : TecneroTheme.grisBorde,
                      ),
                      const SizedBox(width: 8),
                      const _PasoIndicador(
                        numero: 3,
                        label: 'Enviar',
                        activo: false,
                      ),
                    ],
                  ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 14 : 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: Column(
                    children: [
                      _PasoCard(
                        numero: 1,
                        titulo: 'Selecciona la línea de producción',
                        descripcion: '¿En qué área vas a trabajar hoy?',
                        completado: paso1Listo,
                        child: lineas.when(
                          loading: () => const LinearProgressIndicator(),
                          error: (e, _) => _ErrorBox(msg: 'Error: $e'),
                          data: (lista) =>
                              DropdownButtonFormField<models.LineaProduccion>(
                            initialValue: _lineaSeleccionada,
                            decoration: const InputDecoration(
                              hintText: 'Toca aquí para seleccionar...',
                              prefixIcon:
                                  Icon(Icons.factory_outlined, size: 18),
                            ),
                            items: lista
                                .map(
                                  (l) => DropdownMenuItem(
                                    value: l,
                                    child: Text(
                                      l.nombre,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              setState(() {
                                _lineaSeleccionada = v;
                                _items.clear();
                                _error = null;
                                _exito = null;
                              });

                              if (v != null) {
                                WidgetsBinding.instance
                                    .addPostFrameCallback((_) {
                                  if (!mounted) return;
                                  _preguntarCargarSugeridos();
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _PasoCard(
                        numero: 2,
                        titulo: 'Elige los materiales que necesitas',
                        descripcion:
                            'Puedes cargar una lista sugerida o buscar manualmente',
                        completado: paso2Listo,
                        bloqueado: !paso1Listo,
                        child: materiales.when(
                          loading: () => const Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                          error: (e, _) => _ErrorBox(
                            msg:
                                'No se pudieron cargar los materiales.\nVerifica la conexión con el servidor.\n\n$e',
                          ),
                          data: (lista) => Column(
                            children: [
                              Flex(
                                direction:
                                    isMobile ? Axis.vertical : Axis.horizontal,
                                children: [
                                  Flexible(
                                    fit: isMobile
                                        ? FlexFit.loose
                                        : FlexFit.tight,
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: paso1Listo
                                            ? _preguntarCargarSugeridos
                                            : null,
                                        icon: Icon(
                                          _cargandoSugeridos
                                              ? Icons.hourglass_top_outlined
                                              : Icons.playlist_add_check,
                                          size: 20,
                                        ),
                                        label: Text(
                                          _cargandoSugeridos
                                              ? 'Cargando sugeridos...'
                                              : 'Cargar materiales sugeridos',
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          minimumSize:
                                              const Size(double.infinity, 50),
                                          backgroundColor:
                                              TecneroTheme.azulOscuro,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: isMobile ? 0 : 10,
                                    height: isMobile ? 10 : 0,
                                  ),
                                  Flexible(
                                    fit: isMobile
                                        ? FlexFit.loose
                                        : FlexFit.tight,
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: paso1Listo
                                            ? () =>
                                                _abrirSelectorMateriales(lista)
                                            : null,
                                        icon: Icon(
                                          _items.isEmpty
                                              ? Icons.add_circle_outline
                                              : Icons.edit_outlined,
                                          size: 20,
                                        ),
                                        label: Text(
                                          _items.isEmpty
                                              ? 'Seleccionar manualmente'
                                              : 'Editar selección (${_items.length})',
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          minimumSize:
                                              const Size(double.infinity, 50),
                                          side: BorderSide(
                                            color: paso1Listo
                                                ? TecneroTheme.azulOscuro
                                                : TecneroTheme.grisBorde,
                                            width: 1.5,
                                          ),
                                          foregroundColor: paso1Listo
                                              ? TecneroTheme.azulOscuro
                                              : TecneroTheme.textoSecundario,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (_items.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                _ResumenCategorias(
                                  items: _items,
                                  categoriaLabel: _categoriaLabel,
                                  categoriaColor: _categoriaColor,
                                ),
                                const SizedBox(height: 12),
                                if (!isMobile) ...[
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
                                        SizedBox(
                                          width: 110,
                                          child: Text(
                                            'Categoría',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color:
                                                  TecneroTheme.textoSecundario,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            'Material',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color:
                                                  TecneroTheme.textoSecundario,
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 110,
                                          child: Text(
                                            'Cantidad',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color:
                                                  TecneroTheme.textoSecundario,
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 70,
                                          child: Text(
                                            'Unidad',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color:
                                                  TecneroTheme.textoSecundario,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 40),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                ],
                                ...List.generate(
                                  _items.length,
                                  (i) => _MaterialFilaRow(
                                    key: ValueKey(_items[i].rowId),
                                    item: _items[i],
                                    categoria:
                                        _categoriaLabel(_items[i].material),
                                    categoriaColor: _categoriaColor(
                                      _categoriaLabel(_items[i].material),
                                    ),
                                    onCantidadChange: (v) => setState(
                                      () => _items[i].cantidad = v,
                                    ),
                                    onRemove: () => _removeItem(i),
                                  ),
                                ),
                              ] else if (paso1Listo) ...[
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0F9FF),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: const Color(0xFFBAE6FD),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.info_outline,
                                        color: Color(0xFF0284C7),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'Puedes cargar la lista sugerida para ${_lineaSeleccionada?.nombre ?? "esta línea"} o seleccionar materiales manualmente.',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF0369A1),
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
                      ),
                      const SizedBox(height: 12),
                      _PasoCard(
                        numero: 3,
                        titulo: 'Observaciones y envío',
                        descripcion: 'Agrega notas para bodega (opcional)',
                        completado: false,
                        bloqueado: !paso1Listo || !paso2Listo,
                        child: Column(
                          children: [
                            TextField(
                              controller: _obsCtrl,
                              maxLines: 3,
                              enabled: paso1Listo && paso2Listo,
                              decoration: const InputDecoration(
                                hintText:
                                    'Ej: Materiales urgentes, para turno de tarde...',
                                prefixIcon: Icon(Icons.note_outlined, size: 18),
                              ),
                            ),
                            const SizedBox(height: 20),
                            if (_error != null) ...[
                              _ErrorBox(msg: _error!),
                              const SizedBox(height: 12),
                            ],
                            if (_exito != null) ...[
                              _SuccessBox(msg: _exito!),
                              const SizedBox(height: 12),
                            ],
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed:
                                    (_enviando || !paso1Listo || !paso2Listo)
                                        ? null
                                        : _enviar,
                                icon: _enviando
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.send_outlined, size: 18),
                                label: Text(
                                  _enviando
                                      ? 'Enviando...'
                                      : 'Enviar solicitud a bodega',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  disabledBackgroundColor:
                                      TecneroTheme.grisBorde,
                                ),
                              ),
                            ),
                            if (!paso1Listo || !paso2Listo) ...[
                              const SizedBox(height: 8),
                              Text(
                                !paso1Listo
                                    ? 'Completa el paso 1 y 2 para poder enviar'
                                    : 'Completa el paso 2 para poder enviar',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: TecneroTheme.textoSecundario,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PasoIndicador extends StatelessWidget {
  final int numero;
  final String label;
  final bool activo;

  const _PasoIndicador({
    required this.numero,
    required this.label,
    required this.activo,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: activo ? TecneroTheme.naranja : TecneroTheme.grisBorde,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: activo
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : Text(
                    '$numero',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: TecneroTheme.textoSecundario,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            color: TecneroTheme.textoSecundario,
          ),
        ),
      ],
    );
  }
}

class _MobileStepStrip extends StatelessWidget {
  final bool paso1Listo;
  final bool paso2Listo;

  const _MobileStepStrip({
    required this.paso1Listo,
    required this.paso2Listo,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MobileStepChip(
            numero: 1,
            label: 'Línea',
            activo: paso1Listo,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _MobileStepChip(
            numero: 2,
            label: 'Materiales',
            activo: paso2Listo,
          ),
        ),
        const SizedBox(width: 6),
        const Expanded(
          child: _MobileStepChip(
            numero: 3,
            label: 'Enviar',
            activo: false,
          ),
        ),
      ],
    );
  }
}

class _MobileStepChip extends StatelessWidget {
  final int numero;
  final String label;
  final bool activo;

  const _MobileStepChip({
    required this.numero,
    required this.label,
    required this.activo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: activo
            ? TecneroTheme.naranja.withValues(alpha: 0.12)
            : TecneroTheme.grisClaro,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: activo ? TecneroTheme.naranja : TecneroTheme.grisBorde,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: activo ? TecneroTheme.naranja : Colors.white,
            child: activo
                ? const Icon(Icons.check, size: 12, color: Colors.white)
                : Text(
                    '$numero',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: TecneroTheme.textoSecundario,
                    ),
                  ),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PasoCard extends StatelessWidget {
  final int numero;
  final String titulo;
  final String descripcion;
  final bool completado;
  final bool bloqueado;
  final Widget child;

  const _PasoCard({
    required this.numero,
    required this.titulo,
    required this.descripcion,
    required this.completado,
    this.bloqueado = false,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: bloqueado ? 0.5 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: completado
                ? TecneroTheme.naranja.withValues(alpha: 0.4)
                : TecneroTheme.grisBorde,
            width: completado ? 1.5 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: completado
                          ? TecneroTheme.naranja
                          : TecneroTheme.azulOscuro,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: completado
                          ? const Icon(
                              Icons.check,
                              size: 16,
                              color: Colors.white,
                            )
                          : Text(
                              '$numero',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titulo,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          descripcion,
                          style: const TextStyle(
                            fontSize: 12,
                            color: TecneroTheme.textoSecundario,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (completado)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1FAE5),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Completado',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF065F46),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _ResumenCategorias extends StatelessWidget {
  final List<_ItemRow> items;
  final String Function(models.Material) categoriaLabel;
  final Color Function(String) categoriaColor;

  const _ResumenCategorias({
    required this.items,
    required this.categoriaLabel,
    required this.categoriaColor,
  });

  @override
  Widget build(BuildContext context) {
    final resumen = <String, int>{};

    for (final item in items) {
      final cat = categoriaLabel(item.material);
      resumen[cat] = (resumen[cat] ?? 0) + 1;
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: resumen.entries
          .map(
            (e) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: categoriaColor(e.key),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${e.key}: ${e.value}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _MaterialFilaRow extends StatelessWidget {
  final _ItemRow item;
  final String categoria;
  final Color categoriaColor;
  final Function(double) onCantidadChange;
  final VoidCallback onRemove;

  const _MaterialFilaRow({
    super.key,
    required this.item,
    required this.categoria,
    required this.categoriaColor,
    required this.onCantidadChange,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 720;

    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: TecneroTheme.grisBorde),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.material.nombre,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: categoriaColor,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                categoria,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              item.material.codigo,
                              style: const TextStyle(
                                fontSize: 11,
                                color: TecneroTheme.textoSecundario,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onRemove,
                    icon: const Icon(
                      Icons.close,
                      size: 18,
                      color: Color(0xFFEF4444),
                    ),
                    tooltip: 'Eliminar',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      key: ValueKey('cantidad-mobile-${item.rowId}'),
                      initialValue: item.cantidad.toString(),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Cantidad',
                        isDense: true,
                      ),
                      onChanged: (v) =>
                          onCantidadChange(double.tryParse(v) ?? 0),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Unidad',
                        isDense: true,
                      ),
                      child: Text(
                        item.material.unidadMedida,
                        overflow: TextOverflow.ellipsis,
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 110,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: categoriaColor,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                categoria,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.material.nombre,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  item.material.codigo,
                  style: const TextStyle(
                    fontSize: 10,
                    color: TecneroTheme.textoSecundario,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 110,
            child: TextFormField(
              key: ValueKey('cantidad-${item.rowId}'),
              initialValue: item.cantidad.toString(),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
              ),
              style: const TextStyle(fontSize: 13),
              onChanged: (v) => onCantidadChange(double.tryParse(v) ?? 0),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            child: Text(
              item.material.unidadMedida,
              style: const TextStyle(
                fontSize: 12,
                color: TecneroTheme.textoSecundario,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 40,
            child: IconButton(
              onPressed: onRemove,
              icon: const Icon(
                Icons.remove_circle_outline,
                size: 20,
                color: Color(0xFFEF4444),
              ),
              padding: EdgeInsets.zero,
              tooltip: 'Quitar',
            ),
          ),
        ],
      ),
    );
  }
}

class _MaterialesDialog extends StatefulWidget {
  final List<models.Material> materiales;
  final List<models.Material> seleccionInicial;
  final String Function(models.Material) categoriaLabel;
  final Color Function(String) categoriaColor;
  final String Function(String) normalizarTexto;

  const _MaterialesDialog({
    required this.materiales,
    required this.seleccionInicial,
    required this.categoriaLabel,
    required this.categoriaColor,
    required this.normalizarTexto,
  });

  @override
  State<_MaterialesDialog> createState() => _MaterialesDialogState();
}

class _MaterialesDialogState extends State<_MaterialesDialog> {
  final _buscarCtrl = TextEditingController();
  final Set<String> _seleccionadosIds = {};
  String _categoriaFiltro = 'Todos';

  @override
  void initState() {
    super.initState();
    _seleccionadosIds.addAll(widget.seleccionInicial.map((m) => m.id));
  }

  @override
  void dispose() {
    _buscarCtrl.dispose();
    super.dispose();
  }

  List<String> get _categorias {
    final cats = widget.materiales.map(widget.categoriaLabel).toSet().toList()
      ..sort();

    return ['Todos', ...cats];
  }

  List<models.Material> get _filtrados {
    final q = widget.normalizarTexto(_buscarCtrl.text);

    return widget.materiales.where((m) {
      final cat = widget.categoriaLabel(m);
      final matchCat = _categoriaFiltro == 'Todos' || cat == _categoriaFiltro;
      final texto =
          widget.normalizarTexto('${m.codigo} ${m.nombre} ${m.unidadMedida}');
      final matchTxt = q.isEmpty || texto.contains(q);

      return matchCat && matchTxt;
    }).toList()
      ..sort((a, b) {
        final c = widget.categoriaLabel(a).compareTo(widget.categoriaLabel(b));

        return c != 0 ? c : a.nombre.compareTo(b.nombre);
      });
  }

  @override
  Widget build(BuildContext context) {
    final filtrados = _filtrados;
    final w = MediaQuery.of(context).size.width;

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      title: Row(
        children: [
          const Expanded(
            child: Text(
              'Seleccionar materiales',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: TecneroTheme.naranja.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${_seleccionadosIds.length} seleccionados',
              style: const TextStyle(
                fontSize: 12,
                color: TecneroTheme.naranja,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: w > 760 ? 720 : w * 0.92,
        height: 560,
        child: Column(
          children: [
            TextField(
              controller: _buscarCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o código...',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _buscarCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => _buscarCtrl.clear()),
                      )
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _categorias.map((cat) {
                  final sel = cat == _categoriaFiltro;

                  return FilterChip(
                    label: Text(cat),
                    selected: sel,
                    onSelected: (_) => setState(() => _categoriaFiltro = cat),
                    backgroundColor: cat == 'Todos'
                        ? TecneroTheme.grisClaro
                        : widget.categoriaColor(cat),
                    selectedColor: TecneroTheme.azulOscuro,
                    labelStyle: TextStyle(
                      fontSize: 11,
                      color: sel ? Colors.white : TecneroTheme.textoPrimario,
                    ),
                    checkmarkColor: Colors.white,
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: filtrados.isEmpty
                  ? const Center(
                      child: Text(
                        'Sin resultados',
                        style: TextStyle(
                          color: TecneroTheme.textoSecundario,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtrados.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final m = filtrados[i];
                        final cat = widget.categoriaLabel(m);
                        final sel = _seleccionadosIds.contains(m.id);

                        return CheckboxListTile(
                          dense: true,
                          value: sel,
                          onChanged: (v) => setState(() {
                            if (v == true) {
                              _seleccionadosIds.add(m.id);
                            } else {
                              _seleccionadosIds.remove(m.id);
                            }
                          }),
                          title: Text(
                            m.nombre,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Text(
                                m.codigo,
                                style: const TextStyle(fontSize: 11),
                              ),
                              Text(
                                m.unidadMedida,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: TecneroTheme.textoSecundario,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: widget.categoriaColor(cat),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  cat,
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ),
                            ],
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: TecneroTheme.azulOscuro,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(null),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            final sel = widget.materiales
                .where((m) => _seleccionadosIds.contains(m.id))
                .toList();

            Navigator.of(context, rootNavigator: true).pop(sel);
          },
          icon: const Icon(Icons.check, size: 18),
          label: Text('Confirmar (${_seleccionadosIds.length})'),
        ),
      ],
    );
  }
}

class _SuccessBox extends StatelessWidget {
  final String msg;

  const _SuccessBox({required this.msg});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFD1FAE5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF6EE7B7)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.check_circle_outline,
              size: 18,
              color: Color(0xFF065F46),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF065F46),
                ),
              ),
            ),
          ],
        ),
      );
}

class _ErrorBox extends StatelessWidget {
  final String msg;

  const _ErrorBox({required this.msg});

  @override
  Widget build(BuildContext context) => Container(
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
