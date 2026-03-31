#!/bin/bash

source ./00_vars.sh

openssl req -new -x509 -keyout ca-key -out ca-cert -days 1095 \
  -subj "/CN=KafkaCA/O=Playground/C=PL" \
  -passout pass:$CA_PASSWORD

# Create truststore with CA certificate
keytool -keystore kafka.truststore.p12 -alias CARoot \
  -import -file ca-cert -storepass $TRUSTSTORE_PASSWORD -noprompt -storetype PKCS12

openssl pkcs12 -in kafka.truststore.p12 -nokeys -out kafka.truststore.crt