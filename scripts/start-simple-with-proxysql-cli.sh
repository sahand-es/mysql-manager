#!/bin/bash

#export MYSQL_S1_HOST=mysql-s1
#export MYSQL_S2_HOST=mysql-s2

echo -e "\nadd mysql instance: "
python /app/cli/mysql-cli.py mysql add -h $MYSQL_S1_HOST -u root -p root
echo -e "\nDone"

echo -e "\nping mysql: "
python /app/cli/mysql-cli.py mysql ping -h $MYSQL_S1_HOST

echo -e "\nget-info mysql: "
python /app/cli/mysql-cli.py mysql get-info -h $MYSQL_S1_HOST -c "select 1"

echo -e "\ncreate-user: "
python /app/cli/mysql-cli.py mysql create-user --host $MYSQL_S1_HOST --user replica-user --password repl --roles "REPLICATION SLAVE"

echo -e "\ncreate-monitoring-user: "
python /app/cli/mysql-cli.py mysql create-monitoring-user --host $MYSQL_S1_HOST --password exporter

echo -e "\nproxysql operations: "
python /app/cli/mysql-cli.py mysql create-user --host $MYSQL_S1_HOST --user proxysql --password pass --roles "USAGE,REPLICATION CLIENT"

echo -e "\nproxysql add: "
python /app/cli/mysql-cli.py proxysql add -h proxysql -u radmin -p pwd

echo -e "\nproxysql initialize: "
python /app/cli/mysql-cli.py proxysql initialize -h proxysql --mysql-user root --mysql-password root --monitor-user exporter --monitor-password exporter

echo -e "\nproxysql add-backend: "
python /app/cli/mysql-cli.py proxysql add-backend --mysql-host mysql-s1 --proxysql-host proxysql --read-weight 1 --is-writer
