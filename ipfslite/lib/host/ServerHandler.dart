class ServerHandler extends ApplicationProtocolConnection implements Consumer<QuicStream> {
    private static final String TAG = ServerHandler.class.getSimpleName();
    private final QuicConnection connection;
    private final LiteHost liteHost;
    private final PeerId peerId;

    public ServerHandler(@NonNull LiteHost liteHost, @NonNull QuicConnection quicConnection) throws IOException {
        this.liteHost = liteHost;
        this.connection = quicConnection;


        X509Certificate cert = connection.getRemoteCertificate();
        Objects.requireNonNull(cert);
        PubKey pubKey = LiteHostCertificate.extractPublicKey(cert);
        Objects.requireNonNull(pubKey);
        peerId = PeerId.fromPubKey(pubKey);
        Objects.requireNonNull(peerId);
        liteHost.handleConnection(peerId, connection, true);

        connection.setPeerInitiatedStreamCallback(this);

    }

    @Override
    public void accept(QuicStream quicStream) {
        new StreamHandler(connection, quicStream, peerId, liteHost);
    }
}