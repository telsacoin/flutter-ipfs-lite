import 'package:ipfslite/host/PeerInfo.dart';

class IdentityService {
    static final String TAG = IdentityService.class.getSimpleName();

    static PeerInfo getPeerInfo(PeerId peerId, QuicClientConnection conn)
            on Exception {


        IdentifyOuterClass.Identify identify = IdentityService.getIdentity(conn);
        Objects.requireNonNull(identify);

        String agent = identify.getAgentVersion();
        String version = identify.getProtocolVersion();
        Multiaddr observedAddr = null;
        if (identify.hasObservedAddr()) {
            observedAddr = new Multiaddr(identify.getObservedAddr().toByteArray());
        }

        List<String> protocols = new ArrayList<>();
        List<Multiaddr> addresses = new ArrayList<>();
        List<ByteString> entries = identify.getProtocolsList().asByteStringList();
        for (ByteString entry : entries) {
            protocols.add(entry.toStringUtf8());
        }
        entries = identify.getListenAddrsList();
        for (ByteString entry : entries) {
            addresses.add(new Multiaddr(entry.toByteArray()));
        }

        return new PeerInfo(peerId, agent, version, addresses, protocols, observedAddr);

    }

    @NonNull
    public static IdentifyOuterClass.Identify getIdentity(@NonNull QuicClientConnection conn)
            throws Exception {
        return requestIdentity(conn);
    }


    private static IdentifyOuterClass.Identify requestIdentity(
            @NonNull QuicClientConnection conn) throws Exception {


        QuicStream quicStream = conn.createStream(true, IPFS.CREATE_STREAM_TIMEOUT,
                TimeUnit.SECONDS);
        IdentityRequest identityRequest = new IdentityRequest(quicStream, IPFS.CONNECT_TIMEOUT,
                TimeUnit.SECONDS);

        // TODO quicStream.updatePriority(new QuicStreamPriority(IPFS.PRIORITY_HIGH, false));

        identityRequest.writeAndFlush(DataHandler.writeToken(
                IPFS.STREAM_PROTOCOL, IPFS.IDENTITY_PROTOCOL));

        identityRequest.closeOutputStream();

        return identityRequest.reading();

    }
}
