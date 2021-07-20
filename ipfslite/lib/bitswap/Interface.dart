import 'package:flutter/cupertino.dart';
import 'package:ipfslite/core/Closeable.dart';

abstract class Interface {

    void reset();

    Block getBlock(Closeable closeable, Cid cid, bool root) on ClosedException;

    void preload(@NonNull Closeable closeable, @NonNull List<Cid> cids);
}