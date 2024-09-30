from enum import Enum

class MysqlStatus(Enum):
    UP = "up"
    DOWN = "down"
    NOT_REPLICA = "not_replica"
    REPLICATION_THREADS_STOPPED = "replication_threads_stopped"

class MysqlReplicationProblem(Enum):
    IO_THREAD_NOT_RUNNING = 1 
    SQL_THREAD_NOT_RUNNING = 2 
    LAST_ERROR = 3 # this is for when there is no IO nor SQL errors
    IO_ERROR = 4
    SQL_ERROR = 5
    REPLICATION_LAG_HIGH = 6
    NOT_REPLICA = 7
    AUTO_POSITION_DISABLED = 8
    NO_PROBLEM = 0


class MysqlConfigProblem(Enum):
    LOGBIN_NOT_ENABLED = 1 
    LOGBIN_FORMAT = 2
    GTID_NOT_ENABLED = 3 
    GTID_CONSISTENCY_NOT_ENABLED = 4
    NO_PROBLEM = 0


# class ProxySQLBackendState(Enum): 
#     REPLICA =     
