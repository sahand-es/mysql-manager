from mysql_manager.instance import MysqlInstance
from mysql_manager.base import BaseManager
from mysql_manager.exceptions import MysqlConnectionException

class ProxySQL(BaseManager): 
    def __init__(
        self, 
        host: str,
        user: str,
        password: str, 
        mysql_user: str, 
        mysql_password: str,
        monitor_user: str, 
        monitor_password: str,    
    ) -> None:
        super().__init__(host, user, password, 6032)
        self.mysql_user = mysql_user
        self.mysql_password = mysql_password
        self.monitor_user = monitor_user
        self.monitor_password = monitor_password
        self.backends: dict[str: MysqlInstance] = []

    def add_backend(self, instance: MysqlInstance, read_weight: int=1, is_writer: bool=False):
        db = self._get_db()
        if db is None: 
            print("Could not connect to proxysql")
            raise MysqlConnectionException
        
        with db: 
            with db.cursor() as cursor:
                try: 
                    cursor.execute(f"INSERT INTO mysql_servers(hostgroup_id, hostname, port, weight) VALUES (1,'{instance.host}',3306, {read_weight})")
                    if is_writer:
                        cursor.execute(f"INSERT INTO mysql_servers(hostgroup_id, hostname, port) VALUES (0,'{instance.host}',3306)")
                    cursor.execute("load mysql servers to runtime")
                    cursor.execute("save mysql servers to disk")
                    result = cursor.fetchall()
                    print(result)
                    self.backends.append(instance)
                except Exception as e: 
                    print(e)
                    raise Exception

    def find_backend_problems(self):
        pass 

    def find_proxysql_problems(self):
        pass

    def initialize_setup(self):
        db = self._get_db()
        if db is None: 
            print("Could not connect to mysql")
            raise MysqlConnectionException
        
        with db: 
            with db.cursor() as cursor:
                try: 
                    cursor.execute("INSERT INTO mysql_replication_hostgroups (writer_hostgroup,reader_hostgroup,comment) VALUES (0,1,'main')")
                    cursor.execute("load mysql servers to runtime")
                    cursor.execute("save mysql servers to disk")
                    cursor.execute(f"UPDATE global_variables SET variable_value='{self.monitor_user}' WHERE variable_name='mysql-monitor_username'")
                    cursor.execute(f"UPDATE global_variables SET variable_value='{self.monitor_password}' WHERE variable_name='mysql-monitor_password'")
                    cursor.execute("load mysql variables to runtime")
                    cursor.execute("save mysql variables to disk")
                    cursor.execute("INSERT INTO mysql_query_rules (active, match_digest, destination_hostgroup, apply) VALUES (1, '^SELECT.*', 1, 0)")
                    cursor.execute("load mysql query rules to runtime")
                    cursor.execute("save mysql query rules to disk")
                    cursor.execute(f"INSERT INTO mysql_users (username,password) VALUES ('{self.mysql_user}','{self.mysql_password}')")
                    cursor.execute("load mysql users to runtime")
                    cursor.execute("save mysql users to disk")
                    result = cursor.fetchall()
                    print(result)
                except Exception as e: 
                    print(e)
                    raise e



