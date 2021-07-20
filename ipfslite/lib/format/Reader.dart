import 'dart:typed_data';

abstract class Reader {
  int read(Uint8List bytes);
}
