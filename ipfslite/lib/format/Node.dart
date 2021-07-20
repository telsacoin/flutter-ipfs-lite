import 'Block.dart';

abstract class Node extends Block, Resolver {
    Prefix v0CidPrefix = new Prefix(
            Cid.DagProtobuf, -1, Multihash.Type.sha2_256.index, 0);
    Prefix v1CidPrefix = new Prefix(
            Cid.DagProtobuf, -1, Multihash.Type.sha2_256.index, 1);

    // PrefixForCidVersion returns the Protobuf prefix for a given CID version
    static Prefix PrefixForCidVersion(int version) {
        switch (version) {
            case 0:
                return v0CidPrefix;
            case 1:
                return v1CidPrefix;
            default:
                throw new RuntimeException("wrong version");
        }
    }

    static ProtoNode createNodeWithData(byte[] data) {
        return new ProtoNode(data);
    }

    List<Link> getLinks();

    Cid getCid();

    byte[] getData();

    byte[] getRawData();

    void setCidBuilder(@Nullable Builder builder);

    Pair<Link, List<String>> resolveLink(@NonNull List<String> path);

    long size();
}
