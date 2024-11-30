## deploy with docker
You can use [docker-compose.yaml](./../docker-compose.yaml) to deploy all needed 
services. Make sure to uncomment volumes if you need persistence.
```sh 
docker compose up etcd -d 
```
It deploys etcd to store state of the cluster. 
After running the etcd, we need to do some inital setup in it.
First create root user and another user with limited privileges for MySQL Manager. 
```sh
docker compose exec etcd etcdctl user add root --new-user-password="password"
docker compose exec etcd etcdctl user grant-role root root
docker compose exec etcd etcdctl user add mm --new-user-password="password"
docker compose exec etcd etcdctl role add mm 
docker compose exec etcd etcdctl role grant-permission mm --prefix=true readwrite mm/cluster1/
docker compose exec etcd etcdctl user grant-role mm mm
docker compose exec etcd etcdctl auth enable
```      
We created `mm` user with password `password`. In a production environment you need to set a 
much stronger password. User `mm` is granted access to `mm/cluster1/` prefix in etcd. Note that 
the environment variables in `mm` container must match the values given above. 

Then run all other containers:
```sh
docker compose up -d --build
```
It deploys two MySQL servers, their exporters and a ProxySQL. MySQL Manager is set up by building 
an image from Dockerfile at the root of the project. Now start cluster with this command:
```sh
docker compose exec mm python cli/mysql-cli.py init -f /etc/mm/cluster-spec.yaml
```
Running `python cli/mysql-cli.py init -f /etc/mm/cluster-spec.yaml` in `mm` makes MySQL Manager 
to start cluster setup, watch for their state and failover if needed. After a minute check `mm`
logs:
```sh
docker compose logs mm -f 
```
You should see these lines in its logs:
```log
Source is mysql-s1
Replica is mysql-s2
```
You can check server states by running this:
```sh
docker compose exec mm python cli/mysql-cli.py mysql get-cluster-status
```
The output is like this:
```log
source=up
replica=up
```