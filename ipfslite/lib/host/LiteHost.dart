class LiteHostCertificate {
    public static final String certificatePrefix = "libp2p-tls-handshake:";
    private static final String TAG = LiteHostCertificate.class.getSimpleName();

    private static final int[] extensionPrefix = new int[]{1, 3, 6, 1, 4, 1, 53594};
    public static final int[] extensionID = getPrefixedExtensionID(new int[]{1, 1});


    /**
     * FIPS 140-2 encryption requires the RSA key length to be 2048 bits or greater.
     * Let's use that as a sane default but allow the default to be set dynamically
     * for those that need more stringent security requirements.
     */
    private final File certificate;
    private final File privateKey;
    private final X509Certificate cert;
    private final PrivateKey key;

    private final PublicKey publicKey;

    /**
     * Creates a new instance.
     *
     * @param fqdn   a fully qualified domain name
     * @param random the {@link SecureRandom} to use
     */
    public LiteHostCertificate(@NonNull Context context, PrivKey privKey,
                               KeyPair keypair, String fqdn, SecureRandom random)
            throws Exception {

        Date currentDate = new Date();
        LocalDateTime localDateTime = currentDate.toInstant().atZone(
                ZoneId.systemDefault()).toLocalDateTime();
        LocalDateTime notBeforeLocal = localDateTime.minusYears(1);
        LocalDateTime notAfterLocal = localDateTime.plusYears(99);
        Date notBefore = Date.from(notBeforeLocal.atZone(ZoneId.systemDefault()).toInstant());
        Date notAfter = Date.from(notAfterLocal.atZone(ZoneId.systemDefault()).toInstant());

        String algorithm = keypair.getPublic().getAlgorithm();
        String[] paths = generate(context, privKey, fqdn, keypair, random,
                notBefore, notAfter, algorithm);
        certificate = new File(paths[0]);
        privateKey = new File(paths[1]);
        key = keypair.getPrivate();
        publicKey = keypair.getPublic();
        FileInputStream certificateInput = null;
        try {
            certificateInput = new FileInputStream(certificate);
            cert = (X509Certificate) CertificateFactory.getInstance("X509").generateCertificate(certificateInput);
        } catch (Exception e) {
            throw new CertificateEncodingException(e);
        } finally {
            if (certificateInput != null) {
                try {
                    certificateInput.close();
                } catch (IOException e) {
                    LogUtils.error(TAG, e);
                }
            }
        }
    }


    public LiteHostCertificate(@NonNull Context context, PrivKey privKey, KeyPair keypair)
            throws Exception {
        this(context, privKey, keypair, "localhost");
    }


    public LiteHostCertificate(@NonNull Context context, PrivKey privKey, KeyPair keypair, String fqdn)
            throws Exception {
        // Bypass entropy collection by using insecure random generator.
        // We just want to generate it without any delay because it's for testing purposes only.
        this(context, privKey, keypair, fqdn, ThreadLocalInsecureRandom.current());
    }

    // getPrefixedExtensionID returns an Object Identifier
    // that can be used in x509 Certificates.
    public static int[] getPrefixedExtensionID(int[] suffix) {

        return Ints.concat(extensionPrefix, suffix);
    }

    static String[] generate(@NonNull Context context, PrivKey privKey, String fqdn, KeyPair keypair,
                             SecureRandom random, Date notBefore, Date notAfter,
                             String algorithm) throws Exception {
        PrivateKey key = keypair.getPrivate();

        BigInteger bigInteger = new BigInteger(64, random);
        // Prepare the information required for generating an X.509 certificate.
        X500Name owner = new X500Name("CN=" + fqdn);


        X509v3CertificateBuilder builder = new JcaX509v3CertificateBuilder(
                owner, bigInteger, notBefore, notAfter, owner, keypair.getPublic());

        PubKey pubKey = privKey.publicKey();
        byte[] keyBytes = Crypto.PublicKey.newBuilder().setType(pubKey.getKeyType())
                .setData(ByteString.copyFrom(pubKey.raw())).build().toByteArray();


        SubjectPublicKeyInfo subjectPublicKeyInfo = SubjectPublicKeyInfo.
                getInstance(keypair.getPublic().getEncoded());
        byte[] signature = privKey.sign(Bytes.concat(
                certificatePrefix.getBytes(), subjectPublicKeyInfo.getEncoded()));


        SignedKey signedKey = new SignedKey(keyBytes, signature);

        ASN1ObjectIdentifier indent = new ASN1ObjectIdentifier(getLiteExtension());
        builder.addExtension(indent, false, signedKey);


        ContentSigner signer = new JcaContentSignerBuilder(
                algorithm.equalsIgnoreCase("EC") ? "SHA256withECDSA" :
                        "SHA256WithRSAEncryption").build(key);
        X509CertificateHolder certHolder = builder.build(signer);
        X509Certificate cert = new JcaX509CertificateConverter().
                setProvider(BouncyCastleProvider.PROVIDER_NAME).getCertificate(certHolder);
        cert.verify(keypair.getPublic());

        return newSelfSignedCertificate(context, fqdn, key, cert);
    }

    public static String getLiteExtension() {
        return LiteHostCertificate.integersToString(LiteHostCertificate.extensionID);
    }

    public static String integersToString(int[] values) {
        try {
            String s = "";
            for (int i = 0; i < values.length; ++i) {
                if (i > 0) {
                    s = s.concat(".");
                }
                s = s.concat(String.valueOf(values[i]));
            }

            return s;
        } catch (Throwable throwable) {
            throw new RuntimeException(throwable);
        }
    }

    static String[] newSelfSignedCertificate(@NonNull Context context, @NonNull String fqdn,
                                             @NonNull PrivateKey key, @NonNull X509Certificate cert)
            throws IOException, CertificateEncodingException {
        File cacheDir = context.getCacheDir();

        final String keyText = "-----BEGIN PRIVATE KEY-----\n" +
                Base64.encodeToString(key.getEncoded(), 0) +
                "\n-----END PRIVATE KEY-----\n";

        File keyFile = File.createTempFile("keyutil_" + fqdn + '_', ".key", cacheDir);
        keyFile.deleteOnExit();

        OutputStream keyOut = new FileOutputStream(keyFile);
        try {
            keyOut.write(keyText.getBytes(StandardCharsets.US_ASCII));
            keyOut.close();
            keyOut = null;
        } finally {
            if (keyOut != null) {
                safeClose(keyFile, keyOut);
                safeDelete(keyFile);
            }
        }


        final String certText = "-----BEGIN CERTIFICATE-----\n" +
                Base64.encodeToString(cert.getEncoded(), 0) +
                "\n-----END CERTIFICATE-----\n";


        File certFile = File.createTempFile("keyutil_" + fqdn + '_', ".crt", cacheDir);
        certFile.deleteOnExit();

        OutputStream certOut = new FileOutputStream(certFile);
        try {
            certOut.write(certText.getBytes(StandardCharsets.US_ASCII));
            certOut.close();
            certOut = null;
        } finally {
            if (certOut != null) {
                safeClose(certFile, certOut);
                safeDelete(certFile);
                safeDelete(keyFile);
            }
        }

        return new String[]{certFile.getPath(), keyFile.getPath()};
    }

    private static void safeDelete(File certFile) {
        if (!certFile.delete()) {
            LogUtils.error(TAG, "Failed to delete a file: " + certFile);
        }
    }

    private static void safeClose(File keyFile, OutputStream keyOut) {
        try {
            keyOut.close();
        } catch (IOException e) {
            LogUtils.error(TAG, "Failed to close a file: " + keyFile, e);
        }
    }

    public static PubKey extractPublicKey(@NonNull X509Certificate cert) throws IOException {

        byte[] extension = cert.getExtensionValue(LiteHostCertificate.getLiteExtension());
        Objects.requireNonNull(extension);

        ASN1OctetString octs = (ASN1OctetString) ASN1Primitive.fromByteArray(extension);
        ASN1Primitive primitive = ASN1Primitive.fromByteArray(octs.getOctets());
        DLSequence sequence = (DLSequence) DERSequence.getInstance(primitive);
        DEROctetString pubKeyRaw = (DEROctetString) sequence.getObjectAt(0);

        PubKey pubKey = unmarshalPublicKey(pubKeyRaw.getOctets());
        Objects.requireNonNull(pubKey);

        DEROctetString signature = (DEROctetString) sequence.getObjectAt(1);
        byte[] skSignature = signature.getOctets();

        byte[] certKeyPub = cert.getPublicKey().getEncoded();

        byte[] verify = Bytes.concat(LiteHostCertificate.certificatePrefix.getBytes(), certKeyPub);

        boolean result = pubKey.verify(verify, skSignature);

        if (!result) {
            throw new RuntimeException("Verification process failed");
        }
        return pubKey;

    }

    private static PubKey unmarshalPublicKey(byte[] data) throws InvalidProtocolBufferException {

        Crypto.PublicKey pmes = Crypto.PublicKey.parseFrom(data);

        byte[] pubKeyData = pmes.getData().toByteArray();

        switch (pmes.getType()) {
            case RSA:
                return Rsa.unmarshalRsaPublicKey(pubKeyData);
            case ECDSA:
                return Ecdsa.unmarshalEcdsaPublicKey(pubKeyData);
            case Secp256k1:
                return Secp256k1.unmarshalSecp256k1PublicKey(pubKeyData);
            case Ed25519:
                return Ed25519.unmarshalEd25519PublicKey(pubKeyData);
            default:
                throw new RuntimeException("BadKeyTypeException");
        }
    }

    public PublicKey getPublicKey() {
        return publicKey;
    }

    /**
     * Returns the generated X.509 certificate file in PEM format.
     */
    public File certificate() {
        return certificate;
    }

    /**
     * Returns the generated RSA private key file in PEM format.
     */
    public File privateKey() {
        return privateKey;
    }

    /**
     * Returns the generated X.509 certificate.
     */
    public X509Certificate cert() {
        return cert;
    }

    /**
     * Returns the generated RSA private key.
     */
    public PrivateKey key() {
        return key;
    }

    /**
     * Deletes the generated X.509 certificate file and RSA private key file.
     */
    public void delete() {
        safeDelete(certificate);
        safeDelete(privateKey);
    }

    public static class SignedKey extends ASN1Object {
        private final ASN1OctetString PubKey;
        private final ASN1OctetString Signature;

        public SignedKey(@NonNull byte[] pubKey, @NonNull byte[] signature) {
            PubKey = new DEROctetString(pubKey);
            Signature = new DEROctetString(signature);
        }

        @Override
        public ASN1Primitive toASN1Primitive() {
            ASN1Encodable[] v = new ASN1Encodable[]{this.PubKey, this.Signature};
            return new DERSequence(v);
        }

    }


    public static final class ThreadLocalInsecureRandom extends SecureRandom {

        private static final long serialVersionUID = -8209473337192526191L;

        private static final SecureRandom INSTANCE = new ThreadLocalInsecureRandom();

        private ThreadLocalInsecureRandom() {
        }

        public static SecureRandom current() {
            return INSTANCE;
        }

        private static Random random() {
            return new SecureRandom();
        }

        @Override
        public String getAlgorithm() {
            return "insecure";
        }

        @Override
        public void setSeed(byte[] seed) {
        }

        @Override
        public void setSeed(long seed) {
        }

        @Override
        public void nextBytes(byte[] bytes) {
            random().nextBytes(bytes);
        }

        @Override
        public byte[] generateSeed(int numBytes) {
            byte[] seed = new byte[numBytes];
            random().nextBytes(seed);
            return seed;
        }

        @Override
        public int nextInt() {
            return random().nextInt();
        }

        @Override
        public int nextInt(int n) {
            return random().nextInt(n);
        }

        @Override
        public boolean nextBoolean() {
            return random().nextBoolean();
        }

        @Override
        public long nextLong() {
            return random().nextLong();
        }

        @Override
        public float nextFloat() {
            return random().nextFloat();
        }

        @Override
        public double nextDouble() {
            return random().nextDouble();
        }

        @Override
        public double nextGaussian() {
            return random().nextGaussian();
        }
    }
}