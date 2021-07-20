abstract class ConnectionHandler {
  void outgoingConnection(PeerId peerId, QuicConnection connection);
  void incomingConnection(PeerId peerId, QuicConnection connection);
}
