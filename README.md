## build 
run this to build docker image: 
```sh 
docker build -t mysql-manager:v0.1 . 
```

## tests
to run tests:  
```sh
docker compose down
docker compose up
./tests/mysql_replication.sh
./tests/mysql_replication_with_proxysql.sh
```

