#!/bin/bash

#export MYSQL_S1_HOST=mysql-s1
#export MYSQL_S2_HOST=mysql-s2

echo -e "\nadd mysql instance: "
python /app/cli/mysql-cli.py mysql add -h $MYSQL_S1_HOST -u root -p root
python /app/cli/mysql-cli.py mysql add -h $MYSQL_S2_HOST -u root -p root
echo -e "\nDone"

echo -e "\nping mysql: "
python /app/cli/mysql-cli.py mysql ping -h $MYSQL_S1_HOST

echo -e "\nget-info mysql: "
python /app/cli/mysql-cli.py mysql get-info -h $MYSQL_S1_HOST -c "select 1"

echo -e "\ncreate-user: "
python /app/cli/mysql-cli.py mysql create-user --host $MYSQL_S1_HOST --user replica-user --password repl --roles "REPLICATION SLAVE"

echo -e "\nadd-replica: "
python /app/cli/mysql-cli.py mysql add-replica --master $MYSQL_S1_HOST --replica $MYSQL_S2_HOST

echo -e "\nstart-replication: "
python /app/cli/mysql-cli.py mysql start-replication --master $MYSQL_S1_HOST --replica $MYSQL_S2_HOST --repl-user replica-user --repl-password repl

echo -e "\ncreate-monitoring-user: "
python /app/cli/mysql-cli.py mysql create-monitoring-user --host $MYSQL_S1_HOST --password exporter
