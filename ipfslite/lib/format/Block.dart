import 'dart:typed_data';

abstract class Block {
  Uint8List getRawData();

  Cid getCid();

  String toString();
}
