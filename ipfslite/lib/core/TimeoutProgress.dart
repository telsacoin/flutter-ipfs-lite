import 'package:ipfslite/core/Progress.dart';

import 'Closeable.dart';

abstract class TimeoutProgress implements Progress {
  int? timeout;
  late Closeable closeable;
  int? start;

  TimeoutProgress(Closeable closeable, {int? timeout}) {
    this.closeable = closeable;
    this.timeout = timeout;
    this.start = DateTime.now().millisecondsSinceEpoch;
  }

  bool isClosed() {
    if (closeable != null) {
      return closeable.isClosed() ||
          (DateTime.now().millisecondsSinceEpoch - start!) > (timeout! * 1000);
    }
    return (DateTime.now().millisecondsSinceEpoch - start!) > (timeout! * 1000);
  }
}
