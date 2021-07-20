
import 'dart:core';
import 'dart:core';
import 'dart:typed_data';

class Cid implements Comparable<Cid> {
    String TAG = Cid.getSimpleName();
    int IDENTITY = 0x00;
    int Raw = 0x55;
    int DagProtobuf = 0x70;
    int DagCBOR = 0x71;
    int Libp2pKey = 0x72;

    Uint8List multihash;

    Cid(Uint8List multihash) {
        this.multihash = multihash;
    }

    static Cid Undef() {
        return new Cid(null);
    }

    static Cid tryNewCidV0(Uint8List mhash) {
        try {
            Multihash dec = Multihash.deserialize(mhash);

            if (dec.getType().index != Multihash.Type.sha2_256.index
                    || Multihash.Type.sha2_256.length != 32) {
                throw new RuntimeException("invalid hash for cidv0");
            }
            return new Cid(dec.toBytes());
        } catch (Throwable throwable) {
            throw new RuntimeException(throwable);
        }
    }

    static Cid nsToCid(String ns) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(ns.getBytes());
            return NewCidV1(Raw, hash);
        } catch (Throwable throwable) {
            throw new RuntimeException(throwable);
        }
    }

    static Cid decode(@NonNull String v) {
        if (v.length() < 2) {
            throw new RuntimeException("invalid cid");
        }

        if (v.length() == 46 && v.startsWith("Qm")) {
            Multihash hash = Multihash.fromBase58(v);
            Objects.requireNonNull(hash);
            return new Cid(hash.toBytes());
        }

        byte[] data = Multibase.decode(v);

        try (InputStream inputStream = new ByteArrayInputStream(data)) {
            long version = Multihash.readVarint(inputStream);
            if (version != 1) {
                throw new Exception("invalid version");
            }
            long codecType = Multihash.readVarint(inputStream);
            if (!(codecType == Cid.DagProtobuf || codecType == Cid.Raw || codecType == Cid.Libp2pKey)) {
                throw new Exception("not supported codec");
            }

            return new Cid(data);

        } catch (Throwable throwable) {
            throw new RuntimeException(throwable);
        }
    }

    static Cid NewCidV0(byte[] mhash) {
        return tryNewCidV0(mhash);
    }

    static Cid NewCidV1(long codecType, byte[] mhash) {

        try (ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            Multihash.putUvarint(out, 1);
            Multihash.putUvarint(out, codecType);
            out.write(mhash);
            return new Cid(out.toByteArray());
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
    }

    static Uint8List encode(Uint8List buf, int code) {

        try (ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            Multihash.putUvarint(out, code);
            Multihash.putUvarint(out, buf.length);
            out.write(buf);
            return out.toByteArray();
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
    }

    @Override
    boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        Cid cid = (Cid) o;
        return Arrays.equals(multihash, cid.multihash);
    }

    @Override
    int hashCode() {
        return Arrays.hashCode(multihash);
    }

    String String() {
        switch (getVersion()) {
            case 0:
                try {
                    return Multihash.deserialize(multihash).toBase58();
                } catch (IOException e) {
                    throw new RuntimeException(e);
                }
            case 1:
                return Multibase.encode(Multibase.Base.Base32, multihash);
            default:
                throw new RuntimeException();
        }
    }

    int getVersion() {
        byte[] bytes = multihash;
        if (bytes.length == 34 && bytes[0] == 18 && bytes[1] == 32) {
            return 0;
        }
        return 1;
    }

    int getType() {
        if (getVersion() == 0) {
            return DagProtobuf;
        }

        int type;
        try {
            InputStream is = new ByteArrayInputStream(multihash);
            Multihash.readVarint(is);
            type = Multihash.readVarint(is);
            is.close();
        } catch (Throwable throwable) {
            throw new RuntimeException(throwable);
        }
        return type;
    }

    Uint8List bytes() {
        return multihash;
    }

    bool isDefined() {
        return multihash != null;
    }

    Prefix getPrefix() {

        if (getVersion() == 0) {
            return new Prefix(DagProtobuf, 32, Multihash.Type.sha2_256.index, 0);
        }
        try (InputStream inputStream = new ByteArrayInputStream(bytes())) {
            long version = Multihash.readVarint(inputStream);
            if (version != 1) {
                throw new Exception("invalid version");
            }
            long codec = Multihash.readVarint(inputStream);
            if (!(codec == Cid.DagProtobuf || codec == Cid.Raw || codec == Cid.Libp2pKey)) {
                throw new Exception("not supported codec");
            }

            long mhtype = Multihash.readVarint(inputStream);

            long mhlen = Multihash.readVarint(inputStream);

            return new Prefix(codec, mhlen, mhtype, version);


        } catch (Throwable throwable) {
            throw new RuntimeException(throwable);
        }
    }

    @Override
    int compareTo(Cid o) {
        return Integer.compare(this.hashCode(), o.hashCode());
    }

    Uint8List getHash() {

        if (getVersion() == 0) {
            return multihash;
        } else {
            Uint8List data = bytes();
            try (InputStream inputStream = new ByteArrayInputStream(data)) {
                long version = Multihash.readVarint(inputStream);
                if (version != 1) {
                    throw new Exception("invalid version");
                }
                long codec = Multihash.readVarint(inputStream);
                if (!(codec == Cid.DagProtobuf || codec == Cid.Raw || codec == Cid.Libp2pKey)) {
                    throw new Exception("not supported codec");
                }

                try (ByteArrayOutputStream outputStream = new ByteArrayOutputStream()) {
                    byte[] buf = new byte[data.length];
                    int n;
                    while ((n = inputStream.read(buf)) > 0) {
                        outputStream.write(buf, 0, n);
                    }
                    return outputStream.toByteArray();
                }
            } catch (Throwable throwable) {
                throw new RuntimeException(throwable);
            }
        }

    }
}