#!/bin/bash

source ./00_vars.sh

# Generate client keystore
keytool -keystore $CLIENT_NAME.keystore.p12 -alias $CLIENT_NAME \
  -validity 365 -genkey -keyalg RSA -storetype pkcs12 \
  -storepass $CLIENT_KEYSTORE_PASSWORD -keypass $KEYSTORE_PASSWORD \
  -dname "CN=$CLIENT_NAME,O=Playground,C=PL"

# Create CSR
keytool -keystore $CLIENT_NAME.keystore.p12 -alias $CLIENT_NAME \
  -certreq -file $CLIENT_NAME-cert-request -storepass $CLIENT_KEYSTORE_PASSWORD

# Sign with CA
openssl x509 -req -CA ca-cert -CAkey ca-key \
  -in $CLIENT_NAME-cert-request -out $CLIENT_NAME-cert-signed \
  -days 365 -CAcreateserial -passin pass:$CA_PASSWORD

# Import CA cert
keytool -keystore $CLIENT_NAME.keystore.p12 -alias CARoot \
 -import -file ca-cert -storepass $CLIENT_KEYSTORE_PASSWORD -noprompt

# Import signed cert
keytool -keystore $CLIENT_NAME.keystore.p12 -alias $CLIENT_NAME \
  -import -file $CLIENT_NAME-cert-signed -storepass $CLIENT_KEYSTORE_PASSWORD -noprompt

echo "Generated keystore for client $CLIENT_NAME"

openssl pkcs12 -in $CLIENT_NAME.keystore.p12 -clcerts -nokeys -out $CLIENT_NAME.crt
echo "Extracted certificate from PKCS12 file for client $CLIENT_NAME"
openssl pkcs12 -in $CLIENT_NAME.keystore.p12 -nocerts -nodes -out $CLIENT_NAME.key
echo "Extracted key from PKCS12 file for client $CLIENT_NAME"