## Requirements
You can migrate from other MySQL servers (we call them remote servers) to MySQL Manager clusters. 
MySQL Manager uses clone plugin to migrate data from remote server. 
It checks for compatibility in the remote server. Version check is not 
implemented because some distributions add strings to the version and make it 
hard to compare versions. Please refer to 
[this doc](https://dev.mysql.com/doc/refman/8.0/en/clone-plugin-remote.html) for 
version requirements when using clone plugin.
Other requirements are checked by MySQL Manager itself. 

## Deployment
You should follow instructions in [Getting Started](./getting-started.md) doc to 
setup a cluster. Replace `mm-config-mysql-2.yaml` in [docker-compose.yaml](../docker-compose.yaml) with `mm-config-mysql-2-migrate.yaml` and when starting cluster 
in `mm` container add `--standby` flag:
```sh
docker compose exec mm python cli/mysql-cli.py init -f /etc/mm/cluster-spec.yaml --standby
```
