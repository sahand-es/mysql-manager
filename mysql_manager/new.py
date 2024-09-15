from prometheus_client import Counter, Gauge, Histogram, start_http_server

# Prometheus Metrics
FAILOVER_ATTEMPTS = Counter('mysql_failover_attempts', 'Number of failover attempts made')
SUCCESSFUL_FAILOVERS = Counter('mysql_successful_failovers', 'Number of successful failovers')
MASTER_FAILURES = Counter('mysql_master_failures', 'Total number of master failures')
REPLICATION_RESTARTS = Counter('mysql_replication_restarts', 'Number of replication restarts on replicas')
CLUSTER_FAILURES = Counter('mysql_cluster_failures', 'Total number of cluster failures (master and replica down)')
MASTER_FAILURE_THRESHOLD_EXCEEDED = Counter('mysql_master_failure_threshold_exceeded', 'Number of times master failure count exceeded the threshold')
BACKEND_REMOVALS = Counter('proxysql_backend_removals', 'Number of times backend removal was triggered in ProxySQL')

# Gauges can track the current state of the system
MASTER_UP_STATUS = Gauge('mysql_master_up_status', 'Current status of the MySQL master (1=up, 0=down)')
REPLICA_UP_STATUS = Gauge('mysql_replica_up_status', 'Current status of the MySQL replica (1=up, 0=down)')
CURRENT_MASTER_FAILURE_COUNT = Gauge('mysql_master_failure_count', 'Current number of master failures')

# Histograms for tracking latency of operations
FAILOVER_DURATION = Histogram('mysql_failover_duration_seconds', 'Time taken for a complete failover process')

class ClusterManager: 
    def __init__(self, config_file: str = DEFAULT_CONFIG_PATH):
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
        self.spec = {}
        self._initialize_cluster()
        
        # Start Prometheus metrics server on port 8000
        start_http_server(8000)
    
    def reconcile_cluster(self):
        self._log("Running reconciliation for cluster")
        if self.state.old_master_joined == False: 
            self.add_replica_to_master(retry=1)
            # TODO: if successful, increase successful failover metric
            SUCCESSFUL_FAILOVERS.inc()
        
        self.update_cluster_state()
        self._log("Current cluster state: " + str(self.state))
        
        # Update Gauges for master and replica status
        MASTER_UP_STATUS.set(1 if self.state.master == MysqlStatus.UP.value else 0)
        REPLICA_UP_STATUS.set(1 if self.state.replica == MysqlStatus.UP.value else 0)

        if (
            self.state.replica == MysqlStatus.NOT_REPLICATING.value
            and self.state.master == MysqlStatus.UP.value
        ):
            self.repl.restart_replication()
            REPLICATION_RESTARTS.inc()
        elif (
            self.state.master == MysqlStatus.DOWN.value
            and self.state.replica == MysqlStatus.DOWN.value
        ):
            # Increment cluster failure count if both master and replica are down
            CLUSTER_FAILURES.inc()
            self._log("Cluster failure detected: Both master and replica are down.")
        elif (
            self.state.master_failure_count > MASTER_FAILURE_THRESHOLD 
            and self.state.replica in [MysqlStatus.UP.value, MysqlStatus.NOT_REPLICATING.value]
        ):
            self._log("Running failover for cluster")
            
            # Increment failover-related metrics
            FAILOVER_ATTEMPTS.inc()
            MASTER_FAILURE_THRESHOLD_EXCEEDED.inc()

            self.state.old_master_joined = False
            self.proxysqls[0].remove_backend(self.src)
            BACKEND_REMOVALS.inc()
            
            # Track failover time
            with FAILOVER_DURATION.time():
                self.repl.reset_replication()
                self.switch_src_and_repl()

        self._log(f"Master is {self.src.host}")
        if self.repl is not None: 
            self._log(f"Replica is {self.repl.host}")
        
        # Update master failure count gauge
        CURRENT_MASTER_FAILURE_COUNT.set(self.state.master_failure_count)

    def update_cluster_state(self) -> dict: 
        if not self.is_server_up(self.src, retry=1):
            self.state.master = MysqlStatus.DOWN.value
            self.state.master_failure_count += 1
            MASTER_FAILURES.inc()  # Increment master failures counter
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

    # Other methods remain unchanged...
