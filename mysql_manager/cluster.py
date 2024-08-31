from configparser import ConfigParser
import time, datetime, threading
from pymysql.err import OperationalError

from mysql_manager.instance import MysqlInstance
from mysql_manager.dto import ClusterStateDTO
from mysql_manager.base import BaseServer
from mysql_manager.proxysql import ProxySQL
from mysql_manager.enums import (
    MysqlReplicationProblem,
    MysqlStatus,
)
from mysql_manager.exceptions import MysqlConnectionException
from mysql_manager.constants import *

class ClusterManager: 
    def __init__(self, config_file: str=DEFAULT_CONFIG_PATH):
        self.src: MysqlInstance = None
        self.repl: MysqlInstance = None
        self.proxysqls: list[ProxySQL] = [] 
        self.users: dict = {} 
        self.config_file = config_file
        self.state = ClusterStateDTO(
            master=MysqlStatus.UP.value,
            replica=MysqlStatus.DOWN.value,
            old_master_joined=True,
            master_failure_count=0,
        )
        self.read_config_file()

    def _log(self, msg) -> None:
        print(str(datetime.datetime.now()) + "  " + msg)

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

    def run(self, stop_event: threading.Event):
        self.start()
        while not stop_event.is_set(): 
            self._log("Checking cluster state...")
            time.sleep(CLUSTER_CHECK_INTERVAL_SECONDS)
            self.reconcile_cluster()

        self._log("Stopping cluster manager...")

    def reconcile_cluster(self):
        self._log("Running reconciliation for cluster")
        if self.state.old_master_joined == False: 
            self.add_replica_to_master(retry=1)
            # TODO: if successful increase total_successful_failover metric
        
        self.update_cluster_state()
        if (
            self.state.master_failure_count > MASTER_FAILURE_THRESHOLD 
            and self.state.replica == MysqlStatus.UP.value
        ):
            self._log("Running failover for cluster")
            self.state.old_master_joined = False
            self.proxysqls[0].shun_backend(self.src)
            self.repl.reset_replication()
            self.switch_src_and_repl()
            
        if (
            self.state.master == MysqlStatus.DOWN.value
            and self.state.replica == MysqlStatus.DOWN.value
        ):
            # TODO: increase total_cluster_connection_failure metric
            pass 
        
        if self.state.replica == MysqlStatus.NOT_REPLICATING.value:
            self.repl.restart_replication()
    
    def switch_src_and_repl(self): 
        self._log(f"Switching src[{self.src.host}] and repl[{self.repl.host}]")
        self.src = MysqlInstance(self.repl.host, self.repl.user, self.repl.password)
        self.repl = MysqlInstance(self.src.host, self.src.user, self.src.password)

    def update_cluster_state(self) -> dict: 
        if not self.is_server_up(self.src, retry=1):
            self.state.master = MysqlStatus.DOWN.value
            self.state.master_failure_count += 1
        else: 
            self.state.master = MysqlStatus.UP.value
            self.state.master_failure_count = 0

        if self.is_server_up(self.repl, retry=1):
            self.state.replica = MysqlStatus.UP.value 
            problems = self.repl.find_replication_problems()
            if ( 
                MysqlReplicationProblem.SQL_THREAD_NOT_RUNNING.value in problems 
                or MysqlReplicationProblem.IO_THREAD_NOT_RUNNING.value in problems
                or MysqlReplicationProblem.NOT_REPLICA.value in problems
            ):
                self.state.replica = MysqlStatus.NOT_REPLICATING.value
        else: 
            self.state.replica = MysqlStatus.DOWN.value
        
        self._write_cluster_state()

    def _write_cluster_state(self):
        config = ConfigParser()
        config.add_section("state")
        config.set("state", "master", self.state.master)
        config.set("state", "replica", self.state.replica)
        
        with open(CLUSTER_STATE_FILE_PATH, "w") as sf:
            config.write(sf)

    def start_mysql_replication(self):
        ## TODO: reset replication all for both of them 
        self._log(f"Starting replication in repl[{self.repl.host}]")
        self.src.add_replica(self.repl)
        self.repl.set_master(self.src)
        self.repl.start_replication("replica", self.users["repl_password"])
    
    def is_server_up(self, server: BaseServer, retry: int=1) -> bool:
        for i in range(retry):
            try: 
                server.ping()
            except Exception:
                # do not sleep in last retry
                if i+1 != retry: 
                    time.sleep(RETRY_WAIT_SECONDS)
                continue
            return True

        return False

    def check_servers_up(self, retry: int=1): 
        # is_ok = False
        for _ in range(retry):
            try: 
                self.src.ping()
                if self.repl is not None:
                    self.repl.ping()
                self.proxysqls[0].ping()
            except Exception as e:
                time.sleep(RETRY_WAIT_SECONDS)
                continue
            # is_ok = True
            break
        
        # if is_ok == False:
        #     raise MysqlConnectionException()

    def config_src_initial_setup(self):
        self._log(f"Initial config of src[{self.src.host}]")
        self.src.add_pitr_event(minute_intervals=15)
        self.src.create_new_user(
            "replica", self.users["repl_password"], ["REPLICATION SLAVE"]
        )
        self.src.create_database(DEFAULT_DATABASE)
        self.src.create_monitoring_user(self.users["exporter_password"])
        self.src.create_nonpriv_user(self.users["nonpriv_user"], self.users["nonpriv_password"])
        self.src.create_new_user("proxysql", self.users["proxysql_mon_password"], ["USAGE", "REPLICATION CLIENT"])
        
        self.proxysqls[0].add_backend(self.src, 1, True)

    def add_replica_to_master(self, retry: int=1):
        self._log("Adding replica to master")
        self.check_servers_up(retry=retry)
        if self.repl is not None and self.repl.is_replica():
            return
            
        self.src.install_plugin("clone", "mysql_clone.so")
        self.repl.install_plugin("clone", "mysql_clone.so")

        self.repl.run_command(
            f"set persist clone_valid_donor_list='{self.src.host}:3306'"
        )
        self.repl.run_command("set persist read_only=0")
        try:
            self.repl.run_command(
                f"CLONE INSTANCE FROM '{self.src.user}'@'{self.src.host}':3306 IDENTIFIED BY '{self.src.password}'"
            )
        except OperationalError as o:
            self._log(str(o))

        self.check_servers_up(retry=retry)
        self.start_mysql_replication()
        self.proxysqls[0].add_backend(self.repl, 1, False)

    def start(self):
        # TODO: make proxysql and src initial setup idempotent
        self._log("Starting cluster setup...")
        self.check_servers_up(retry=10)
        if (
            self.repl is not None 
            and self.src.is_replica() 
            and self.repl.is_master_of(self.src)
        ):
            self.switch_src_and_repl()

        self._log("Initializing config of servers...")
        if not self.proxysqls[0].is_configured():
            self.proxysqls[0].initialize_setup()
        if self.src.has_base_gtid_set(): 
            self.config_src_initial_setup()
        if (
            self.repl is not None 
            and self.repl.has_base_gtid_set() 
            and not self.repl.is_replica()
        ):
            self.add_replica_to_master(retry=10)

