#!/bin/bash

docker compose exec mm bash /app/scripts/start-replication-cli.sh
echo -e "\n\nCreating db in master..."
docker compose exec mysql-s1 mysql -uroot -proot -e "create database sales; use sales; CREATE TABLE t1 (c1 INT PRIMARY KEY, c2 TEXT NOT NULL);INSERT INTO t1 VALUES (1, 'Luis');"
sleep 1

echo -e "\n\nChecking replica..."
docker compose exec mysql-s2 mysql -uroot -proot -e "select * from sales.t1;"

echo -e "\n\nChecking metrics from exporter..."
curl localhost:9104/metrics | grep mysql_up
