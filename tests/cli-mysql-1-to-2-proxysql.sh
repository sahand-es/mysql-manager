#!/bin/bash

source ./setup-etcd.sh

echo "Creating servers..."
docker compose down
docker rm -f mm

docker compose up -d 
setup_user 
docker build ./../ -t mysql-manager:latest
docker run -d \
    -v ./config/mm-config-mysql-1.yaml:/etc/mm/cluster-spec.yaml \
    --network mysql-manager_default --name mm \
    -e ETCD_HOST=etcd -e ETCD_USERNAME=mm -e ETCD_PASSWORD=password -e ETCD_PREFIX=mm/cluster1/ \
    -p 8000:8000 mysql-manager:latest
docker exec mm python cli/mysql-cli.py init -f /etc/mm/cluster-spec.yaml
sleep 30

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
# docker rm -f mm 
# docker run -d \
#     -v ./config/mm-config-mysql-2.yaml:/etc/mm/cluster-spec.yaml \
#     -e ETCD_HOST=etcd -e ETCD_USERNAME=mm -e ETCD_PASSWORD=password -e ETCD_PREFIX=mm/cluster1/ \
#     --network mysql-manager_default --name mm mysql-manager:latest
docker exec mm python cli/mysql-cli.py add -h mysql-s2 -u root -p root -n s2
sleep 30 

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

echo -e "\n\nTest persisted variables..."
docker compose exec mysql-s2 mysql -uroot -proot -e "select @@global.super_read_only"
docker compose exec mysql-s2 mysql -uroot -proot -e "select @@global.read_only"

echo -e "\n\nTesting cluster status..."
docker exec mm python /app/cli/mysql-cli.py mysql get-cluster-status

echo -e "\n\nDestroying servers..."
sleep 5
docker compose down 
docker rm -f mm
