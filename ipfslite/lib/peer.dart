import 'dart:developer';
import 'dart:io';

import 'package:ipfslite/server.dart';

class PeerException implements Exception {
  String cause;
  PeerException(this.cause);
}

class LifecycleObserver {}

enum NodeState { Start, Stop }

class Peer implements LifecycleObserver {
  static final String tag = "Peer";
  static bool? mem;
  static bool? mode;
  static String? path;
  static int? port;

  static NodeState state = NodeState.Stop;

  //
  // init the gRPC IPFS Lite server instance with the provided repo path
  //
  Peer(String datastorePath, bool debug, bool lowMem) {
    path = datastorePath;
    mode = debug;
    mem = lowMem;
  }

  void ready() async {
    if (!started()) {
      log("Peer not started");
      throw new PeerException("Peer not started");
    }
  }

  // start IPFS Lite instance with the provided repo path
  // @throws Exception The exception that occurred
  static void start() async {
    try {
      if (state == NodeState.Start) {
        return;
      }
      startServer(InternetAddress.anyIPv4);
      /* blockingStub = IpfsLiteGrpc.newBlockingStub(channel);
      asyncStub = IpfsLiteGrpc.newStub(channel); */

      state = NodeState.Start;
    } on PeerException catch (e) {
      throw new PeerException(e.cause);
    }
  }

  static void stop() async {
    try {
      if (state == NodeState.Stop) {
        return;
      }
      Mobile.stop();
      state = NodeState.Stop;
    } on PeerException catch (e) {
      throw new PeerException(e.cause);
    }

    static GetFileRequest FileRequest(String cid) async{
         return GetFileRequest.newBuilder()
                 .setCid(cid)
                 .build();
    }

    static AddParams.Builder AddFileParams(ByteString data) async{
        return AddParams.newBuilder()
                .setChunker(data.toStringUtf8());
    }

    static AddFileRequest.Builder FileData(ByteString data) async{
        return AddFileRequest.newBuilder()
                .setAddParams(AddFileParams(data))
                .setChunk(data);
    }

    static AddFileRequest.Builder FileRequestHeader() async{
        AddParams.Builder params = AddParams.newBuilder();
        return AddFileRequest.newBuilder()
                .setAddParams(params);
    }

    void streamDataChunks(byte[] data, StreamObserver<AddFileRequest> requestStream) async{
        try {
            // Start stream
            AddFileRequest.Builder requestHeader = FileRequestHeader();
            requestStream.onNext(requestHeader.build());
            // Send file segments of 1024b
            int blockSize = 1024;
            int blockCount = (data.length + blockSize - 1) / blockSize;

            byte[] range;
            for (int i = 1; i < blockCount; i++) {
                int idx = (i - 1) * blockSize;
                range = Arrays.copyOfRange(data, idx, idx + blockSize);
                AddFileRequest.Builder requestData = FileData(ByteString.copyFrom(range));
                requestStream.onNext(requestData.build());
            }
            int end = -1;
            if (data.length % blockSize == 0) {
                end = data.length;
            } else {
                end = data.length % blockSize + blockSize * (blockCount - 1);
            }
            range = Arrays.copyOfRange(data, (blockCount - 1) * blockSize, end);
            AddFileRequest.Builder requestData = FileData(ByteString.copyFrom(range));
            requestStream.onNext(requestData.build());
        } catch (RuntimeException e) {
            requestStream.onError(e);
            throw e;
        }
        requestStream.onCompleted();
    }
  }

  void addFile(byte[] data, final AddFileHandler handler) {

        StreamObserver<AddFileRequest> addFileRequest = asyncStub.addFile(new StreamObserver<AddFileResponse>() {
            @Override
            public void onNext(AddFileResponse value) {
                try {
                    String cid = value.getNode().getBlock().getCid();
                    handler.onNext(cid);
                } catch (Throwable t) {
                    handler.onError(t);
                }
            }

            @Override
            public void onError(Throwable t) {
                logger.log(Level.INFO, "GetFileError: " + t.getLocalizedMessage());
                handler.onError(t);
            }

            @Override
            public void onCompleted() {
                logger.log(Level.INFO, "GetFileComplete");
                handler.onComplete();
            }
        });

        // Stream the file over a background thread
        new Thread(() -> {
            streamDataChunks(data, addFileRequest);
        }).start();
    }

