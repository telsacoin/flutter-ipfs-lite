import 'dart:typed_data';

class Multiaddr {
    Uint8List raw;
    String address;

    Multiaddr(String address) {
        this.address = address;
        this.raw = decodeFromString(address);
    }

    Multiaddr(Uint8List raw) {
        this.address = encodeToString(raw); // check validity
        this.raw = raw;
    }

    private static byte[] decodeFromString(String addr) {
        while (addr.endsWith("/"))
            addr = addr.substring(0, addr.length() - 1);
        String[] parts = addr.split("/");
        if (parts[0].length() != 0)
            throw new IllegalStateException("MultiAddress must start with a /");

        ByteArrayOutputStream bout = new ByteArrayOutputStream();
        try {
            for (int i = 1; i < parts.length; ) {
                String part = parts[i++];
                Protocol p = Protocol.get(part);
                p.appendCode(bout);
                if (p.size() == 0)
                    continue;

                String component = p.isTerminal() ?
                        Stream.of(Arrays.copyOfRange(parts, i, parts.length)).reduce("", (a, b) -> a + "/" + b) :
                        parts[i++];
                if (component.length() == 0)
                    throw new IllegalStateException("Protocol requires address, but non provided!");

                bout.write(p.addressToBytes(component));
                if (p.isTerminal())
                    break;
            }
            return bout.toByteArray();
        } catch (IOException e) {
            throw new IllegalStateException("Error decoding multiaddress: " + addr);
        }
    }

    private static String encodeToString(byte[] raw) {
        StringBuilder b = new StringBuilder();
        InputStream in = new ByteArrayInputStream(raw);
        try {
            while (true) {
                int code = (int) Protocol.readVarint(in);
                Protocol p = Protocol.get(code);
                b.append("/" + p.name());
                if (p.size() == 0)
                    continue;

                String addr = p.readAddress(in);
                if (addr.length() > 0)
                    b.append("/" + addr);
            }
        } catch (EOFException ignore) {
            // ignore
        } catch (IOException e) {
            throw new RuntimeException(e);
        }

        return b.toString();
    }

    public byte[] getBytes() {
        return Arrays.copyOfRange(raw, 0, raw.length);
    }

    public String getHost() {
        String[] parts = toString().substring(1).split("/");
        if (parts[0].startsWith("ip") || parts[0].startsWith("dns"))
            return parts[1];
        throw new IllegalStateException("This multiaddress doesn't have a host: " + toString());
    }

    public int getPort() {
        String[] parts = toString().substring(1).split("/");
        if (parts[2].startsWith("tcp") || parts[2].startsWith("udp"))
            return Integer.parseInt(parts[3]);
        throw new IllegalStateException("This multiaddress doesn't have a port: " + toString());
    }

    @NonNull
    @Override
    public String toString() {
        return address;
    }

    @Override
    public boolean equals(Object other) {
        if (!(other instanceof Multiaddr))
            return false;
        return Arrays.equals(raw, ((Multiaddr) other).raw);
    }

    @Override
    public int hashCode() {
        return Arrays.hashCode(raw);
    }

    public String getStringComponent(Protocol.Type type) {
        String[] tokens = address.split("/");
        for (int i = 0; i < tokens.length; i++) {
            String token = tokens[i];
            if (Objects.equals(token, type.name)) {
                return tokens[i + 1];
            }
        }
        return null;
    }

    public boolean has(@NonNull Protocol.Type type) {
        String[] tokens = address.split("/");
        for (String token : tokens) {
            if (Objects.equals(token, type.name)) {
                return true;
            }
        }
        return false;
    }

}