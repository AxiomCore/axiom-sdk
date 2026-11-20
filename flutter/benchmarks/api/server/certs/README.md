Self-signed test certificate for the bench server's HTTP/2 (TLS) listener: CN 127.0.0.1,
SAN IP:127.0.0.1 and DNS:localhost, 10 years. Test only, not a secret: the private key is
committed on purpose so every run uses the same certificate. Clients accept it explicitly
(dio_http2_adapter onBadCertificate, IOClient badCertificateCallback, Chrome
--ignore-certificate-errors). Regenerate:

    openssl req -x509 -newkey rsa:2048 -nodes -keyout key.pem -out cert.pem -days 3650 \
      -subj "/CN=127.0.0.1" -addext "subjectAltName=IP:127.0.0.1,DNS:localhost"
