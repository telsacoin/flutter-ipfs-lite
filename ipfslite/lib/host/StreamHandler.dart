class StreamHandler {
    private static final String TAG = StreamHandler.class.getSimpleName();
    protected final int streamId;
    private final LiteHost host;
    @NonNull
    private final QuicConnection connection;
    @NonNull
    private final DataHandler reader = new DataHandler(new HashSet<>(
            Arrays.asList(IPFS.STREAM_PROTOCOL, IPFS.PUSH_PROTOCOL, IPFS.BITSWAP_PROTOCOL,
                    IPFS.IDENTITY_PROTOCOL, IPFS.DHT_PROTOCOL, IPFS.RELAY_PROTOCOL)
    ), IPFS.MESSAGE_SIZE_MAX);
    @NonNull
    private final PeerId peerId;
    private final InputStream inputStream;
    private final OutputStream outputStream;
    private final AtomicBoolean init = new AtomicBoolean(false);
    private volatile String protocol = null;
    private long time = System.currentTimeMillis();

    public StreamHandler(@NonNull QuicConnection connection, @NonNull QuicStream quicStream,
                         @NonNull PeerId peerId, @NonNull LiteHost host) {
        this.inputStream = quicStream.getInputStream();
        this.outputStream = quicStream.getOutputStream();
        this.streamId = quicStream.getStreamId();
        this.connection = connection;
        this.host = host;
        this.peerId = peerId;
        new Thread(this::reading).start();
        LogUtils.debug(TAG, "Instance" + " StreamId " + streamId + " PeerId " + peerId);
    }


    protected void reading() {
        byte[] buf = new byte[4096];
        try {
            int length;

            while ((length = inputStream.read(buf, 0, 4096)) > 0) {
                byte[] data = Arrays.copyOfRange(buf, 0, length);
                channelRead0(data);
            }

        } catch (Throwable throwable) {
            exceptionCaught(throwable);
        }
    }


    public void writeAndFlush(@NonNull byte[] data) {
        try {
            outputStream.write(data);
            outputStream.flush();
        } catch (Throwable throwable) {
            exceptionCaught(throwable);
        }
    }

    public void exceptionCaught(@NonNull Throwable cause) {
        LogUtils.debug(TAG, "Error" + " StreamId " + streamId + " PeerId " + peerId + " " + cause);
        reader.clear();
    }

    public void closeOutputStream() {
        try {
            outputStream.close();
        } catch (Throwable throwable) {
            LogUtils.error(TAG, throwable);
        }
    }

    public void channelRead0(@NonNull byte[] msg) throws Exception {

        try {
            reader.load(msg);

            if (reader.isDone()) {
                for (String token : reader.getTokens()) {

                    LogUtils.debug(TAG, "Token " + token + " StreamId " + streamId + " PeerId " + peerId);

                    protocol = token;
                    switch (token) {
                        case IPFS.STREAM_PROTOCOL:
                            if (!init.getAndSet(true)) {
                                writeAndFlush(DataHandler.writeToken(IPFS.STREAM_PROTOCOL));
                            }
                            break;
                        case IPFS.PUSH_PROTOCOL:
                            writeAndFlush(DataHandler.writeToken(IPFS.PUSH_PROTOCOL));
                            break;
                        case IPFS.BITSWAP_PROTOCOL:
                            writeAndFlush(DataHandler.writeToken(IPFS.BITSWAP_PROTOCOL));
                            time = System.currentTimeMillis();
                            break;
                        case IPFS.IDENTITY_PROTOCOL:
                            writeAndFlush(DataHandler.writeToken(IPFS.IDENTITY_PROTOCOL));

                            IdentifyOuterClass.Identify response =
                                    host.createIdentity(connection.getRemoteAddress());

                            writeAndFlush(DataHandler.encode(response));
                            return;
                        default:
                            LogUtils.debug(TAG, "Ignore " + token +
                                    " StreamId " + streamId + " PeerId " + peerId);
                            writeAndFlush(DataHandler.writeToken(IPFS.NA));
                            closeOutputStream();
                            return;
                    }
                }
                byte[] message = reader.getMessage();

                if (message != null) {
                    if (protocol != null) {
                        switch (protocol) {
                            case IPFS.BITSWAP_PROTOCOL:
                                host.forwardMessage(peerId,
                                        MessageOuterClass.Message.parseFrom(message));

                                LogUtils.debug(TAG, "Time " + (System.currentTimeMillis() - time) +
                                        " StreamId " + streamId + " PeerId " + peerId);
                                break;
                            case IPFS.PUSH_PROTOCOL:
                                host.push(peerId, message);
                                break;
                            default:
                                throw new Exception("StreamHandler invalid protocol");
                        }
                    } else {
                        throw new Exception("StreamHandler invalid protocol");
                    }
                }
            } else {
                LogUtils.debug(TAG, "Iteration " + protocol + " " + reader.hasRead() + " "
                        + reader.expectedBytes() + " StreamId " + streamId + " PeerId " + peerId +
                        " Tokens " + reader.getTokens().toString());
            }

        } catch (ProtocolIssue protocolIssue) {
            LogUtils.error(TAG, protocolIssue.getMessage() +
                    " StreamId " + streamId + " PeerId " + peerId);
            writeAndFlush(DataHandler.writeToken(IPFS.NA));
            closeOutputStream();

        }
    }
}
