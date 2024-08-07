#!/bin/bash

#export MYSQL_S1_HOST=mysql-s1
#export MYSQL_S2_HOST=mysql-s2

echo -e "\nadd mysql instance: "
python /app/cli/mysql-cli.py mysql add -n mysql-s1-instance -h $MYSQL_S1_HOST -u root -p root
echo -e "\nDone"

echo -e "\nping mysql: "
python /app/cli/mysql-cli.py mysql ping -n mysql-s1-instance

echo -e "\nget-info mysql: "
python /app/cli/mysql-cli.py mysql get-info -n mysql-s1-instance -c "select 1"

echo -e "\ncreate-user: "
python /app/cli/mysql-cli.py mysql create-user -n mysql-s1-instance --user replica-user --password repl --roles "REPLICATION SLAVE"

echo -e "\ncreate-monitoring-user: "
python /app/cli/mysql-cli.py mysql create-monitoring-user -n mysql-s1-instance --password exporter

echo -e "\nproxysql operations: "
python /app/cli/mysql-cli.py mysql create-user -n mysql-s1-instance --user proxysql --password pass --roles "USAGE,REPLICATION CLIENT"

echo -e "\nproxysql add: "
python /app/cli/mysql-cli.py proxysql add -n proxysql-instance -h proxysql -u radmin -p pwd

echo -e "\nproxysql initialize: "
python /app/cli/mysql-cli.py proxysql initialize -n proxysql-instance --mysql-user root --mysql-password root --monitor-user exporter --monitor-password exporter

echo -e "\nproxysql add-backend: "
python /app/cli/mysql-cli.py proxysql add-backend --mysql-name mysql-s1-instance --proxysql-name proxysql-instance --read-weight 1 --is-writer
