// Servicio de socket y audio para recibir notificaciones en tiempo real.
import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../models/models.dart';
import '../../services/api_service.dart';

typedef NuevaNotificacionCallback = void Function(
    NotificacionInterna notificacion);

class NotificationSocketService {
  io.Socket? _socket;
  String? _usuarioId;
  NuevaNotificacionCallback? _onNuevaNotificacion;
  final AudioPlayer _audioPlayer = AudioPlayer();
  AudioPool? _audioPool;
  Future<void>? _audioInitFuture;

  bool get conectado => _socket?.connected == true;

  void connect({
    required String usuarioId,
    required NuevaNotificacionCallback onNuevaNotificacion,
  }) {
    // Se guarda el callback para refrescar UI cada vez que entra un evento.
    _onNuevaNotificacion = onNuevaNotificacion;
    unawaited(_inicializarAudio());

    if (_socket != null && _usuarioId == usuarioId) {
      return;
    }

    disconnect();
    _usuarioId = usuarioId;

    final socket = io.io(
      ApiService.socketBaseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'usuarioId': usuarioId})
          .build(),
    );

    socket.onConnect((_) {
      socket.emit('registrar_usuario', {'usuarioId': usuarioId});
    });

    socket.on('nueva_notificacion', (data) {
      if (data is Map) {
        // El socket entrega el payload como mapa; se convierte al modelo de la
        // app antes de disparar sonido y refresco.
        final notificacion = NotificacionInterna.fromJson(
          Map<String, dynamic>.from(data),
        );
        _reproducirSonido();
        _onNuevaNotificacion?.call(notificacion);
      }
    });

    _socket = socket;
    socket.connect();
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _usuarioId = null;
  }

  void dispose() {
    disconnect();
    unawaited(_audioPool?.dispose());
    _audioPlayer.dispose();
  }

  Future<void> _inicializarAudio() {
    return _audioInitFuture ??= _crearAudioPool();
  }

  Future<void> _crearAudioPool() async {
    try {
      // El sonido se deja preparado una sola vez para evitar latencia al
      // recibir la primera notificación.
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      await _audioPlayer.setPlayerMode(PlayerMode.lowLatency);
      await _audioPlayer.setVolume(1);

      _audioPool = await AudioPool.createFromAsset(
        path: 'sounds/notification.mp3',
        minPlayers: 1,
        maxPlayers: 4,
        playerMode: PlayerMode.lowLatency,
      );
    } catch (e, st) {
      debugPrint('No se pudo inicializar el audio de notificaciones: $e');
      debugPrintStack(stackTrace: st);
      _audioPool = null;
    }
  }

  Future<void> _reproducirSonido() async {
    try {
      await _inicializarAudio();

      final pool = _audioPool;
      if (pool != null) {
        await pool.start(volume: 1);
        return;
      }

      await _audioPlayer.stop();
      await _audioPlayer.play(
        AssetSource('sounds/notification.mp3'),
        volume: 1,
        mode: PlayerMode.lowLatency,
      );
    } catch (e, st) {
      debugPrint('No se pudo reproducir el sonido de notificación: $e');
      debugPrintStack(stackTrace: st);
    }
  }
}
