#!/bin/bash
docker exec -it kafka kafka-topics --bootstrap-server localhost:9092 --delete --topic orders
docker exec -it kafka kafka-topics --bootstrap-server localhost:9092 --create --topic orders --partitions 1 --replication-factor 1
