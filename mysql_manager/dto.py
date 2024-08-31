from dataclasses import dataclass

@dataclass
class ClusterStateDTO:
    master: str
    replica: str 
    old_master_joined: bool
    master_failure_count: int
