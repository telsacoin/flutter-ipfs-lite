import 'package:ipfslite/core/Closeable.dart';

abstract class NavigableNode {
  NavigableNode fetchChild(Closeable ctx, int childIndex);

  int childTotal();

  Cid getChild(int index);

  Cid getCid();
}
