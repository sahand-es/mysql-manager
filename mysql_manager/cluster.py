from configparser import ConfigParser
import time, datetime, threading

from pymysql.err import OperationalError

from mysql_manager.instance import MysqlInstance
from mysql_manager.base import BaseManager
from mysql_manager.proxysql import ProxySQL
from mysql_manager.enums import (
    MysqlReplicationProblem,
    MysqlStatus,
)
from mysql_manager.exceptions import MysqlConnectionException
from mysql_manager.constants import (
    DEFAULT_CONFIG_PATH,
    DEFAULT_DATABASE,
    RETRY_WAIT_SECONDS,
    CLUSTER_CHECK_INTERVAL_SECONDS,
)

class ClusterManager: 
    def __init__(self, config_file: str=DEFAULT_CONFIG_PATH):
        self.src: MysqlInstance = None
        self.repl: MysqlInstance = None
        self.proxysqls: list[ProxySQL] = [] 
        self.users: dict = {} 
        self.config_file = config_file
        self.state = {
            "master": MysqlStatus.UP.value,
            "replica": MysqlStatus.UP.value,
        }
        self.read_config_file()

    def _log(self, msg) -> None:
        print(str(datetime.datetime.now()) + "  " + msg)
    
    def run(self, stop_event: threading.Event):
        while not stop_event.is_set(): 
            self._log("Checking cluster state...")
            time.sleep(CLUSTER_CHECK_INTERVAL_SECONDS)
            self.reconcile_cluster_state()
        
        self._log("Stopping cluster manager...")

    def discover_node_roles(self):
        self.proxysqls[0].run_command("select * from runtime_mysql_servers")
        self.update_cluster_state()

    def reconcile_cluster_state(self):
        self.check_servers_up()
        self.get_cluster_status()

    def read_config_file(self):
        config = ConfigParser()
        config.read(self.config_file)

        self.src = MysqlInstance(**config["mysql-s1"])
        self.users = config["users"]
        self.proxysqls.append(
            ProxySQL(
                **config["proxysql-1"], 
                mysql_user=self.users["nonpriv_user"],
                mysql_password=self.users["nonpriv_password"],
                monitor_user="proxysql",
                monitor_password=self.users["proxysql_mon_password"]),
            )
        
        if config.has_section("mysql-s2"): 
            self.repl = MysqlInstance(**config["mysql-s2"])

    def update_cluster_state(self) -> dict: 
        if not self.is_server_up(self.src, retry=3):
            self.state["master"] = MysqlStatus.DOWN.value
        else: 
            self.state["master"] = MysqlStatus.UP.value

        if not self.is_server_up(self.repl, retry=3):
            self.state["replica"] = MysqlStatus.DOWN.value
        else: 
            self.state["replica"] = MysqlStatus.UP.value

        # try:
        #     self.repl.ping()
        #     problems = self.repl.find_replication_problems()
        #     if ( 
        #         MysqlReplicationProblem.SQL_THREAD_NOT_RUNNING.value in problems 
        #         or MysqlReplicationProblem.IO_THREAD_NOT_RUNNING.value in problems
        #     ):
        #         cluster_status["replica"] = MysqlStatus.DOWN.value
        # except:
        #     cluster_status["replica"] = MysqlStatus.DOWN.value
        
        # return cluster_status

    def start_mysql_replication(self):
        ## TODO: reset replication all for both of them 
        self.src.add_replica(self.repl)
        self.repl.set_master(self.src)
        self.repl.start_replication("replica", self.users["repl_password"])
    
    def is_server_up(self, server: BaseManager, retry: int=1) -> bool:
        for _ in range(retry):
            try: 
                server.ping()
            except Exception:
                time.sleep(RETRY_WAIT_SECONDS)
                continue
            return True

        return False

    def check_servers_up(self, retry: int=1): 
        is_ok = False
        for _ in range(retry):
            try: 
                self.src.ping()
                if self.repl is not None:
                    self.repl.ping()
                self.proxysqls[0].ping()
            except Exception as e:
                time.sleep(RETRY_WAIT_SECONDS)
                continue
            is_ok = True
            break
        
        if is_ok == False:
            raise MysqlConnectionException()

    def add_replica_to_master(self):
        self.check_servers_up(retry=10)
        if self.repl is not None: 
            status = self.repl.get_replica_status()
            if status is not None:
                return
            
        self.src.install_plugin("clone", "mysql_clone.so")
        self.repl.install_plugin("clone", "mysql_clone.so")

        self.repl.run_command(
            f"set persist clone_valid_donor_list='{self.src.host}:3306'"
        )
        self.repl.run_command("set global super_read_only=0")
        try:
            self.repl.run_command(
                f"CLONE INSTANCE FROM '{self.src.user}'@'{self.src.host}':3306 IDENTIFIED BY '{self.src.password}'"
            )
        except OperationalError as o:
            self._log(str(o))

        self.check_servers_up(retry=10)
        self.start_mysql_replication()
        self.proxysqls[0].add_backend(self.repl, 1, False)

    def start(self):
        self.check_servers_up()
        
        self.src.add_pitr_event(15)
        self.src.create_new_user(
            "replica", self.users["repl_password"], ["REPLICATION SLAVE"]
        )
        self.src.create_database(DEFAULT_DATABASE)
        self.src.create_monitoring_user(self.users["exporter_password"])
        self.src.create_nonpriv_user(self.users["nonpriv_user"], self.users["nonpriv_password"])
        self.src.create_new_user("proxysql", self.users["proxysql_mon_password"], ["USAGE", "REPLICATION CLIENT"])

        

        self.proxysqls[0].initialize_setup()
        self.proxysqls[0].add_backend(self.src, 1, True)
        
        if self.repl is not None: 
            self.start_mysql_replication()
            time.sleep(5)
            self.proxysqls[0].add_backend(self.repl, 1, False)
