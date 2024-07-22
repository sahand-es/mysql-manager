#!/bin/bash

docker compose exec mm bash /app/scripts/start-replication-with-proxysql-cli.sh
echo -e "\n\nCreating db in master..."
docker compose exec mysql-s1 mysql -uroot -proot -h proxysql -e "create database sales; use sales; CREATE TABLE t1 (c1 INT PRIMARY KEY, c2 TEXT NOT NULL);INSERT INTO t1 VALUES (1, 'Luis');"
sleep 5

echo -e "\n\nChecking through proxysql..."
docker compose exec mysql-s1 mysql -uroot -proot -h proxysql -e "select * from sales.t1;"

echo -e "\n\nChecking master..."
docker compose exec mysql-s1 mysql -uroot -proot -e "select * from sales.t1;"

echo -e "\n\nChecking replica..."
docker compose exec mysql-s2 mysql -uroot -proot -e "select * from sales.t1;"

echo -e "\n\nChecking proxysql config and stats..."
sleep 10
docker compose exec mysql-s1 mysql -uradmin -ppwd -h proxysql -P6032 -e "select * from runtime_mysql_servers;"
docker compose exec mysql-s1 mysql -uradmin -ppwd -h proxysql -P6032 -e "SELECT * FROM monitor.mysql_server_connect_log ORDER BY time_start_us DESC LIMIT 6"
docker compose exec mysql-s1 mysql -uradmin -ppwd -h proxysql -P6032 -e "select Queries, srv_host from stats_mysql_connection_pool\G"
docker compose exec mysql-s1 mysql -uradmin -ppwd -h proxysql -P6032 -e "select * from stats_mysql_query_rules"
docker compose exec mysql-s1 mysql -uroot -proot -e "USE mysql; SHOW EVENTS;"

echo -e "\n\nChecking metrics from exporter..."
curl localhost:9104/metrics | grep mysql_up
