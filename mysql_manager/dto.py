from dataclasses import dataclass
from mysql_manager.enums import MysqlClusterState, MysqlRoles


@dataclass
class MysqlData:
    role: MysqlRoles
    host: str 
    user: str 
    password: str
    port: int = 3306


@dataclass
class ClusterStatus:
    state: MysqlClusterState


## TODO: define exact dtos for dicts
@dataclass
class ClusterData:
    mysqls: dict[str: MysqlData]
    remote: MysqlData | None 
    status: ClusterStatus
    proxysqls: list[dict[str: str]]
    users: dict[str: str]
