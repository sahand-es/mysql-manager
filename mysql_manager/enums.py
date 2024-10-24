from enum import Enum

class MysqlStatus(Enum):
    UP = "up"
    DOWN = "down"
    NOT_REPLICA = "not_replica"
    REPLICATION_THREADS_STOPPED = "replication_threads_stopped"

class MysqlReplicationProblem(Enum):
    IO_THREAD_NOT_RUNNING = "io_thread_not_running" 
    SQL_THREAD_NOT_RUNNING = "sql_thread_not_running"
    LAST_ERROR = "last_error" # this is for when there is no IO nor SQL errors
    IO_ERROR = "io_error"
    SQL_ERROR = "sql_error"
    REPLICATION_LAG_HIGH = "replication_lag_high"
    NOT_REPLICA = "not_replica"
    AUTO_POSITION_DISABLED = "auto_position_disabled"
    NO_PROBLEM = "no_problem"


class MysqlConfigProblem(Enum):
    LOGBIN_NOT_ENABLED = "logbin_not_enabled"
    LOGBIN_FORMAT = "logbin_format"
    GTID_NOT_ENABLED = "gtid_not_enabled"
    GTID_CONSISTENCY_NOT_ENABLED = "gtid_consistency_not_enabled"
    NO_PROBLEM = "no_problem"


class MysqlClusterState(Enum):
    CREATED = "created" 
    NEW = "new"

class MysqlRoles(Enum):
    SOURCE = "source"
    REPLICA = "replica"
    READONLY_REPLICA = "readonly_replica"
# class ProxySQLBackendState(Enum): 
#     REPLICA =     
