from dataclasses import dataclass
from mysql_manager.enums import MysqlClusterState, MysqlRoles


@dataclass
class MysqlData:
    role: MysqlRoles
    host: str 
    user: str 
    password: str


@dataclass
class ClusterStatus:
    state: MysqlClusterState


## TODO: define exact values for dicts
@dataclass
class ClusterData:
    mysqls: dict[str: MysqlData]
    status: ClusterStatus
    proxysqls: list[dict[str: str]]
    users: dict[str: str]
