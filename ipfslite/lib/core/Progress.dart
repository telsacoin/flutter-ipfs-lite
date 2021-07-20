import 'package:ipfslite/core/Closeable.dart';

abstract class Progress extends Closeable {
  void setProgress(int progress);
  bool doProgress();
}
