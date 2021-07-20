import 'dart:developer' as logger;
import 'dart:io';
import 'dart:isolate';
import 'package:typed_data/typed_data.dart' as typed;
import 'dart:ffi';




class ipfslite {

  bool? offline;
  int? reprovideInterval;


  var defaultReprovideInterval = 12 * DateTime.Hour;

  ipfslite(
    this.offline;
    this.defaultReprovideInterval;
  );

    //the init function
  void init() {
    ipld.Register(cid.DagProtobuf, merkledag.DecodeProtobufBlock);
    ipld.Register(cid.Raw, merkledag.DecodeRawBlock);
    ipld.Register(cid.DagCBOR, cbor.DecodeBlock);
  }

}
