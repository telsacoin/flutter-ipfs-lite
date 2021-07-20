import 'dart:typed_data';

class IdentityRequest {
    private static final String TAG = IdentityRequest.class.getSimpleName();

    @NonNull
    private final InputStream inputStream;
    @NonNull
    private final OutputStream outputStream;

    public IdentityRequest(@NonNull QuicStream quicStream, long readTimeout, TimeUnit unit) {
        this.inputStream = quicStream.getInputStream(unit.toMillis(readTimeout));
        this.outputStream = quicStream.getOutputStream();
    }

    public void writeAndFlush(@NonNull byte[] data) {
        try {
            outputStream.write(data);
            outputStream.flush();
        } catch (Throwable throwable) {
            LogUtils.error(TAG, throwable);
        }
    }

    public void closeOutputStream() {
        try {
            outputStream.close();
        } catch (Throwable throwable) {
            LogUtils.error(TAG, throwable);
        }
    }

    @Nullable
    public IdentifyOuterClass.Identify reading() throws IOException, ProtocolIssue, DataLimitIssue {

        DataHandler reader = new DataHandler(new HashSet<>(
                Arrays.asList(IPFS.STREAM_PROTOCOL, IPFS.IDENTITY_PROTOCOL)
        ), IPFS.IDENTITY_STREAM_SIZE_LIMIT);
        byte[] buf = new byte[4096];

        int length;

        while ((length = inputStream.read(buf, 0, 4096)) > 0) {
            reader.load(Arrays.copyOfRange(buf, 0, length));
            if (reader.isDone()) {
                Uint8List message = reader.getMessage();
                if (message != null) {
                    return IdentifyOuterClass.Identify.parseFrom(message);
                }
            }
        }

        return null;
    }
}