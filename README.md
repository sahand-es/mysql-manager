## build 
run this to build docker image: 
```sh 
VERSION=v0.1
docker build -t registry.hamdocker.ir/public/mysql-manager:$VERSION . 
docker push registry.hamdocker.ir/public/mysql-manager:$VERSION
```

## generate requirements.txt 
```sh
poetry export --without-hashes --format=requirements.txt > requirements.txt
```

## tests
to run tests:  
```sh
docker compose down
docker compose up
./tests/mysql_replication.sh
./tests/mysql_replication_with_proxysql.sh
```

