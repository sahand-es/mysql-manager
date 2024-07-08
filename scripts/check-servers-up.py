from mysql_manager.instance import MysqlInstance
from mysql_manager.proxysql import ProxySQL
import os, time, json 

MYSQL_S1_HOST = os.getenv("MYSQL_S1_HOST")
MYSQL_S2_HOST = os.getenv("MYSQL_S2_HOST")
MYSQL_ROOT_PASSWORD = os.getenv("MYSQL_ROOT_PASSWORD")
MYSQL_REPL_PASSWORD = os.getenv("MYSQL_REPL_PASSWORD")
MYSQL_EXPORTER_PASSWORD = os.getenv("MYSQL_EXPORTER_PASSWORD")
PROXYSQL_HOST = os.getenv("PROXYSQL_HOST")
PROXYSQL_PASSWORD = os.getenv("PROXYSQL_PASSWORD")
PROXYSQL_MON_PASSWORD = os.getenv("PROXYSQL_MON_PASSWORD")

src = MysqlInstance(MYSQL_S1_HOST, "root", MYSQL_ROOT_PASSWORD)
repl = MysqlInstance(MYSQL_S2_HOST, "root", MYSQL_ROOT_PASSWORD)
px = ProxySQL(
    PROXYSQL_HOST, 
    "radmin", 
    PROXYSQL_PASSWORD, 
    "root", 
    MYSQL_ROOT_PASSWORD, 
    "proxysql", 
    PROXYSQL_MON_PASSWORD
)

status = {"src": "down", "repl": "down", "proxy": "down"}
src_ping = src.ping()
repl_ping = repl.ping()
proxy_ping = px.ping()
src_command = src.get_info("select 1")
repl_command = repl.get_info("select 1")
proxy_command = px.get_info("select 1")
# print(proxy_ping, proxy_command)

if src_ping and src_command.get("1", "0") == 1:
    status["src"] = "up" 
if repl_ping and repl_command.get("1", "0") == 1:
    status["repl"] = "up"
if proxy_ping and proxy_command.get("1", "0") == "1":
    status["proxy"] = "up"

print(json.dumps(status))
