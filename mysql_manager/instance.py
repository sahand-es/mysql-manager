import textwrap

import pymysql
from mysql_manager.enums import (
    MysqlConfigProblem,
    MysqlReplicationProblem,
)

from mysql_manager.exceptions import MysqlConnectionException, MysqlReplicationException, MysqlAddPITREventException
from mysql_manager.base import BaseManager
from mysql_manager.constants import DEFAULT_DATABASE

class MysqlInstance(BaseManager):
    def __init__(self, host: str, user: str, password: str, port: int=3306) -> None:
        self.host = host 
        self.port = port
        self.user = user
        self.password = password
        self.replicas: list[MysqlInstance] = []
        self.master: MysqlInstance = None
        # self.uptime = -1
        # self.server_id: int = -1 
        # self.server_uuid: int = -1 
        # self.is_readonly: bool = False
        # self.is_binlog_enabled: bool = True
        # self.binlog_format: str = "row" 
        # self.binlog_row_image: str = "full"
        # self.is_replica: bool = False 
        # self.is_replica_sql_running: bool = False 
        # self.is_replica_io_running: bool = False
        # self.using_gtid: bool = False
        # self.read_binlog_coordinates = None
        # self.exec_binlog_coordinates = None
        # self.seconds_behind_master: int = 0 
        # self.executed_gtid_set: str = "" 
    
    def user_exists(self, user: str, grants: list[str]) -> bool: 
        db = self._get_db()
        if db is None: 
            self._log("Could not connect to mysql")
            raise MysqlConnectionException()
        
        result = {}
        with db: 
            with db.cursor() as cursor:
                try: 
                    cursor.execute(f"SHOW GRANTS FOR '{user}'")
                    result = cursor.fetchone()
                except pymysql.err.OperationalError: 
                    return False
                except Exception as e: 
                    self._log(str(e))
                    raise e
        
        return True
    
    def create_database(self, name: str): 
        db = self._get_db()
        if db is None: 
            self._log("Could not connect to mysql")
            raise MysqlConnectionException()

        with db: 
            with db.cursor() as cursor:
                try: 
                    cursor.execute(f"CREATE DATABASE IF NOT EXISTS {name}")
                    cursor.fetchone()
                except Exception as e: 
                    self._log(str(e))
                    raise e
        
    def create_monitoring_user(self, password: str):
        db = self._get_db()
        if db is None: 
            self._log("Could not connect to mysql")
            raise MysqlConnectionException()
    
        with db: 
            with db.cursor() as cursor:
                try: 
                    cursor.execute(
                        f"CREATE USER IF NOT EXISTS 'exporter'@'%' IDENTIFIED WITH mysql_native_password BY '{password}' WITH MAX_USER_CONNECTIONS 3"
                    )
                    cursor.execute(
                        "GRANT PROCESS, REPLICATION CLIENT ON *.* TO 'exporter'@'%'"
                    )
                    cursor.execute(
                        "GRANT SELECT ON performance_schema.* TO 'exporter'@'%'"
                    )
                    cursor.execute("FLUSH PRIVILEGES")
                except Exception as e: 
                    self._log(str(e))
                    raise e

    def create_nonpriv_user(self, user: str, password: str): 
        db = self._get_db()
        if db is None: 
            self._log("Could not connect to mysql")
            raise MysqlConnectionException()

        with db: 
            with db.cursor() as cursor:
                try: 
                    cursor.execute(
                        f"CREATE USER IF NOT EXISTS '{user}'@'%' IDENTIFIED WITH mysql_native_password BY '{password}'"
                    )
                    cursor.execute(
                        f"GRANT CREATE, DROP, PROCESS, SHOW DATABASES, REPLICATION CLIENT, CREATE USER, CREATE ROLE, DROP ROLE ON *.* TO '{user}'@'%' WITH GRANT OPTION"
                    )
                    cursor.execute(
                        f"GRANT ROLE_ADMIN ON *.* TO '{user}'@'%' WITH GRANT OPTION"
                    )
                    cursor.execute(
                        f"GRANT ALL PRIVILEGES ON {DEFAULT_DATABASE}.* TO '{user}'@'%' WITH GRANT OPTION"
                    )
                    for db in ["mysql", "sys", "performance_schema"]:
                        cursor.execute(
                            f"GRANT SELECT ON {db}.* TO '{user}'@'%' WITH GRANT OPTION"
                        )
                except Exception as e: 
                    self._log(str(e))
                    raise e

    def create_new_user(self, user: str, password: str, grants: list[str]):
        db = self._get_db()
        if db is None: 
            self._log("Could not connect to mysql")
            raise MysqlConnectionException()
        
        with db: 
            with db.cursor() as cursor:
                try: 
                    cursor.execute(
                        f"CREATE USER IF NOT EXISTS '{user}'@'%' IDENTIFIED WITH mysql_native_password BY '{password}'"
                    )
                    grants_command = ",".join(grants)
                    cursor.execute(
                        f"GRANT {grants_command} ON *.* TO '{user}'@'%'"
                    )
                    cursor.execute("FLUSH PRIVILEGES")
                except Exception as e: 
                    self._log(str(e))
                    raise e
    
    def find_config_problems(self) -> list[MysqlReplicationProblem]: 
        db = self._get_db()
        if db is None: 
            self._log("Could not connect to mysql")
            raise MysqlConnectionException()
        
        with db: 
            with db.cursor() as cursor:
                try: 
                    cursor.execute('''
select @@global.log_bin, @@global.binlog_format, @@global.gtid_mode, @@global.enforce_gtid_consistency
''')
                    result = cursor.fetchone()
                except Exception as e: 
                    self._log(str(e))
                    raise e
        
        problems = []
        if result["@@global.log_bin"] != 1: 
            problems.append(MysqlConfigProblem.LOGBIN_NOT_ENABLED.value)
        if result["@@global.binlog_format"] != "ROW":
            problems.append(MysqlConfigProblem.LOGBIN_FORMAT.value)
        if result["@@global.gtid_mode"] != "ON": 
            problems.append(MysqlConfigProblem.GTID_NOT_ENABLED.value)
        if result["@@global.enforce_gtid_consistency"] != "ON":
            problems.append(MysqlConfigProblem.GTID_CONSISTENCY_NOT_ENABLED.value)
        
        return problems         

    def is_master_of(self, replica) -> bool:
        status = replica.get_replica_status()
        if status is None:
            return False 
        
        if status["Source_Host"] == self.host:
            return True

        return False 

    def add_replica(self, replica) -> None:
        if replica.is_replica() and not self.is_replica() and self.is_master_of(replica):
            self.replicas.append(replica)

    def get_master_status(self) -> dict:
        return self.get_info("SHOW MASTER STATUS") 

    def get_replica_status(self) -> dict:
        return self.get_info("SHOW REPLICA STATUS") 

    def is_replica(self) -> bool: 
        ## TODO: what if replica is not available?
        return self.get_replica_status() is not None 

    def find_replication_problems(self) -> list[MysqlReplicationProblem]:
        status = self.get_replica_status()
        if status is None: 
            return [MysqlReplicationProblem.NOT_SLAVE.value]
        
        # values of these two can be used in future: 'Replica_IO_State', 'Replica_SQL_Running_State'
        ## TODO: check if keys exist in `status`
        problems = []
        if status["Replica_IO_Running"] != "Yes":
            problems.append(MysqlReplicationProblem.IO_THREAD_NOT_RUNNING.value)
        if status["Replica_SQL_Running"] != "Yes":
            problems.append(MysqlReplicationProblem.SQL_THREAD_NOT_RUNNING.value)
        if status["Last_Errno"] != 0 and status["Last_Error"] != "":
            problems.append(MysqlReplicationProblem.LAST_ERROR.value)
        if status["Last_IO_Errno"] != 0 and status["Last_IO_Error"] != "":
            problems.append(MysqlReplicationProblem.IO_ERROR.value)
        if status["Last_SQL_Errno"] != 0 and status["Last_SQL_Error"] != "":
            problems.append(MysqlReplicationProblem.SQL_ERROR.value)
        if status["Seconds_Behind_Source"] is not None and status["Seconds_Behind_Source"] > 60:
            problems.append(MysqlReplicationProblem.REPLICATION_LAG_HIGH.value)
        if status["Auto_Position"] != 1:
            problems.append(MysqlReplicationProblem.AUTO_POSITION_DISABLED.value)
        
        return problems

    def set_master(self, master):
        if master.is_replica():
            self._log("This server at "+master.host+" is a replica and can not be set as master")
            return
        
        master_cfg_problems = master.find_config_problems()
        if len(master_cfg_problems) != 0:
            self._log("Problem in master at "+master.host+" config: " + str(master_cfg_problems))
            return
        
        self.master = master 

    def _generate_change_master_command(self, repl_user: str, repl_password: str) -> str:
        return f"""
CHANGE REPLICATION SOURCE TO SOURCE_HOST='{self.master.host}', 
    SOURCE_USER='{repl_user}',
    SOURCE_PASSWORD='{repl_password}',
    SOURCE_CONNECT_RETRY = 1,
    SOURCE_RETRY_COUNT = 10,
    SOURCE_AUTO_POSITION = 1; 
"""
    ## TODO: read orchestrator code 
    ## TODO: check server ids not equal
    def start_replication(self, repl_user: str, repl_password: str): 
        if self.master is None: 
            self._log("No master set for this instance")
            raise MysqlReplicationException()
        
        if not self.master.ping():
            self._log("Master not accesible")
            raise MysqlReplicationException()
        
        cfg_problems = self.find_config_problems()
        if len(cfg_problems) != 0: 
            self._log("Problem in config: " + str(cfg_problems))
            raise MysqlReplicationException()

        repl_status = self.get_replica_status()
        if repl_status is not None and repl_status["Replica_IO_Running"] == "Yes" and repl_status["Replica_SQL_Running"] == "Yes": 
            self._log("Replication is running")
            return

        db = self._get_db()
        if db is None: 
            self._log("Could not connect to mysql")
            raise MysqlConnectionException()
        
        with db: 
            with db.cursor() as cursor:
                try: 
                    cursor.execute(
                        self._generate_change_master_command(repl_user, repl_password)
                    )
                    cursor.execute("SET GLOBAL SUPER_READ_ONLY=1")
                    cursor.execute("START REPLICA")
                    result = cursor.fetchone()
                    self._log(str(result))
                except Exception as e:
                    self._log(str(e)) 
                    raise MysqlReplicationException()

    def add_pitr_event(self, minute_intervals: int=15):
        db = self._get_db()
        if db is None:
            self._log("Could not connect to mysql")
            raise MysqlConnectionException()

        with db:
            with db.cursor() as cursor:
                try:
                    cursor.execute("USE mysql;")
                    cursor.execute(
                        f"CREATE EVENT pitr ON SCHEDULE EVERY {minute_intervals} MINUTE DO FLUSH BINARY LOGS;"
                    )
                except Exception as e:
                    self._log(str(e))
                    raise MysqlAddPITREventException()
