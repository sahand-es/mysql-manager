from mysql_manager.instance import Mysql
from mysql_manager.proxysql import ProxySQL
from mysql_manager.cluster import ClusterManager

def test_normal_info_wrong():
    tests = [
        {"host": "wrong-host", "user": "root", "password": "root"},
        {"host": "test-mysql-s1-svc", "user": "wrong", "password": "root"},
        {"host": "test-mysql-s1-svc", "user": "root", "password": "wrong"},
    ]
    for i in tests: 
        print(i)
        inst = Mysql(**i)
        print("pinged: " + str(inst.ping()))
        inst.get_master_status()
        print("config problem: " + str(inst.find_config_problems()))
        print("\n\n")

def test_timeout():
    tests = [
        {"host": "test-mysql-s1-svc", "user": "root", "password": "root", "port": 3304},
    ]
    for i in tests: 
        print(i)
        inst = Mysql(**i)
        print("pinged: " + str(inst.ping()))
        print("\n\n")

def test_replication():
    tests = [
        {"host": "test-mysql-s1-svc", "user": "root", "password": "root"},
        {"host": "test-mysql-s2-svc", "user": "root", "password": "root"},
    ]
    src = Mysql(**tests[0])
    repl = Mysql(**tests[1])
    src.create_new_user("replica", "replica", ["REPLICATION SLAVE"])
    print("user replica exists: ", str(src.user_exists("replica", [])))
    src.add_replica(repl)
    repl.set_source(src)
    repl.start_replication("replica", "replica")
    print("is src replica: " + str(src.is_replica()))
    print("is repl replica: " + str(repl.is_replica()))
    print("src config problems: " + str(src.find_config_problems()))
    print("repl config problems: " + str(repl.find_config_problems()))
    print("src replication problems: " + str(src.find_replication_problems()))
    print("repl replication problems: " + str(repl.find_replication_problems()))
    src.add_replica(repl)
    print("src replica: " + src.replicas[0].host)
    print("is src master of repl: " + str(src.is_master_of(repl)))

def test_proxysql():
    tests = [
        {"host": "test-mysql-s1-svc", "user": "root", "password": "root"},
        {"host": "test-mysql-s2-svc", "user": "root", "password": "root"},
        {"host": "test-proxysql-svc", "user": "radmin", "password": "radmin", "mysql_user": "str", 
        "mysql_password": "str",
        "monitor_user": "str", 
        "monitor_password": "str"},
    ]
    px = ProxySQL(**tests[2])
    print("Pinged: " + str(px.ping()))

def test_cluster_read_config():
    clm = ClusterManager("./tests/config/mm-config-mysql-1.yaml")
    assert clm.src.host == "mysql-s1"
    assert clm.src.user == "root"
    assert clm.src.password == "root"
    # print(clm.repl)
    assert len(clm.proxysqls) == 1 
    assert clm.proxysqls[0].host == "proxysql" 
    assert clm.proxysqls[0].user == "radmin" 
    assert clm.proxysqls[0].password == "pwd" 
    assert clm.users == {
        "replPassword": "password",
        "exporterPassword": "exporter",
        "nonprivPassword": "password",
        "nonprivUser": "dbadmin",
        "proxysqlMonPassword": "password",
    }


if __name__ == "__main__": 
    # test_normal_info_wrong()
    # test_timeout()
    test_cluster_read_config()
