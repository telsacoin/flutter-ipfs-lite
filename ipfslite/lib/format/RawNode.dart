import 'dart:typed_data';

import 'Block.dart';
import 'Node.dart';

class RawNode implements Node {

    Block block;


    RawNode(Block block) {
        this.block = block;
    }

    static Node NewRawNode(byte[] data) {

        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            Uint8List hash = digest.digest(data);

            Cid cid = Cid.NewCidV1(Cid.Raw, hash);
            Block blk = BasicBlock.createBlockWithCid(cid, data);

            return new RawNode(blk);
        } catch (Throwable throwable) {
            throw new RuntimeException(throwable);
        }

    }

    static Node NewRawNodeWPrefix(byte[] data, Builder builder) {

        builder = builder.withCodec(Cid.Raw);
        Cid cid = builder.sum(data);

        Block blk = BasicBlock.createBlockWithCid(cid, data);

        return new RawNode(blk);

    }

    @Override
    public void setCidBuilder(@Nullable Builder builder) {
        throw new RuntimeException("TODO");
    }

    @Override
    public Pair<Link, List<String>> resolveLink(@NonNull List<String> path) {
        throw new RuntimeException("not supported here");
    }

    @Override
    public long size() {
        return getData().length;
    }

    @Override
    public List<Link> getLinks() {
        return new ArrayList<>();
    }

    @Override
    public Cid getCid() {
        return block.getCid();
    }

    @Override
    public byte[] getData() {
        return block.getRawData();
    }

    @Override
    public byte[] getRawData() {
        return block.getRawData();
    }

    @Override
    public Pair<Object, List<String>> resolve(@NonNull List<String> path) {
        throw new RuntimeException("not supported here");
    }
}
