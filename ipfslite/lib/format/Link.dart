import 'dart:typed_data';

class Link {

    final Cid cid;
    final String name;
    final long size;


    Link(Cid cid, String name, long size) {
        this.cid = cid;
        this.name = name;
        this.size = size;
    }

    static Link create(Uint8List hash, String name, long size) {
        assert(hash);
        assert(name);
        Cid cid = new Cid(hash);
        return new Link(cid, name, size);
    }

    static Link createLink(Node node, String name) {
        long size = node.size();
        return new Link(node.getCid(), name, size);
    }

    Cid getCid() {
        return cid;
    }

    int getSize() {
        return size;
    }

    String getName() {
        return name;
    }

    @Override
    public String toString() {
        return "Link{" +
                "cid='" + cid + '\'' +
                ", name='" + name + '\'' +
                ", size=" + size +
                '}';
    }

    Node getNode(@NonNull Closeable ctx, @NonNull NodeGetter nodeGetter) throws ClosedException {
        return nodeGetter.getNode(ctx, getCid(), true);
    }

}