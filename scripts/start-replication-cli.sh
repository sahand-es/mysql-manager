#!/bin/bash

#export MYSQL_S1_HOST=mysql-s1
#export MYSQL_S2_HOST=mysql-s2

echo -e "\nadd mysql instance: "
python /app/cli/mysql-cli.py mysql add -n mysql-s1-instance -h $MYSQL_S1_HOST -u root -p root
python /app/cli/mysql-cli.py mysql add -n mysql-s2-instance -h $MYSQL_S2_HOST -u root -p root
echo -e "\nDone"

echo -e "\nping mysql: "
python /app/cli/mysql-cli.py mysql ping -n mysql-s1-instance

echo -e "\nget-info mysql: "
python /app/cli/mysql-cli.py mysql get-info -n mysql-s1-instance -c "select 1"

echo -e "\ncreate-user: "
python /app/cli/mysql-cli.py mysql create-user -n mysql-s1-instance --user replica-user --password repl --roles "REPLICATION SLAVE"

echo -e "\nadd-replica: "
python /app/cli/mysql-cli.py mysql add-replica --master mysql-s1-instance --replica mysql-s2-instance

echo -e "\nstart-replication: "
python /app/cli/mysql-cli.py mysql start-replication --master mysql-s1-instance --replica mysql-s2-instance --repl-user replica-user --repl-password repl

echo -e "\ncreate-monitoring-user: "
python /app/cli/mysql-cli.py mysql create-monitoring-user -n mysql-s1-instance --password exporter
