from mysql_manager.instance import MysqlInstance
from mysql_manager.proxysql import ProxySQL
import os, time 


MYSQL_S1_HOST = os.getenv("MYSQL_S1_HOST")
# MYSQL_S2_HOST = os.getenv("MYSQL_S2_HOST")
MYSQL_ROOT_PASSWORD = os.getenv("MYSQL_ROOT_PASSWORD")
MYSQL_EXPORTER_PASSWORD = os.getenv("MYSQL_EXPORTER_PASSWORD")
# MYSQL_REPL_PASSWORD = os.getenv("MYSQL_REPL_PASSWORD")
PROXYSQL_HOST = os.getenv("PROXYSQL_HOST")
PROXYSQL_PASSWORD = os.getenv("PROXYSQL_PASSWORD")
PROXYSQL_MON_PASSWORD = os.getenv("PROXYSQL_MON_PASSWORD")

src = MysqlInstance(MYSQL_S1_HOST, "root", MYSQL_ROOT_PASSWORD)
src.create_monitoring_user(MYSQL_EXPORTER_PASSWORD)

src.create_new_user("proxysql", PROXYSQL_MON_PASSWORD, ["USAGE", "REPLICATION CLIENT"])
time.sleep(5)
px = ProxySQL(
    PROXYSQL_HOST, 
    "radmin", 
    PROXYSQL_PASSWORD, 
    "root", 
    MYSQL_ROOT_PASSWORD, 
    "proxysql", 
    PROXYSQL_MON_PASSWORD
)
px.initialize_setup()
px.add_backend(src, 1, True)
# px.add_backend(repl, 1, False)
