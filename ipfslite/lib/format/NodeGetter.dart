import 'package:ipfslite/cid/Cid.dart';
import 'package:ipfslite/core/Closeable.dart';

import 'Node.dart';

abstract class NodeGetter {
  Node getNode(Closeable closeable, Cid cid, bool root);

  void preload(Closeable ctx, List<Cid> cids);
}
