#!/bin/bash

echo -e "\U1F6A7 Creating servers..."
docker compose down
docker rm -f mm

docker compose up -d 
docker build ./../ -t mysql-manager:latest
docker run -d --env-file ../.env-test  --network mysql-manager_default \
    --name mm mysql-manager:latest --nodes 2
sleep 30


echo -e "\n\n\U1F4BB Creating db in master..."
docker compose exec mysql-s1 mysql -uhamadmin -ppassword -h proxysql -e "use hamdb; CREATE TABLE t1 (c1 INT PRIMARY KEY, c2 TEXT NOT NULL);INSERT INTO t1 VALUES (1, 'Luis');"
sleep 5

echo -e "\n\n\U1F4BB Checking through proxysql..."
docker compose exec mysql-s1 mysql -uhamadmin -ppassword -h proxysql -e "select * from hamdb.t1;"

echo -e "\n\n\U270c Checking master..."
docker compose exec mysql-s1 mysql -uroot -proot -e "select * from hamdb.t1;"

echo -e "\n\n\U270c Checking replica..."
docker compose exec mysql-s2 mysql -uroot -proot -e "select * from hamdb.t1;"

echo -e "\n\n\U270c Checking events in master..."
docker compose exec mysql-s1 mysql -uroot -proot -e "USE mysql; SHOW EVENTS;"

echo -e "\n\n\U270c Checking default user..."
docker compose exec mysql-s1 mysql -uroot -proot -e "SELECT user FROM mysql.user"
docker compose exec mysql-s1 mysql -uroot -proot -e "show grants for hamadmin"

echo -e "\n\n\U270c Checking default database..."
docker compose exec mysql-s1 mysql -uroot -proot -e "show databases"

echo -e "\n\n\U1F6B6 Checking proxysql config and stats..."
sleep 10
docker compose exec mysql-s1 mysql -uradmin -ppwd -h proxysql -P6032 -e "select * from runtime_mysql_servers;"
docker compose exec mysql-s1 mysql -uradmin -ppwd -h proxysql -P6032 -e "SELECT * FROM monitor.mysql_server_connect_log ORDER BY time_start_us DESC LIMIT 6"
docker compose exec mysql-s1 mysql -uradmin -ppwd -h proxysql -P6032 -e "select Queries, srv_host from stats_mysql_connection_pool\G"
docker compose exec mysql-s1 mysql -uradmin -ppwd -h proxysql -P6032 -e "select * from stats_mysql_query_rules"

echo -e "\n\n\U1F6B6 Checking metrics from exporter..."
curl localhost:9104/metrics | grep mysql_up


echo -e "\n\n\U1F6B6 Test persisted variables..."
docker compose restart mysql-s2
sleep 20
docker compose exec mysql-s2 mysql -uroot -proot -e "select @@global.super_read_only"
docker compose exec mysql-s2 mysql -uroot -proot -e "select @@global.read_only"

echo -e "\n\n\U1F6B6 Testing add replica..."
docker compose exec mm python /app/cli/mysql-cli.py mysql add-replica

echo -e "\n\n\U1F6B6 Testing cluster status..."
echo -e "\n[Case 1]: up, up"
sleep 5
docker exec mm python /app/cli/mysql-cli.py mysql get-cluster-status 

echo -e "\n[Case 2]: up, not_replicating"
docker compose exec mysql-s2 mysql -uroot -proot -e "stop replica io_thread"
sleep 5
docker exec mm python /app/cli/mysql-cli.py mysql get-cluster-status 

echo -e "\n[Case 3]: up, not_replicating"
docker compose exec mysql-s2 mysql -uroot -proot -e "start replica io_thread"
docker compose exec mysql-s2 mysql -uroot -proot -e "stop replica sql_thread"
sleep 5
docker exec mm python /app/cli/mysql-cli.py mysql get-cluster-status

echo -e "\n[Case 4]: up, down"
docker compose down mysql-s2 
sleep 5
docker exec mm python /app/cli/mysql-cli.py mysql get-cluster-status
sleep 5

echo -e "\n\n\U1F6A7 Destroying servers..."
sleep 5
docker compose down 
docker rm -f mm 
