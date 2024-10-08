from dataclasses import dataclass
from mysql_manager.enums import MysqlClusterState

@dataclass
class ClusterStateDTO:
    master: str
    replica: str 
    old_master_joined: bool
    master_failure_count: int
    state: MysqlClusterState
