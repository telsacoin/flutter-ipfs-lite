import 'Node.dart';

class ProtoNode implements Node {
    private static final String TAG = ProtoNode.getSimpleName();
    private final List<Link> links = Collections.synchronizedList(new ArrayList<>());
    public Cid cached;
    private byte[] data;
    private byte[] encoded;
    private Builder builder;

    public ProtoNode() {
    }

    public ProtoNode(@NonNull byte[] data) {
        this.data = data;
    }

    @Override
    public Pair<Link, List<String>> resolveLink(@NonNull List<String> path) {

        if (path.size() == 0) {
            throw new RuntimeException("end of path, no more links to resolve");
        }
        String name = path.get(0);
        Link lnk = getNodeLink(name);
        List<String> left = new ArrayList<>(path);
        left.remove(name);
        return Pair.create(lnk, left);
    }

    @NonNull
    private Link getNodeLink(@NonNull String name) {
        for (Link link : links) {
            if (Objects.equals(link.getName(), name)) {
                return new Link(link.getCid(), link.getName(), link.getSize());
            }
        }
        throw new RuntimeException("" + name + " not found");
    }

    public void unmarshal(byte[] encoded) {

        try {

            Merkledag.PBNode pbNode = Merkledag.PBNode.parseFrom(encoded);
            List<Merkledag.PBLink> pbLinks = pbNode.getLinksList();
            for (Merkledag.PBLink pbLink : pbLinks) {
                links.add(Link.create(pbLink.getHash().toByteArray(), pbLink.getName(),
                        pbLink.getTsize()));
            }

            links.sort((o1, o2) -> o1.getName().compareTo(o2.getName()));

            this.data = pbNode.getData().toByteArray();

            this.encoded = encoded;

        } catch (Throwable throwable) {
            LogUtils.error(TAG, throwable);
        }

    }

    public long size() {
        byte[] b = encodeProtobuf();
        long size = b.length;
        for (Link link : links) {
            size += link.getSize();
        }
        return size;
    }

    @Override
    public List<Link> getLinks() {
        return new ArrayList<>(links);
    }

    @Override
    public Cid getCid() {
        if (encoded != null && cached.isDefined()) {
            return cached;
        }
        byte[] data = getRawData();

        if (encoded != null && cached.isDefined()) {
            return cached;
        }
        cached = getCidBuilder().sum(data);
        return cached;
    }

    @Override
    public byte[] getData() {
        return data;
    }

    public void setData(byte[] fileData) {
        encoded = null;
        cached = Cid.Undef();
        data = fileData;
    }

    @Override
    public byte[] getRawData() {
        return encodeProtobuf();
    }


    // Marshal encodes a *Node instance into a new byte slice.
    // The conversion uses an intermediate PBNode.
    private byte[] marshal() {

        Merkledag.PBNode.Builder pbn = Merkledag.PBNode.newBuilder();

        links.sort((o1, o2) -> o1.getName().compareTo(o2.getName()));// keep links sorted

        synchronized (links) {
            for (Link link : links) {

                Merkledag.PBLink.Builder lnb = Merkledag.PBLink.newBuilder().setName(link.getName())
                        .setTsize(link.getSize());

                if (link.getCid().isDefined()) {
                    ByteString hash = ByteString.copyFrom(link.getCid().bytes());
                    lnb.setHash(hash);
                }

                pbn.addLinks(lnb.build());
            }
        }
        if (this.data.length > 0) {
            pbn.setData(ByteString.copyFrom(this.data));
        }

        return pbn.build().toByteArray();
    }

    private byte[] encodeProtobuf() {

        links.sort((o1, o2) -> o1.getName().compareTo(o2.getName()));// keep links sorted
        if (encoded == null) {
            cached = Cid.Undef();
            encoded = marshal();
        }

        if (!cached.isDefined()) {
            cached = getCidBuilder().sum(encoded);
        }

        return encoded;
    }

    public Builder getCidBuilder() {
        if (builder == null) {
            builder = v0CidPrefix;
        }
        return builder;
    }

    public void setCidBuilder(@Nullable Builder builder) {
        if (builder == null) {
            this.builder = v0CidPrefix;
        } else {
            this.builder = builder.withCodec(Cid.DagProtobuf);
            this.cached = Cid.Undef();
        }
    }

    public Node copy() {


        // Copy returns a copy of the node.
        // NOTE: Does not make copies of Node objects in the links.

        ProtoNode protoNode = new ProtoNode();

        protoNode.data = Arrays.copyOf(getData(), getData().length);


        synchronized (links) {
            if (links.size() > 0) {
                protoNode.links.addAll(links);
            }
        }
        protoNode.builder = builder;

        return protoNode;


    }

    public void removeNodeLink(@NonNull String name) {
        encoded = null;
        synchronized (links) {
            for (Link link : links) {
                if (Objects.equals(link.getName(), name)) {
                    links.remove(link);
                    break;
                }
            }
        }
    }

    public void addNodeLink(@NonNull String name, @NonNull Node link) {

        encoded = null;

        Link lnk = Link.createLink(link, name);

        addRawLink(lnk);

    }

    private void addRawLink(@NonNull Link link) {
        encoded = null;

        synchronized (links) {
            links.add(link);
        }
    }

    @Override
    Pair<Object, List<String>> resolve(@NonNull List<String> path) {
        Pair<Link, List<String>> res = resolveLink(path);
        return Pair.create(res.first, res.second);
    }

}
