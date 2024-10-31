from mysql_manager.instance import Mysql
from mysql_manager.proxysql import ProxySQL
import os 


MYSQL_S1_HOST = os.getenv("MYSQL_S1_HOST")
MYSQL_S2_HOST = os.getenv("MYSQL_S2_HOST")
MYSQL_ROOT_PASSWORD = os.getenv("MYSQL_ROOT_PASSWORD")
MYSQL_REPL_PASSWORD = os.getenv("MYSQL_REPL_PASSWORD")
MYSQL_EXPORTER_PASSWORD = os.getenv("MYSQL_EXPORTER_PASSWORD")

src = Mysql(MYSQL_S1_HOST, "root", MYSQL_ROOT_PASSWORD)
repl = Mysql(MYSQL_S2_HOST, "root", MYSQL_ROOT_PASSWORD)
src.create_new_user("replica", MYSQL_REPL_PASSWORD, ["REPLICATION SLAVE"])
src.add_replica(repl)
repl.set_source(src)
repl.start_replication("replica", MYSQL_REPL_PASSWORD)

## create monitoring user 
src.create_monitoring_user(MYSQL_EXPORTER_PASSWORD)
