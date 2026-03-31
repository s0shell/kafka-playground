# Description
This is a web application which uses Kafka with Avro for educational purposes. The goal is to show how an application can be affected by corrupted data flow. The app is consuming messages from topic `orders` and printing them on page available at `http://127.0.0.1:5000`. Malicious messages published to Kafka topic trigger XSS, which is caused by disabling autoescape mechanism of Jinja2 template engine (default: enabled).

Currently the tool used for interracting with Kafka is the one available here: https://github.com/stn1slv/kafka-console-avro-tools.
I am working on my own GUI tool, once it will be finished, I will update this repo.


Communication with Kafka on port `9093` requires mTLS. Follow the instructions to create certificates locally.
You can interract with the app via plaintext protocol on port `9092` but certificates are mandatory anyway. If you are enough tech savvy, you can change the configuration but then I believe you are way past this project ;)


## Prerequisites
 - Docker
 - Python3
 - curl
 - go

# Usage

## Generate certificates
In `/kafka/certs` directory set variables in `00_vars.sh`, then run scripts in the following order: `01_ca.sh` -> `02_server.sh` -> `03_client.sh`.

Next, in the same directory create files `keystore-password` and `truststore-password`, and put only the password in that files. No spaces or new lines at the end.

```
echo -n "" > keystore-password
echo -n "" > truststore-password
```

####  Start docker containers
```
cd kafka-playground/docker
docker-compose up -d
```

#### Create topic
```
docker exec -it kafka kafka-topics --bootstrap-server localhost:9092 \  --create --topic orders --partitions 1 --replication-factor 1
```

#### Register Avro schema
```
curl -X POST http://localhost:8081/subjects/orders-value/versions \
  -H "Content-Type: application/vnd.schemaregistry.v1+json" \
  --data '{
    "schema": "{\"type\":\"record\",\"name\":\"Order\",\"namespace\":\"com.demo\",\"fields\":[{\"name\":\"orderId\",\"type\":\"string\"},{\"name\":\"product\",\"type\":\"string\"},{\"name\":\"quantity\",\"type\":\"int\"},{\"name\":\"customerComment\",\"type\":\"string\"}]}"
  }'
```

#### Get Kafka console avro tools
```
git clone https://github.com/stn1slv/kafka-console-avro-tools
cd kafka-console-avro-tools
go build -o kafka-avro
sudo cp kafka-avro /usr/local/bin
```

#### Start App
```
cd app
pip install -r requirements.txt
python3 app.py
```

The application listens on port `5000` and pools messages from `orders` topic. Increment consumer group id in `app.py` to start consuming from offset 0.

#### Produce message
```
kafka-avro producer --auth tls --caCertFile kafka.truststore.crt --certFile playground.crt --keyFile playground.key --schemaId 1 --schemaRegistryURL http://localhost:8081 -b localhost:9093 -t orders -f ../orders.json 
kafka-avro producer --auth tls --caCertFile kafka.truststore.crt --certFile playground.crt --keyFile playground.key --schemaId 1 --schemaRegistryURL http://localhost:8081 -b localhost:9093 -t orders -f ../orders_bad.json 
```
Check the app!

#### Clear topic
Quick, but dirty way of clearing up topic is to delete it and create from scratch. Schema does not have to be re-registered.
Use provided script `clear_topic.sh` in `docker` directory.

## TIP: Certificates
You can extract both certificate and private key from PKCS12 file using the commands below:
```
openssl pkcs12 -in certs.p12 -clcerts -nokeys -out certificate.crt
openssl pkcs12 -in certs.p12 -nocerts -out -nodes private.key
```
Bear in mind, that some applications prefer to load the key without prompting for password. Always make sure that the key material is well protected! 

# Final Words
This application is for educational purposes ONLY! If you have any ideas for further development of it and want to add something, feel free. 



