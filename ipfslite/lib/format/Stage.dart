class Stage {
  NavigableNode node;
  int index;

  Stage(NavigableNode node, int index) {
    this.node = node;
    this.index = index;
  }

  NavigableNode getNode() {
    return node;
  }

  void incrementIndex() {
    index = index + 1;
  }

  int index() {
    return index;
  }

  void setIndex(int value) {
    index = value;
  }

  Stage copy() {
    return new Stage(node, index);
  }

  @Override
  String toString() {
    return node.toString() + " " + index + " ";
  }
}
