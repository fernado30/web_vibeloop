import 'dart:io';

/// Determina si un error u objeto es el resultado de un problema de conexión/red.
bool isNetworkError(Object error) {
  if (error is SocketException || error is HttpException || error is HandshakeException) {
    return true;
  }
  final message = error.toString().toLowerCase();
  return message.contains('socketexception') ||
      message.contains('failed host lookup') ||
      message.contains('network_unreachable') ||
      message.contains('network is unreachable') ||
      message.contains('connection timed out') ||
      message.contains('connection closed before full header') ||
      message.contains('clientexception') ||
      message.contains('handshakeexception') ||
      message.contains('httpexception') ||
      message.contains('no address associated with hostname');
}

/// Devuelve un mensaje amigable y limpio en español para errores de red.
String getFriendlyNetworkError({String? actionContext}) {
  if (actionContext != null && actionContext.isNotEmpty) {
    return 'No pudimos $actionContext porque no tienes conexión a internet. Revisa tu conexión de red e inténtalo de nuevo.';
  }
  return 'No tienes conexión a internet. Revisa tu conexión de red e inténtalo de nuevo.';
}
