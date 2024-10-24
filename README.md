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

## test with behave
first install behave: 
```sh 
pip install behave testcontainers
behave tests/features
## if you want to build image
BUILD_IMAGE=true behave
```

## design and scenarios
when the cluster manager is created it creates src and repl based on s1 and s2, respectively.
scenarios: 
- mm is up during failover and startup of cluster, one proxysql, one master and one repl
  - on startup with 2 nodes:
    - wait for all to become up
    - check if proxysql is configured: 
      - if not, initialize proxysql setup
    - find src and repl
      - if both have gtid base (only 5 transactions from their own server_uuid) and proxysql is not configured: s1 is master and s2 is repl, config users and stuff in src, add_replica_to_master, add backends to proxysql
      - if repl.is_replica and repl.master is src do nothing
      - if src.is_replica and src.master is repl: switch src and repl
  - on startup with 1 node: 
    - wait for all nodes to become up 
    - check if proxysql is configured: 
      - if not, initialize proxysql setup
    - if src has base gtid set and proxysql is not configured: config users and stuff in src, add src to proxysql
  - reconcile: 
    - if `old_master_joined` is false
      - try to connect to repl:
        - make it a replica of src
        - clone src data
        - enable readonly
        - add it to proxysql
    - ping repl and src 
      - if src is not up and repl is up: 
        - update cluster state
        - increase `master_failure_count` by 1
        - if `master_failure_count` > `MASTER_FAILURE_THRESHOLD` 
          - set the variable `old_master_joined` to false
          - shun src in proxysql
          - stop replication, reset replica and disable read_only in repl (repl will be new master)
          - switch repl and src
          - try to connect to old master:
            - make it a replica of new master
            - clone its data
            - enable readonly
      - if both are down 
        - update cluster state
        - increase `master_failure_count` by 1
        - increase metric `cluster_connection_failure` (we will get alert)
      - if replica is down 
        - update cluster state
      - if replica is up but has replication problem:
        - restart its replication
    - wait for 5 seconds
  - fails: 
    - new master fails when old master is not ready yet
    - mm is restarted before old master is joined to new master
    - master disk is full or read-only
    - replica has problem syncing with master 
    - mm starts when replica has problem connecting to master
    - mm is restarted when adding initial user and stuff in src
    - crashes when src or repl are not available

 
metrics: 
- `total_cluster_connection_failure`
- `total_successful_failover`
- current server roles

failover test scenarios: 
- 2 mysql servers up, 1 proxysql up:
  - master fails. tests:
    - deleted in proxysql 
    - old replica must be master:
      - read_only = 0 
      - super_read_only = 0
      - no replication config
      - added as a writeable host in proxysql
      - deleted old master
    - old master must join the cluster
      - read_only = 1
      - super_readonly = 0 
      - replicating from new master
      - gtid executed set must match that of new master's
  - new master fails
  - after failover mm restarts
  - after initial setup mm restarts 
  - master fails and becomes running before failure threshold


