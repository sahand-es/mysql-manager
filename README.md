# MySQL Manager

MySQL Manager is an open source project for managing highly available MySQL replication setups. 
It supports MySQL asynchronous replication and ProxySQL for proxy. Go to [documentation](./docs/) 
for more details. 

## Features
- MySQL asynchronous replication 
- Automatic failover in case of source (primary) failure
- ProxySQL as a proxy
- High availability using [etcd](https://etcd.io/)
- Supports migration from other MySQL servers using [CLONE](https://dev.mysql.com/doc/refman/8.0/en/clone-plugin.html) plugin
- Prometheus metrics for observability

## Getting started
To get started with MySQL Manager read [getting started doc](./docs/getting-started.md). 

## Contributing and development 
Please follow [contributing doc](./docs/contributing.md) to set up your local development 
environment and contribute to this project.

## License
MySQL Manager is under MIT license. See [LICENSE](LICENSE) for more details. 

