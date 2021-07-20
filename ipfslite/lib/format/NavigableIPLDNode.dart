import 'package:ipfslite/cid/Cid.dart';

class NavigableIPLDNode implements NavigableNode {
    String TAG = NavigableIPLDNode.class.getSimpleName();

    Node node;
    NodeGetter nodeGetter;
    List<Cid> cids = new ArrayList<>();

    NavigableIPLDNode(Node node, @NonNull NodeGetter nodeGetter) {
        this.node = node;
        this.nodeGetter = nodeGetter;
        fillLinkCids(node);
    }

    public static NavigableIPLDNode NewNavigableIPLDNode(
            @NonNull Node node, @NonNull NodeGetter nodeGetter) {
        return new NavigableIPLDNode(node, nodeGetter);
    }

    public static Node extractIPLDNode(@NonNull NavigableNode node) {
        if (node instanceof NavigableIPLDNode) {
            NavigableIPLDNode navigableIPLDNode = (NavigableIPLDNode) node;
            return navigableIPLDNode.GetIPLDNode();
        }
        throw new RuntimeException("not expected behaviour");
    }

    public Node GetIPLDNode() {
        return node;
    }

    private void fillLinkCids(@NonNull Node node) {
        List<Link> links = node.getLinks();

        for (Link link : links) {
            cids.add(link.getCid());
        }
    }

    @Override
    public NavigableNode fetchChild(@NonNull Closeable ctx, int childIndex) throws ClosedException {
        Node child = getPromiseValue(ctx, childIndex);
        Objects.requireNonNull(child);
        return NewNavigableIPLDNode(child, nodeGetter);

    }


    @Override
    public Cid getChild(int index) {
        return cids.get(index);
    }

    @Override
    public Cid getCid() {
        return node.getCid();
    }

    @Override
    public int childTotal() {
        return GetIPLDNode().getLinks().size();
    }


    private Node getPromiseValue(Closeable ctx, int childIndex) throws ClosedException {
        return nodeGetter.getNode(ctx, cids.get(childIndex), false);

    }

    @Override
    public String toString() {
        return node.toString() + " (" + childTotal() + ") ";
    }
}
