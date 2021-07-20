class DnsResolver {
    static final String DNS_ADDR = "dnsaddr=";
    static final String DNS_LINK = "dnslink=";
    static final String IPv4 = "/ip4/";
    static final String IPv6 = "/ip6/";
    static final String DNS_ADDR_PATH = "/dnsaddr/";
    static final String DNS_PATH = "/dns/";
    static final String DNS4_PATH = "/dns4/";
    static final String DNS6_PATH = "/dns6/";
    static final String TAG = (DnsResolver).toString();
    static DnsClient INSTANCE = null;


    @NonNull
    static String resolveDnsLink(String host) {

        List<String> txtRecords = getTxtRecords("_dnslink.".concat(host));
        for (String txtRecord : txtRecords) {
            try {
                if (txtRecord.startsWith(DNS_LINK)) {
                    return txtRecord.replaceFirst(DNS_LINK, "");
                }
            } catch (Throwable throwable) {
                LogUtils.error(TAG, throwable);
            }
        }
        return "";
    }

    static List<String> getTxtRecords(@NonNull String host) {
        List<String> txtRecords = new ArrayList<>();
        try {
            DnsClient client = getInstance();
            DnsQueryResult result = client.query(host, Record.TYPE.TXT);
            DnsMessage response = result.response;
            List<Record<? extends Data>> records = response.answerSection;
            for (Record<? extends Data> record : records) {
                Data payload = record.getPayload();
                if (payload instanceof TXT) {
                    TXT text = (TXT) payload;
                    txtRecords.add(text.getText());
                } else {
                    LogUtils.warning(TAG, payload.toString());
                }
            }
        } catch (Throwable throwable) {
            LogUtils.debug(TAG, "" + throwable.getClass().getName());
        }
        return txtRecords;
    }

    static String resolveDns(@NonNull String multiaddress) throws UnknownHostException {
        if (!multiaddress.startsWith(DNS_PATH)) {
            throw new RuntimeException();
        }
        String query = multiaddress.replaceFirst(DNS_PATH, "");
        String host = query.split("/")[0];
        InetAddress address = InetAddress.getByName(host);
        String ip = IPv4;
        if (address instanceof Inet6Address) {
            ip = IPv6;
        }
        String hostAddress = address.getHostAddress();
        return ip.concat(query.replaceFirst(host, hostAddress));
    }

    static String resolveDns4Address(@NonNull String multiaddress) throws UnknownHostException {
        if (!multiaddress.startsWith(DNS4_PATH)) {
            throw new RuntimeException();
        }
        String query = multiaddress.replaceFirst(DNS4_PATH, "");
        String host = query.split("/")[0];
        InetAddress address = InetAddress.getByName(host);
        String ip = IPv4;
        if (address instanceof Inet6Address) {
            ip = IPv6;
        }
        String hostAddress = address.getHostAddress();
        return ip.concat(query.replaceFirst(host, hostAddress));
    }


    static String resolveDns6Address(@NonNull String multiaddress) throws UnknownHostException {
        if (!multiaddress.startsWith(DNS6_PATH)) {
            throw new RuntimeException();
        }
        String query = multiaddress.replaceFirst(DNS6_PATH, "");
        String host = query.split("/")[0];
        InetAddress address = InetAddress.getByName(host);
        String ip = IPv4;
        if (address instanceof Inet6Address) {
            ip = IPv6;
        }
        String hostAddress = address.getHostAddress();
        return ip.concat(query.replaceFirst(host, hostAddress));
    }

    static Multiaddr resolveDns6(@NonNull Multiaddr multiaddr) throws UnknownHostException {
        return new Multiaddr(resolveDns6Address(multiaddr.toString()));
    }

    static Multiaddr resolveDns4(@NonNull Multiaddr multiaddr) throws UnknownHostException {
        return new Multiaddr(resolveDns4Address(multiaddr.toString()));
    }

    static Multiaddr resolveDns(@NonNull Multiaddr multiaddr) throws UnknownHostException {
        return new Multiaddr(resolveDns(multiaddr.toString()));
    }

    static List<Multiaddr> resolveDnsAddress(@NonNull Multiaddr multiaddr) {
        List<Multiaddr> multiaddrs = new ArrayList<>();
        String host = multiaddr.getStringComponent(Protocol.Type.DNSADDR);
        if (host != null) {
            Set<String> addresses = resolveDnsAddress(host);
            String peerId = multiaddr.getStringComponent(Protocol.Type.P2P);
            for (String addr : addresses) {
                if (peerId != null) {
                    if (addr.endsWith(peerId)) {
                        try {
                            multiaddrs.add(new Multiaddr(addr));
                        } catch (Throwable throwable) {
                            LogUtils.verbose(TAG, throwable.getClass().getSimpleName());
                        }
                    }
                }
            }
        }
        return multiaddrs;
    }


    static Set<String> resolveDnsAddress(@NonNull String host) {
        return resolveDnsAddressInternal(host, new HashSet<>());
    }

    @NonNull
    public static Set<String> resolveDnsAddressInternal(
            @NonNull String host, @NonNull Set<String> hosts) {
        Set<String> multiAddresses = new HashSet<>();

        // recursion protection
        if (hosts.contains(host)) {
            hosts.add(host);
        }

        List<String> txtRecords = getTxtRecords("_dnsaddr." + host);
        for (String txtRecord : txtRecords) {
            try {
                if (txtRecord.startsWith(DNS_ADDR)) {
                    String testRecordReduced = txtRecord.replaceFirst(DNS_ADDR, "");
                    if (testRecordReduced.startsWith(DNS_ADDR_PATH)) {
                        String query = testRecordReduced.replaceFirst(DNS_ADDR_PATH, "");
                        String child = query.split("/")[0];
                        multiAddresses.addAll(resolveDnsAddressInternal(child, hosts));
                    } else if (testRecordReduced.startsWith(DNS4_PATH)) {
                        multiAddresses.add(resolveDns4Address(testRecordReduced));
                    } else if (testRecordReduced.startsWith(DNS6_PATH)) {
                        multiAddresses.add(resolveDns6Address(testRecordReduced));
                    } else {
                        multiAddresses.add(testRecordReduced);
                    }
                }
            } catch (Throwable throwable) {
                LogUtils.error(TAG, throwable);
            }
        }
        return multiAddresses;
    }

    @NonNull
    public static DnsClient getInstance() {
        if (INSTANCE == null) {
            synchronized (TAG.intern()) {
                if (INSTANCE == null) {
                    try {
                        INSTANCE = new DnsClient(new LruCache(128));
                    } catch (Throwable e) {
                        throw new RuntimeException(e);
                    }
                }
            }
        }
        return INSTANCE;
    }

}