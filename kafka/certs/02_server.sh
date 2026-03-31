#!/bin/bash
source ./00_vars.sh

# Generate keystore with key pair
keytool -keystore kafka.server.keystore.p12 -alias localhost \
  -validity $VALIDITY -genkey -keyalg RSA -storetype pkcs12 \
  -storepass $SERVER_KEYSTORE_PASSWORD -keypass $SERVER_KEYSTORE_PASSWORD \
  -dname "CN=$BROKER_HOST,O=Playground/C=PL" \
  -ext SAN=DNS:$BROKER_HOST,DNS:localhost

# Create CSR
keytool -keystore kafka.server.keystore.p12 -alias localhost \
  -certreq -file cert-request -storepass $SERVER_KEYSTORE_PASSWORD 

# Sign with CA
openssl x509 -req -CA ca-cert -CAkey ca-key \
  -in cert-request -out cert-signed \
  -days $VALIDITY -CAcreateserial -passin pass:$CA_PASSWORD \
  -extfile <(printf "subjectAltName=DNS:$BROKER_HOST,DNS:localhost")

# Import CA cert to keystore
keytool -keystore kafka.server.keystore.p12 -alias CARoot \
  -import -file ca-cert -storepass $SERVER_KEYSTORE_PASSWORD -noprompt 

# Import signed cert to keystore
keytool -keystore kafka.server.keystore.p12 -alias localhost \
  -import -file cert-signed -storepass $SERVER_KEYSTORE_PASSWORD -noprompt 

echo "Generated keystore for $BROKER_HOST"