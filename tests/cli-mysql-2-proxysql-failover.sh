#!/bin/bash

source ./setup-etcd.sh

echo "Creating servers..."
docker compose down
docker rm -f mm

docker compose up -d
setup_user
docker build ./../ -t mysql-manager:latest
docker run -d \
    -v ./config/mm-config-mysql-2.yaml:/etc/mm/cluster-spec.yaml \
    --network mysql-manager_default --name mm \
    -e ETCD_HOST=etcd -e ETCD_USERNAME=mm -e ETCD_PASSWORD=password -e ETCD_PREFIX=mm/cluster1/ \
    -p 8000:8000 mysql-manager:latest
docker exec mm python cli/mysql-cli.py init -f /etc/mm/cluster-spec.yaml
sleep 30

echo -e "\n\nCreating db through proxysql..."
docker compose exec mysql-s1 mysql -uhamadmin -ppassword -h proxysql -e "use hamdb; CREATE TABLE t1 (c1 INT PRIMARY KEY, c2 TEXT NOT NULL);INSERT INTO t1 VALUES (1, 'Luis');"
sleep 5

echo -e "\n\nTesting failover..."
docker compose stop mysql-s1 
sleep 20
docker compose exec mysql-s2 mysql -uroot -proot -e "show replica status\G"
sleep 5
docker compose exec mysql-s2 mysql -uroot -proot -e "show master status"
sleep 5

docker compose exec mysql-s2 mysql -uhamadmin -ppassword -h proxysql -e "select * from hamdb.t1;"

echo -e "\n\nChecking events in master..."
docker compose exec mysql-s2 mysql -uroot -proot -e "USE mysql; SHOW EVENTS;"
sleep 5
echo -e "\n\nChecking default user..."
docker compose exec mysql-s2 mysql -uroot -proot -e "SELECT user FROM mysql.user"
docker compose exec mysql-s2 mysql -uroot -proot -e "show grants for hamadmin"
sleep 5

echo -e "\n\nChecking default database..."
docker compose exec mysql-s2 mysql -uroot -proot -e "show databases"
sleep 5 

echo -e "\n\nChecking proxysql config and stats..."
docker compose exec mysql-s2 mysql -uradmin -ppwd -h proxysql -P6032 -e "select * from runtime_mysql_servers;"
docker compose exec mysql-s2 mysql -uradmin -ppwd -h proxysql -P6032 -e "SELECT * FROM monitor.mysql_server_connect_log ORDER BY time_start_us DESC LIMIT 6"
docker compose exec mysql-s2 mysql -uradmin -ppwd -h proxysql -P6032 -e "select Queries, srv_host from stats_mysql_connection_pool\G"
docker compose exec mysql-s2 mysql -uradmin -ppwd -h proxysql -P6032 -e "select * from stats_mysql_query_rules"
sleep 5

echo -e "\n\nChecking metrics from exporter..."
curl localhost:9104/metrics | grep mysql_up
sleep 5 

echo -e "\n\nTesting cluster status..."
echo -e "\n[Case 1]: up, down"
docker exec mm python /app/cli/mysql-cli.py mysql get-cluster-status 
sleep 5 



echo -e "\n\nStarting old master..."
docker compose up -d mysql-s1
sleep 20
docker logs mm --tail 20
sleep 5
docker compose exec mysql-s2 mysql -uhamadmin -ppassword -h proxysql -e "use hamdb; INSERT INTO t1 VALUES (2, 'Jackie');"
sleep 5
docker compose exec mysql-s2 mysql -uroot -proot -e "show replica status\G"
sleep 5
docker compose exec mysql-s2 mysql -uroot -proot -e "show master status"
sleep 5
docker compose exec mysql-s1 mysql -uroot -proot -e "show replica status\G"
sleep 5
docker compose exec mysql-s1 mysql -uroot -proot -e "show master status"
sleep 5
docker compose exec mysql-s2 mysql -uradmin -ppwd -h proxysql -P6032 -e "select * from runtime_mysql_servers;"
sleep 5
curl localhost:9104/metrics | grep mysql_up
curl localhost:9105/metrics | grep mysql_up
sleep 5

echo -e "\n\nTesting mysql manager restart..."
docker rm -f mm
docker run -d \
    -v ./config/mm-config-mysql-2.yaml:/etc/mm/cluster-spec.yaml \
    --network mysql-manager_default --name mm \
    -e ETCD_HOST=etcd -e ETCD_USERNAME=mm -e ETCD_PASSWORD=password -e ETCD_PREFIX=mm/cluster1/ \
    -p 8000:8000 mysql-manager:latest
sleep 20
docker compose exec mysql-s2 mysql -uroot -proot -e "show replica status\G"
sleep 5
docker compose exec mysql-s2 mysql -uroot -proot -e "show master status"
sleep 5
docker compose exec mysql-s1 mysql -uroot -proot -e "show replica status\G"
sleep 5
docker compose exec mysql-s1 mysql -uroot -proot -e "show master status"
sleep 5
docker compose exec mysql-s2 mysql -uradmin -ppwd -h proxysql -P6032 -e "select * from runtime_mysql_servers;"
sleep 5

echo -e "\n\nTesting cluster status..."
echo -e "\n[Case 1]: up, up"
docker exec mm python /app/cli/mysql-cli.py mysql get-cluster-status 
sleep 5 

echo -e "\n\nDestroying servers..."
docker compose down 
docker rm -f mm 
