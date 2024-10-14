import time, datetime, yaml
from pymysql.err import OperationalError
from dataclasses import asdict
from prometheus_client import start_http_server

from mysql_manager.instance import MysqlInstance
from mysql_manager.etcd import EtcdClient
from mysql_manager.dto import ClusterData
from mysql_manager.base import BaseServer
from mysql_manager.proxysql import ProxySQL
from mysql_manager.enums import (
    MysqlReplicationProblem,
    MysqlStatus,
    MysqlClusterState,
    MysqlRoles,
)
from mysql_manager.cluster_data_handler import ClusterDataHandler
from mysql_manager.exceptions import (
    MysqlConnectionException,
    MysqlClusterConfigError,
)
from mysql_manager.constants import *
from mysql_manager.metrics import (
    FAILOVER_ATTEMPTS, 
    SUCCESSFUL_FAILOVERS,
    REPLICATION_RESTARTS,
    CLUSTER_FAILURES,
    MASTER_UP_STATUS,
    REPLICA_UP_STATUS,
)

class ClusterManager: 
    def __init__(self, config_file: str=DEFAULT_CONFIG_PATH):
        self.src: MysqlInstance = None
        self.repl: MysqlInstance = None
        self.proxysqls: list[ProxySQL] = [] 
        self.users: dict = {} 
        self.config_file = config_file
        self.cluster_data_handler = ClusterDataHandler()
        self.etcd_client = EtcdClient()

        # Start Prometheus metrics server on port 8000
        start_http_server(8000)

    def _log(self, msg) -> None:
        print(str(datetime.datetime.now()) + "  " + msg)

    def _validate_cluster_spec(self, spec: dict): 
        if len(spec["mysqls"]) == 0 or len(spec["proxysqls"]) == 0: 
            raise MysqlClusterConfigError()
        
    def _load_cluster_data(self):
        # spec = self.etcd_client.read_spec()
        # self._validate_cluster_spec(spec)
        
        self.users = self.cluster_data_handler.get_users()
        for name, mysql in self.cluster_data_handler.get_mysqls().items():
            if mysql.role == MysqlRoles.SOURCE.value:
                if self.src is None or self.src.name != name: 
                    self.src = MysqlInstance(name=name, **asdict(mysql))
            elif mysql.role ==  MysqlRoles.REPLICA.value:
                self.repl = MysqlInstance(name=name, **asdict(mysql))

        self.proxysqls.append(
            ProxySQL(
                **self.cluster_data_handler.get_proxysql(), 
                mysql_user=self.users["nonprivUser"],
                mysql_password=self.users["nonprivPassword"],
                monitor_user="proxysql",
                monitor_password=self.users["proxysqlMonPassword"]
            ),
        )
        
    # def is_cluster_data_available(self) -> bool:
    #     clusterData = self.etcd_client.read_spec()
    #     if clusterData is None:
    #         return False
    
    #     return True
    
    def run(self):
        while not self.cluster_data_handler.is_cluster_data_available(): 
            time.sleep(CLUSTER_CHECK_INTERVAL_SECONDS)
            self._log("Cluster data not available. Waiting for it...")

        self._load_cluster_data()
        self.start()
        while True: 
            self._log("Checking cluster state...")
            time.sleep(CLUSTER_CHECK_INTERVAL_SECONDS)
            self._load_cluster_data()
            self.reconcile_cluster()

    def must_replica_join_source(self, repl: MysqlInstance) -> bool:
        # in the first two checks, if replica is not available we return True to 
        # prevent useless start replication attempts
        if self.repl is None:
            return True
        if not self.is_server_up(self.repl):
            return True
        ## TODO: actually check if replica is replicating from source
        if self.repl.is_replica():
            return True

        return False
    
    def reconcile_cluster(self):
        self._log("Running reconciliation for cluster")

        self.update_cluster_state()
        # self._log(str(self.cluster_status))
        self._set_status_metrics()

        if self.repl is not None:  
            if not self.must_replica_join_source(self.repl): 
                self.add_replica_to_source(retry=1)
            if (
                self.repl.status == MysqlStatus.REPLICATION_THREADS_STOPPED.value
                and self.src.status == MysqlStatus.UP.value
            ):
                self.repl.restart_replication()
                REPLICATION_RESTARTS.inc()
            elif (
                self.src.status == MysqlStatus.DOWN.value
                and self.repl.status == MysqlStatus.DOWN.value
            ):
                CLUSTER_FAILURES.inc()
                self._log("Cluster failure detected: Master and replicas are down.")
            elif (
                # TODO: add more checks for replica: if it was not running sql thread for
                # a long time, if it is behind master for a long time
                self.src.health_check_failures > MASTER_FAILURE_THRESHOLD 
                and self.repl.status != MysqlStatus.DOWN.value
            ):
                self._log("Running failover for cluster")
                FAILOVER_ATTEMPTS.inc()
                ## TODO: what if we restart when running this 
                ## TODO: use etcd txn
                self.cluster_data_handler.set_mysql_role(self.src, MysqlRoles.REPLICA.value)
                self.cluster_data_handler.set_mysql_role(self.repl, MysqlRoles.SOURCE.value)
                self.proxysqls[0].remove_backend(self.src)
                self.repl.reset_replication()
                self.switch_src_and_repl()

        self._log(f"Source is {self.src.host}")
        if self.repl is not None: 
            self._log(f"Replica is {self.repl.host}")

    def _set_status_metrics(self):
        MASTER_UP_STATUS.clear()
        MASTER_UP_STATUS.labels(host=self.src.host).set(
            1 if self.src.status == MysqlStatus.UP.value else 0
        )

        if self.repl is not None: 
            REPLICA_UP_STATUS.clear()
            REPLICA_UP_STATUS.labels(host=self.repl.host).set(
                1 if self.repl.status == MysqlStatus.UP.value else 0
            )

    def switch_src_and_repl(self): 
        self._log(f"Switching src[{self.src.host}] and repl[{self.repl.host}]")
        tmp_src = MysqlInstance(
            self.src.host, 
            self.src.user, 
            self.src.password,
            self.src.name,
            self.src.role,
        )
        self.src = MysqlInstance(
            self.repl.host, 
            self.repl.user, 
            self.repl.password,
            self.repl.name,
            MysqlRoles.SOURCE.value,
        )
        self.repl = MysqlInstance(
            tmp_src.host, 
            tmp_src.user, 
            tmp_src.password,
            tmp_src.name,
            MysqlRoles.REPLICA.value,
        )

    def update_cluster_state(self) -> dict: 
        if self.is_server_up(self.src, retry=1):
            self.src.status = MysqlStatus.UP.value
            self.src.health_check_failures = 0
        else: 
            self.src.status = MysqlStatus.DOWN.value
            self.src.health_check_failures += 1

        if self.repl is not None: 
            if self.is_server_up(self.repl, retry=1):
                self.repl.status = MysqlStatus.UP.value 
                problems = self.repl.find_replication_problems()
                if MysqlReplicationProblem.NOT_REPLICA.value in problems: 
                    self.repl.status = MysqlStatus.NOT_REPLICA.value
                    return
                if ( 
                    MysqlReplicationProblem.SQL_THREAD_NOT_RUNNING.value in problems 
                    or MysqlReplicationProblem.IO_THREAD_NOT_RUNNING.value in problems
                ):
                    self.repl.status = MysqlStatus.REPLICATION_THREADS_STOPPED.value
            else: 
                self.repl.status = MysqlStatus.DOWN.value
        
        self._write_cluster_state()

    def _write_cluster_state(self):
        ## TODO: maybe change this
        with open(CLUSTER_STATE_FILE_PATH, "w") as sf:
            sf.write(yaml.safe_dump(
                {
                    "source": self.src.status,
                    "replica": self.repl.status if self.repl is not None else MysqlStatus.DOWN.value,
                }
            ))

    def start_mysql_replication(self):
        ## TODO: reset replication all for both of them 
        self._log(f"Starting replication in {self.repl.host}")
        self.src.add_replica(self.repl)
        self.repl.set_master(self.src)
        self.repl.start_replication("replica", self.users["replPassword"])
    
    def is_server_up(self, server: BaseServer, retry: int=1) -> bool:
        for i in range(retry):
            try: 
                server.ping()
                return True
            except Exception:
                # do not sleep in last retry
                if i+1 != retry: 
                    time.sleep(RETRY_WAIT_SECONDS)

        return False

    def check_servers_up(self, retry: int=1): 
        # is_ok = False
        for _ in range(retry):
            try: 
                self.src.ping()
                if self.repl is not None:
                    self.repl.ping()
                self.proxysqls[0].ping()
                return
            except Exception as e:
                time.sleep(RETRY_WAIT_SECONDS)
            # is_ok = True
        
        # if is_ok == False:
        #     raise MysqlConnectionException()

    def config_src_initial_setup(self):
        self._log(f"Initial config of src[{self.src.host}]")
        self.src.add_pitr_event(minute_intervals=15)
        self.src.create_new_user(
            "replica", self.users["replPassword"], ["REPLICATION SLAVE"]
        )
        self.src.create_database(DEFAULT_DATABASE)
        self.src.create_monitoring_user(self.users["exporterPassword"])
        self.src.create_nonpriv_user(self.users["nonprivUser"], self.users["nonprivPassword"])
        self.src.create_new_user("proxysql", self.users["proxysqlMonPassword"], ["USAGE", "REPLICATION CLIENT"])
        
        self.proxysqls[0].add_backend(self.src, 1, True)

    def add_replica_to_source(self, retry: int=1):
        self._log("Joining replica to source")    
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

        self._log("Initializing config of servers...")
        if self.cluster_data_handler.get_cluster_state() == MysqlClusterState.NEW.value:
            self.proxysqls[0].initialize_setup()
            self.config_src_initial_setup()
            ## TODO: what if we restart before writing cluster data?
            self.cluster_data_handler.update_cluster_state(MysqlClusterState.CREATED.value)

        # if (
        #     self.repl is not None
        #     and not self.repl.joined 
        # ):
        #     self.add_replica_to_master(retry=10)

