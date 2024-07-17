#!/bin/bash 

MANIFEST_FILE=mysql-1-proxysql-components.yaml
MYSQL_S1_POD_NAME=release-all-mysql-s1-0
PROXYSQL_POD_NAME=release-all-proxysql-0
MYSQL_MANAGER_DEPLOYMENT_NAME=release-all-mysql-manager

check_namespace () {
    current_namespace=`kubectl config view --minify -o jsonpath='{..namespace}'`
    if [ $current_namespace != "dbaas-staging" ]
    then 
        echo "Error: This is not dbaas-staging namespace. Change your namespace."
        exit 1 
    fi 
}

echo -e "Deleting objects..."
kubectl delete -f $MANIFEST_FILE 2>/dev/null
kubectl wait --for=delete -f $MANIFEST_FILE 
kubectl wait --for=delete pod/$MYSQL_S1_POD_NAME
kubectl wait --for=delete pod/$PROXYSQL_POD_NAME


echo -e "\n\nChecking cluster namespace..."
check_namespace


echo -e "\n\nDeploying manifests..."
kubectl apply -f $MANIFEST_FILE
kubectl wait --for=condition=Ready pod/$MYSQL_S1_POD_NAME
kubectl wait --for=condition=Ready pod/$PROXYSQL_POD_NAME

echo -e "\n\nWaiting for mysql to become ready..."
sleep 80
## TODO: check mysql readiness using mysql manager

echo -e "\n\nStarting cluster using mysql manager..."
kubectl exec -it deploy/$MYSQL_MANAGER_DEPLOYMENT_NAME -- bash -c 'python /app/cli/mysql-cli.py mysql add --host $MYSQL_S1_HOST --user root --password $MYSQL_ROOT_PASSWORD'
kubectl exec -it deploy/$MYSQL_MANAGER_DEPLOYMENT_NAME -- bash -c 'python /app/cli/mysql-cli.py mysql create-user --host $MYSQL_S1_HOST --user replica --password $MYSQL_REPL_PASSWORD --roles "REPLICATION SLAVE"'

echo -e "\nCreate monitoring user: "
kubectl exec -it deploy/$MYSQL_MANAGER_DEPLOYMENT_NAME -- bash -c 'python /app/cli/mysql-cli.py mysql create-monitoring-user --host $MYSQL_S1_HOST --password $MYSQL_EXPORTER_PASSWORD'

echo -e "\nProxysql operations: "
kubectl exec -it deploy/$MYSQL_MANAGER_DEPLOYMENT_NAME -- bash -c 'python /app/cli/mysql-cli.py mysql create-user --host $MYSQL_S1_HOST --user proxysql --password $PROXYSQL_MON_PASSWORD --roles "USAGE,REPLICATION CLIENT"'

echo -e "\nProxysql add: "
kubectl exec -it deploy/$MYSQL_MANAGER_DEPLOYMENT_NAME -- bash -c 'python /app/cli/mysql-cli.py proxysql add --host $PROXYSQL_HOST --user radmin --password $PROXYSQL_PASSWORD' 

echo -e "\nProxysql initialize: "
kubectl exec -it deploy/$MYSQL_MANAGER_DEPLOYMENT_NAME -- bash -c 'python /app/cli/mysql-cli.py proxysql initialize --host $PROXYSQL_HOST --mysql-user root --mysql-password $MYSQL_ROOT_PASSWORD --monitor-user exporter --monitor-password $MYSQL_EXPORTER_PASSWORD'

echo -e "\nProxysql add-backend: "
kubectl exec -it deploy/$MYSQL_MANAGER_DEPLOYMENT_NAME -- bash -c 'python /app/cli/mysql-cli.py proxysql add-backend --mysql-host $MYSQL_S1_HOST --proxysql-host $PROXYSQL_HOST --read-weight 1 --is-writer'



echo -e "\n\nWrite to mysql through proxysql..."
kubectl exec $MYSQL_S1_POD_NAME -- mysql -uroot -ppassword -h release-all-proxysql-svc -e "create database sales; use sales; CREATE TABLE t1 (c1 INT PRIMARY KEY, c2 TEXT NOT NULL);INSERT INTO t1 VALUES (1, 'Luis');"


echo -e "\n\nCheck data in master..."
kubectl exec -it $MYSQL_S1_POD_NAME -- mysql -uroot -ppassword  -e "select * from sales.t1"

echo -e "\n\nChecking proxysql config and stats..."
sleep 20
kubectl exec -it $MYSQL_S1_POD_NAME -- mysql -uradmin -ppx-admin -h release-all-proxysql-svc -P6032 -e "select * from runtime_mysql_servers"
kubectl exec -it $MYSQL_S1_POD_NAME -- mysql -uradmin -ppx-admin -h release-all-proxysql-svc -P6032 -e "SELECT * FROM monitor.mysql_server_connect_log ORDER BY time_start_us DESC LIMIT 6"


echo -e "\n\nChecking metrics..."
sleep 10
kubectl exec -it deploy/$MYSQL_MANAGER_DEPLOYMENT_NAME -- bash -c "curl release-all-mysql-exporter-s1-svc:9104/metrics | grep mysql_up"

echo -e "\n\nDeleting objects..."
kubectl delete -f $MANIFEST_FILE 2>/dev/null
kubectl wait --for=delete  -f $MANIFEST_FILE
