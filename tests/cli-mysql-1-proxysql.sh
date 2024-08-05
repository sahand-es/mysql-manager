#!/bin/bash

echo "Creating servers..."
docker compose down
docker compose up -d 
sleep 30
# docker compose exec mm bash /app/scripts/start-simple-with-proxysql-cli.sh
docker compose exec mm python /app/cli/mysql-cli.py mysql start-cluster

echo -e "\n\nCreating db in master..."
docker compose exec mysql-s1 mysql -uhamadmin -ppassword -h proxysql -e "use hamdb; CREATE TABLE t1 (c1 INT PRIMARY KEY, c2 TEXT NOT NULL);INSERT INTO t1 VALUES (1, 'Luis');"
sleep 5

echo -e "\n\nChecking through proxysql..."
docker compose exec mysql-s1 mysql -uhamadmin -ppassword -h proxysql -e "select * from hamdb.t1;"

echo -e "\n\nChecking master..."
docker compose exec mysql-s1 mysql -uroot -proot -e "select * from hamdb.t1;"

echo -e "\n\nChecking events in master..."
docker compose exec mysql-s1 mysql -uroot -proot -e "USE mysql; SHOW EVENTS;"

echo -e "\n\nChecking default user..."
docker compose exec mysql-s1 mysql -uroot -proot -e "SELECT user FROM mysql.user"
docker compose exec mysql-s1 mysql -uroot -proot -e "show grants for hamadmin"

echo -e "\n\nChecking default database..."
docker compose exec mysql-s1 mysql -uroot -proot -e "show databases"

echo -e "\n\nChecking proxysql config and stats..."
sleep 10
docker compose exec mysql-s1 mysql -uradmin -ppwd -h proxysql -P6032 -e "select * from runtime_mysql_servers;"
docker compose exec mysql-s1 mysql -uradmin -ppwd -h proxysql -P6032 -e "SELECT * FROM monitor.mysql_server_connect_log ORDER BY time_start_us DESC LIMIT 6"
docker compose exec mysql-s1 mysql -uradmin -ppwd -h proxysql -P6032 -e "select Queries, srv_host from stats_mysql_connection_pool\G"
docker compose exec mysql-s1 mysql -uradmin -ppwd -h proxysql -P6032 -e "select * from stats_mysql_query_rules"


echo -e "\n\nChecking metrics from exporter..."
curl localhost:9105/metrics | grep mysql_up

echo -e "\n\nDestroying servers..."
sleep 5
docker compose down 
