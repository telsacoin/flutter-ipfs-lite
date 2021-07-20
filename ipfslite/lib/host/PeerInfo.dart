import 'dart:core';

class PeerInfo {

    PeerId peerId;

    String agent;

    String version;
    List<Multiaddr> addresses;

    List<String> protocols;

    final Multiaddr observed;

    PeerInfo(@NonNull PeerId peerId,
                    @NonNull String agent,
                    @NonNull String version,
                    @NonNull List<Multiaddr> addresses,
                    @NonNull List<String> protocols,
                    @Nullable Multiaddr observed) {
        this.peerId = peerId;
        this.agent = agent;
        this.version = version;
        this.addresses = addresses;
        this.protocols = protocols;
        this.observed = observed;
    }

    String getVersion() {
        return version;
    }

    List<String> getProtocols() {
        return protocols;
    }

    Multiaddr getObserved() {
        return observed;
    }

    List<Multiaddr> getAddresses() {
        return addresses;
    }

    @Override
    public String toString() {
        return "PeerInfo{" +
                "peerId=" + peerId +
                ", agent='" + agent + '\'' +
                ", version='" + version + '\'' +
                ", addresses=" + addresses +
                ", protocols=" + protocols +
                ", observed=" + observed +
                '}';
    }

    @NonNull
    public PeerId getPeerId() {
        return peerId;
    }

    @NonNull
    public String getAgent() {
        return agent;
    }

}
