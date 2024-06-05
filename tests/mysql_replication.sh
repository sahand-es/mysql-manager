#!/bin/bash 
docker compose exec mm python /app/scripts/start-replication.py 
echo -e "\n\nCreating db in master..."
docker compose exec mysql-s1 mysql -uroot -proot -e "create database sales; use sales; CREATE TABLE t1 (c1 INT PRIMARY KEY, c2 TEXT NOT NULL);INSERT INTO t1 VALUES (1, 'Luis');" 
sleep 5
echo -e "\n\nChecking replica..."
docker compose exec mysql-s2 mysql -uroot -proot -e "select * from sales.t1;"
