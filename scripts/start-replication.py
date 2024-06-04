from mysql_manager.instance import MysqlInstance
from mysql_manager.proxysql import ProxySQL
import os 


MYSQL_S1_HOST = os.getenv("MYSQL_S1_HOST")
MYSQL_S2_HOST = os.getenv("MYSQL_S2_HOST")
MYSQL_ROOT_PASSWORD = os.getenv("MYSQL_ROOT_PASSWORD")
MYSQL_REPL_PASSWORD = os.getenv("MYSQL_REPL_PASSWORD")

src = MysqlInstance(MYSQL_S1_HOST, "root", MYSQL_ROOT_PASSWORD)
repl = MysqlInstance(MYSQL_S2_HOST, "root", MYSQL_ROOT_PASSWORD)
src.create_new_user("replica", MYSQL_REPL_PASSWORD, ["REPLICATION SLAVE"])
src.add_replica(repl)
repl.set_master(src)
repl.start_replication("replica", MYSQL_REPL_PASSWORD)
