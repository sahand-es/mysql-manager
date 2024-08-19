#!/bin/bash

echo "Creating servers..."
docker compose down
docker compose up -d 
sleep 30

docker compose exec mm python /app/cli/mysql-cli.py mysql start-cluster --nodes 1

echo -e "\n\nCreating db through proxysql..."
docker compose exec mysql-s1 mysql -uhamadmin -ppassword -h proxysql -e "use hamdb; CREATE TABLE t1 (c1 INT PRIMARY KEY, c2 TEXT NOT NULL);INSERT INTO t1 VALUES (1, 'Luis');"
sleep 5

echo -e "\n\nWrite data through proxysql..."
docker compose exec mysql-s1 bash -c "for i in {1..1000}; do mysql -uhamadmin -ppassword  -h proxysql hamdb -e 'insert into t1 values(floor(rand()*100000000), curdate())' 2>/dev/null; done"

echo -e "\n\nChecking through proxysql..."
docker compose exec mysql-s1 mysql -uhamadmin -ppassword -h proxysql -e "select count(*) from hamdb.t1;"

echo -e "\n\nChecking master..."
docker compose exec mysql-s1 mysql -uroot -proot -e "select count(*) from hamdb.t1;"

echo -e "\n\nPurge master binary logs..."
docker compose exec mysql-s1 mysql -uroot -proot -e "purge binary logs before now()"

echo -e "\n\nAdding replica to master..."
docker compose exec mm python /app/cli/mysql-cli.py mysql add-replica

echo -e "\n\nChecking new replica..."
sleep 10
docker compose exec mysql-s2 mysql -uroot -proot -e "select count(*) from hamdb.t1;"
docker compose exec mysql-s2 mysql -uroot -proot -e "show replica status\G"

echo -e "\n\nChecking proxysql config and stats..."
sleep 10
docker compose exec mysql-s1 mysql -uradmin -ppwd -h proxysql -P6032 -e "select * from runtime_mysql_servers;"
docker compose exec mysql-s1 mysql -uradmin -ppwd -h proxysql -P6032 -e "SELECT * FROM monitor.mysql_server_connect_log ORDER BY time_start_us DESC LIMIT 6"
docker compose exec mysql-s1 mysql -uradmin -ppwd -h proxysql -P6032 -e "select Queries, srv_host from stats_mysql_connection_pool\G"
docker compose exec mysql-s1 mysql -uradmin -ppwd -h proxysql -P6032 -e "select * from stats_mysql_query_rules"

echo -e "\n\nTesting cluster status..."
docker compose exec mm python /app/cli/mysql-cli.py mysql get-cluster-status --nodes 2

echo -e "\n\nDestroying servers..."
sleep 5
docker compose down 
