import yaml
import time
from testcontainers.core.container import Network
from tests.integration_test.environment.mysql.mysql_container_provider import MysqlContainerProvider
from tests.integration_test.environment.mysql_manager.mysql_manager_container_provider import MysqlManagerContainerProvider
from tests.integration_test.environment.proxysql.proxysql_container_provider import ProxysqlContainerProvider


class TestEnvironmentFactory:
    def __init__(
        self,
    ) -> None:
        self.mysqls = []
        self.proxysqls = []
        self.mysql_manager = None
        self.network = Network().create()

    def _get_default_mysql_config_template(self):
        return """[mysqld]
server-id = {}
gtid-mode = ON
enforce-gtid-consistency = ON
log-bin = binlog
relay-log = relaylog
datadir = /var/lib/mysql
binlog_expire_logs_seconds = 59200
binlog_expire_logs_auto_purge = ON
max_binlog_size = 104857600
slow_query_log = 1
long_query_time = 1
slow_query_log_file = /var/lib/mysql/slow.log
max_connections = 1000
"""
    
    def _get_default_proxysql_config_template(self):
        return """datadir="/var/lib/proxysql"
admin_variables=
{{   
    admin_credentials="{}:{};{}:{}"
    mysql_ifaces="0.0.0.0:6032"
    restapi_enabled=true
    restapi_port=6070
}}
mysql_variables=
{{
    threads=4
    max_connections=2048
    default_query_delay=0
    default_query_timeout=36000000
    have_compress=true
    poll_timeout=2000
    interfaces="0.0.0.0:3306"
    default_schema="information_schema"
    stacksize=1048576
    server_version="5.5.30"
    connect_timeout_server=3000
    monitor_history=600000
    monitor_connect_interval=60000
    monitor_ping_interval=10000
    monitor_read_only_interval=1500
    monitor_read_only_timeout=500
    ping_interval_server_msec=120000
    ping_timeout_server=500
    commands_stats=true
    sessions_sort=true
    connect_retries_on_failure=10
}}
"""

    def _get_mysql_manager_config(self):
        res = {
            "clusterSpec": {
                "mysqls": [
                    {
                        "host": mysql.name, 
                        "user": mysql.root_username, 
                        "password": mysql.root_password
                    } for mysql in self.mysqls
                ],
                "proxysqls":[
                    {
                        "host": proxysql.name, 
                        "user": proxysql.remote_username, 
                        "password": proxysql.remote_password
                    } for proxysql in self.proxysqls
                ],
                "users": {
                    "replPassword": "password",
                    "exporterPassword": "exporter",
                    "nonprivPassword": "password",
                    "nonprivUser": "hamadmin",
                    "proxysqlMonPassword": "password",
                },
                "readonlyMysqls": []
            },
        }
        return yaml.dump(res)

    def setup_mysql(self, mysql):
        self.mysqls.append(
            MysqlContainerProvider(
                server_id=mysql["server_id"],
                name=f"mysql-s{mysql['server_id']}",
                network=self.network,
                image=mysql["image"],
                config=self._get_default_mysql_config_template().format(mysql["server_id"])
            )
        )

    def setup_proxysql(self, proxysql):
        self.proxysqls.append(
            ProxysqlContainerProvider(
                name=proxysql["name"],
                network=self.network,
                image=proxysql["image"],
                local_username=proxysql["local_username"],
                local_password=proxysql["local_password"],
                remote_username=proxysql["remote_username"],
                remote_password=proxysql["remote_password"],
                config=self._get_default_proxysql_config_template().format(
                    proxysql["local_username"], 
                    proxysql["local_password"],
                    proxysql["remote_username"], 
                    proxysql["remote_password"],
                )
            )
        )
    
    def setup_mysql_manager(self, mysql_manager):
        self.mysql_manager = MysqlManagerContainerProvider(
            name=mysql_manager["name"],
            network=self.network,
            image=mysql_manager["image"],
            config=self._get_mysql_manager_config()
        )

    def start(self):
        for mysql in self.mysqls:
            mysql.setup()
            mysql.start()
        for proxysql in self.proxysqls:
            proxysql.setup()
            proxysql.start()
        time.sleep(10) 
        self.mysql_manager.setup()
        self.mysql_manager.start()
        time.sleep(10) 


    def stop(self):
        for mysql in self.mysqls:
            mysql.destroy()
        for proxysql in self.proxysqls:
            proxysql.destroy()
        self.mysql_manager.destroy()
        self.network.remove()
