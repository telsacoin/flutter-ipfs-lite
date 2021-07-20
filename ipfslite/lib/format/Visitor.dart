import 'Stack.dart';

class Visitor {
    Stack<Stage> stack = new Stack<Stage>();
    bool rootVisited;

    Visitor(@NonNull NavigableNode root) {
        rootVisited = false;
        pushActiveNode(root);
    }

    public void reset(@NonNull Stack<Stage> stages) {
        stack.clear();
        stack.addAll(stages);
        rootVisited = true;
    }

    @NonNull
    public Stack<Stage> copy() {
        Stack<Stage> copy = new Stack<>();
        for (Stage stage : stack) {
            copy.add(stage.copy());
        }
        return copy;
    }

    public void pushActiveNode(@NonNull NavigableNode node) {
        stack.push(new Stage(node, 0));
    }


    public void popStage() {
        stack.pop();
    }

    public Stage peekStage() {
        return stack.peek();
    }

    public boolean isRootVisited(boolean visited) {
        boolean temp = rootVisited;
        rootVisited = visited;
        return temp;
    }


    public boolean isEmpty() {
        return stack.isEmpty();
    }

    @NonNull
    @Override
    public String toString() {
        String result = "";
        for (Stage stage : stack) {
            result = result.concat(stage.toString());
        }
        return result;
    }
}