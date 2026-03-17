import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config/constants.dart';
import 'auth_service.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? _socket;

  Future<void> connect() async {
    if (_socket != null && _socket!.connected) return;

    final token = await AuthService().getToken();
    if (token == null) return;

    _socket = IO.io(Constants.serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'auth': {'token': token},
    });

    _socket!.connect();

    _socket!.onConnect((_) {
      print('Socket Connected: ${_socket!.id}');
    });

    _socket!.onDisconnect((_) {
      print('Socket Disconnected');
    });

    _socket!.onError((error) {
      print('Socket Error: $error');
    });
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }

  IO.Socket? get socket => _socket;
}
