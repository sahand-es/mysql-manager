# MySQL Manager

MySQL Manager is an open source project for managing highly available MySQL replication setups. 
It supports MySQL asynchronous replication and ProxySQL for proxy. Go to [documentation](./docs/) 
for more details. 

## Features
- MySQL asynchronous replication 
- Automatic failover in case of source (primary) failure
- [Proxy](https://github.com/hamravesh/mysql-manager-haproxy) based on [HAProxy](https://www.haproxy.org/) with both write and readonly ports
- High availability using [etcd](https://etcd.io/)
- Supports migration from other MySQL servers using [CLONE](https://dev.mysql.com/doc/refman/8.0/en/clone-plugin.html) plugin
- Prometheus metrics for observability

## Getting started
To get started with MySQL Manager read [getting started doc](./docs/getting-started.md). If you want to migrate from other MySQL servers please read [migration doc](./docs/migration.md)

## Contributing and development 
Please follow [contributing doc](./docs/contributing.md) to set up your local development 
environment and contribute to this project.

## License
MySQL Manager is under MIT license. See [LICENSE](LICENSE) for more details. 

