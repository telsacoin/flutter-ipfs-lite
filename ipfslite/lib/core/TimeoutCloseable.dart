import 'package:ipfslite/core/Closeable.dart';

class TimeoutCloseable implements Closeable {
  int? timeout;
  late Closeable closeable;
  int? start;

  TimeoutCloseable(Closeable closeable, {int? timeout}) {
    this.closeable = closeable;
    this.timeout = timeout;
    this.start = DateTime.now().millisecondsSinceEpoch;
  }

  @override
  bool isClosed() {
    if (closeable != null) {
      return closeable.isClosed() ||
          (DateTime.now().millisecondsSinceEpoch - start!) > (timeout! * 1000);
    }
    return (DateTime.now().millisecondsSinceEpoch - start!) > (timeout! * 1000);
  }
}