    void getFile(String cid, final GetFileHandler handler) {
        asyncStub.getFile(FileRequest(cid), new StreamObserver<GetFileResponse>() {
            @Override
            public void onNext(GetFileResponse value) {
                handler.onNext(value.getChunk().toByteArray());
            }

            @Override
            public void onError(Throwable t) {
                logger.log(Level.INFO, "GetFileError: " + t.getLocalizedMessage());
                handler.onError(t);
            }

            @Override
            public void onCompleted() {
                logger.log(Level.INFO, "GetFileComplete");
                handler.onComplete();
            }
        });
    }

    byte[] getFileSync(String cid) throws Exception {
        ready();
        GetFileRequest request = FileRequest(cid);
        Iterator<GetFileResponse> response = blockingStub.getFile(request);
        // TODO is there a more efficient way to do this?
        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        while (response.hasNext()) {
            byte[] bytes = response.next().getChunk().toByteArray();
            baos.write(bytes);
        }
        return baos.toByteArray();
    }

    void resolveLink(String link, final ResolveLinkHandler handler) {
        String[] parts = link.split("/");
        if (parts.length == 0) {
            handler.onComplete();
        }

        ResolveLinkRequest.Builder request = ResolveLinkRequest
                .newBuilder()
                .setNodeCid(parts[0]);


        String linkPath = link.replace(parts[0] + "/", "");
        if (linkPath != "") {
            request.addPath(linkPath);
        }

        asyncStub.resolveLink(request.build(), new StreamObserver<ResolveLinkResponse>() {
            @Override
            public void onNext(ResolveLinkResponse value) {
                handler.onNext(value.getLink().getCid());
            }

            @Override
            public void onError(Throwable t) {
                logger.log(Level.INFO, "ResolveLinkResponseError: " + t.getLocalizedMessage());
                handler.onError(t);
            }

            @Override
            public void onCompleted() {
                logger.log(Level.INFO, "ResolveLinkResponseComplete");
                handler.onComplete();
            }
        });
    }


    void getNode(String cid, final ResolveNodeHandler handler) {
        GetNodeRequest.Builder request = GetNodeRequest
                .newBuilder()
                .setCid(cid);

        asyncStub.getNode(request.build(), new StreamObserver<GetNodeResponse>() {
            @Override
            public void onNext(GetNodeResponse value) {
                Node node = value.getNode();
                handler.onNext(node);
            }

            @Override
            public void onError(Throwable t) {
                logger.log(Level.INFO, "GetNodeError: " + t.getLocalizedMessage());
                handler.onError(t);
            }

            @Override
            public void onCompleted() {
                logger.log(Level.INFO, "GetNodeComplete");
                handler.onComplete();
            }
        });
    }

  
    public void removeNode(String cid, final RemoveNodeHandler handler) {
        RemoveNodeRequest.Builder request = RemoveNodeRequest
                .newBuilder()
                .setCid(cid);

        asyncStub.removeNode(request.build(), new StreamObserver<RemoveNodeResponse>() {
            @Override
            public void onNext(RemoveNodeResponse value) {
                handler.onNext(value.toString());
            }

            @Override
            public void onError(Throwable t) {
                logger.log(Level.INFO, "RemoveNodeError: " + t.getLocalizedMessage());
                handler.onError(t);
            }

            @Override
            public void onCompleted() {
                logger.log(Level.INFO, "RemoveNodeComplete");
                handler.onComplete();
            }
        });
    }

    bool started() {
        return state == NodeState.Start;
    }

}

abstract class AddFileHandler {
    void onNext(final String cid);
    void onComplete();
    void onError(final Exception t);
}

abstract class ResolveLinkHandler {
        void onNext(final String cid);
        void onComplete();
        void onError(final Exception t);
}

abstract class ResolveNodeHandler {
        void onNext(final Node node);
        void onComplete();
        void onError(final Exception t);
    }

abstract class RemoveNodeHandler {
    void onNext(String cid);
    void onComplete();
    void onError(final Exception t);
}


