from prometheus_client import Counter, Gauge 

# Prometheus Metrics
# Counters
FAILOVER_ATTEMPTS = Counter('mysql_failover_attempts', 'Number of failover attempts made')
SUCCESSFUL_FAILOVERS = Counter('mysql_successful_failovers', 'Number of successful failovers')
REPLICATION_RESTARTS = Counter('mysql_replication_restarts', 'Number of replication restarts on replicas')
CLUSTER_FAILURES = Counter('mysql_cluster_failures', 'Total number of cluster failures (master and replica down)')

# Gauges
mysql_status_labels = ["host"]
MASTER_UP_STATUS = Gauge(
    'mysql_master_up', 
    'Current status of the MySQL master (1=up, 0=down)',
    mysql_status_labels,
)
REPLICA_UP_STATUS = Gauge(
    'mysql_replica_up', 
    'Current status of the MySQL replica (1=up, 0=down)',
    mysql_status_labels,
)
