import 'package:ipfslite/format/Stack.dart';

import 'NavigableNode.dart';
import 'Node.dart';
import 'Stage.dart';

class Walker {


    NavigableNode root;

    Walker(NavigableNode navigableNode) {
        this.root = navigableNode;

    }

    static Walker NewWalker(NavigableNode navigableNode) {
        return new Walker(navigableNode);
    }


    NavigableNode next(Closeable closeable, Visitor visitor) throws ClosedException {


        if (!visitor.isRootVisited(true)) {
            Stage stage = visitor.peekStage();
            Objects.requireNonNull(stage);
            if (stage.getNode().equals(root)) {
                return root;
            }
        }
        if (!visitor.isEmpty()) {

            boolean success = down(closeable, visitor);
            if (success) {
                Stage stage = visitor.peekStage();
                Objects.requireNonNull(stage);
                return stage.getNode();
            }

            success = up(visitor);

            if (success) {
                return next(closeable, visitor);
            }
        }
        return null;
    }

    boolean up(@NonNull Visitor visitor) {

        if (!visitor.isEmpty()) {
            visitor.popStage();
        } else {
            return false;
        }
        if (!visitor.isEmpty()) {
            boolean result = nextChild(visitor);
            if (result) {
                return true;
            } else {
                return up(visitor);
            }
        } else {
            return false;
        }
    }


    boolean nextChild(@NonNull Visitor visitor) {
        Stage stage = visitor.peekStage();
        NavigableNode activeNode = stage.getNode();

        if (stage.index() + 1 < activeNode.childTotal()) {
            stage.incrementIndex();
            return true;
        }

        return false;
    }


    boolean down(@NonNull Closeable closeable, @NonNull Visitor visitor) throws ClosedException {


        NavigableNode child = fetchChild(closeable, visitor);
        if (child != null) {
            visitor.pushActiveNode(child);
            return true;
        }
        return false;
    }


    NavigableNode fetchChild(@NonNull Closeable closeable, @NonNull Visitor visitor) throws ClosedException {
        Stage stage = visitor.peekStage();
        NavigableNode activeNode = stage.getNode();
        int index = stage.index();
        Objects.requireNonNull(activeNode);

        if (index >= activeNode.childTotal()) {
            return null;
        }

        return activeNode.fetchChild(closeable, index);
    }

    NavigableNode getRoot() {
        return root;
    }

    Map<Stack<Stage>, Long> seek(@NonNull Closeable closeable,
                                         @NonNull Stack<Stage> stack,
                                         long offset) throws ClosedException {

        if (offset < 0) {
            throw new RuntimeException("invalid offset");
        }

        if (offset == 0) {
            return Pair.create(stack, 0L);
        }

        long left = offset;

        NavigableNode visitedNode = stack.peek().getNode();

        Node node = NavigableIPLDNode.extractIPLDNode(visitedNode);

        if (node.getLinks().size() > 0) {
            // Internal node, should be a `mdag.ProtoNode` containing a
            // `unixfs.FSNode` (see the `balanced` package for more details).
            FSNode fsNode = FSNode.extractFSNode(node);

            // If there aren't enough size hints don't seek
            // (see the `io.EOF` handling error comment below).
            if (fsNode.numChildren() != node.getLinks().size()) {
                throw new RuntimeException("ErrSeekNotSupported");
            }


            // Internal nodes have no data, so just iterate through the
            // sizes of its children (advancing the child index of the
            // `dagWalker`) to find where we need to go down to next in
            // the search
            for (int i = 0; i < fsNode.numChildren(); i++) {

                long childSize = fsNode.getBlockSize(i);

                if (childSize > left) {
                    stack.peek().setIndex(i);

                    NavigableNode fetched = visitedNode.fetchChild(closeable, i);
                    stack.push(new Stage(fetched, 0));

                    return seek(closeable, stack, left);
                }
                left -= childSize;
            }
        }

        return Pair.create(stack, left);
    }

    Pair<Stack<Stage>, Long> seek(@NonNull Closeable closeable, long offset) throws ClosedException {

        Stack<Stage> stack = new Stack<>();
        stack.push(new Stage(getRoot(), 0));

        return seek(closeable, stack, offset);

    }
}