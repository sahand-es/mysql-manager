Feature: test migrate remote
  setup cluster nodes, setup another mysql, add data to it, migrate its data to mysql manager cluster and promote cluster 
## TODO: migrate from wrong server (version, config, etc.)
  Scenario: test migration to cluster with two servers and promotion
    Given setup etcd with name etcd and image: quay.hamdocker.ir/coreos/etcd:v3.5.9-amd64
    And setup user root with password: password for etcd
    And setup user mm for etcd with password: password access to path mm/cluster1/
    And setup default mysql with server_id 1 and image: hub.hamdocker.ir/library/mysql:8.0.35-bullseye
    And setup default mysql with server_id 2 and image: hub.hamdocker.ir/library/mysql:8.0.35-bullseye
    And setup default mysql with server_id 3 and name remote and image: hub.hamdocker.ir/library/mysql:8.0.35-bullseye
    And execute mysql query with user: root, password: root, host: remote and port: 3306 query: create database remotedb; use remotedb; CREATE TABLE t1 (c1 INT PRIMARY KEY, c2 TEXT NOT NULL);INSERT INTO t1 VALUES (120, 'Remoters');
    And execute mysql query with user: root, password: root, host: remote and port: 3306 query: use mysql; INSTALL PLUGIN clone SONAME 'mysql_clone.so';
    And setup mysql_manager with remote(remote, root, root, 3306) with name mm with env ETCD_HOST=etcd ETCD_USERNAME=mm ETCD_PASSWORD=password ETCD_PREFIX=mm/cluster1/
    And setup haproxy with name hap1 with env ETCD_HOST=http://etcd:2379 ETCD_USERNAME=mm ETCD_PASSWORD=password ETCD_PREFIX=mm/cluster1/
    And setup haproxy with name hap2 with env ETCD_HOST=http://etcd:2379 ETCD_USERNAME=mm ETCD_PASSWORD=password ETCD_PREFIX=mm/cluster1/
    And init mysql cluster spec standby of remote mysql
    And sleep 50 seconds
    ## testing clone
    Then cluster status must be
    """
    source=replicating_remote
    replica=up

    """
    Then result of query: "select * from remotedb.t1;" with user: root and password: root on host: mysql-s1 and port: 3306 should be
    """
    <?xml version="1.0"?>

    <resultset statement="select * from remotedb.t1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <row>
	    <field name="c1">120</field>
	    <field name="c2">Remoters</field>
      </row>
    </resultset>
    """
    ## testing replication
    Given execute mysql query with user: root, password: root, host: remote and port: 3306 query: use remotedb; INSERT INTO t1 VALUES (121, 'RemoteLuis');
    And sleep 5 seconds
    Then result of query: "select * from remotedb.t1;" with user: root and password: root on host: mysql-s1 and port: 3306 should be
    """
    <?xml version="1.0"?>

    <resultset statement="select * from remotedb.t1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <row>
	    <field name="c1">120</field>
	    <field name="c2">Remoters</field>
      </row>
      <row>
	    <field name="c1">121</field>
	    <field name="c2">RemoteLuis</field>
      </row>
    </resultset>
    """

    And result of query: "select HOST from performance_schema.replication_connection_configuration;" with user: root and password: root on host: mysql-s1 and port: 3306 should be
    """
    <?xml version="1.0"?>

    <resultset statement="select HOST from performance_schema.replication_connection_configuration" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <row>
	    <field name="HOST">remote</field>
      </row>
    </resultset>
    """

    ## test promotion
    Given promote mysql cluster 
    And sleep 50 seconds
    Then cluster status must be
    """
    source=up
    replica=up
    
    """
    And result of query: "select * from remotedb.t1;" with user: root and password: root on host: mysql-s2 and port: 3306 should be
    """
    <?xml version="1.0"?>

    <resultset statement="select * from remotedb.t1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <row>
	    <field name="c1">120</field>
	    <field name="c2">Remoters</field>
      </row>
      <row>
	    <field name="c1">121</field>
	    <field name="c2">RemoteLuis</field>
      </row>
    </resultset>
    """
    And result of query: "show replica status;" with user: root and password: root on host: mysql-s1 and port: 3306 should be
    """
    <?xml version="1.0"?>

    <resultset statement="show replica status" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"></resultset>
    """
    And result of query: "select HOST from performance_schema.replication_connection_configuration;" with user: root and password: root on host: mysql-s2 and port: 3306 should be
    """
    <?xml version="1.0"?>

    <resultset statement="select HOST from performance_schema.replication_connection_configuration" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <row>
	    <field name="HOST">mysql-s1</field>
      </row>
    </resultset>
    """

    And result of query: "SELECT user FROM mysql.user;" with user: root and password: root on host: mysql-s1 and port: 3306 should be
    """
    <?xml version="1.0"?>

    <resultset statement="SELECT user FROM mysql.user" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <row>
	    <field name="user">exporter</field>
      </row>

      <row>
	    <field name="user">hamadmin</field>
      </row>

      <row>
	    <field name="user">replica</field>
      </row>

      <row>
	    <field name="user">root</field>
      </row>

      <row>
	    <field name="user">mysql.infoschema</field>
      </row>

      <row>
	    <field name="user">mysql.session</field>
      </row>

      <row>
	    <field name="user">mysql.sys</field>
      </row>

      <row>
	    <field name="user">root</field>
      </row>
    </resultset>
    """

    Then result of query: "show grants for hamadmin;" with user: root and password: root on host: mysql-s1 and port: 3306 should be
    """
    <?xml version="1.0"?>

    <resultset statement="show grants for hamadmin" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <row>
	    <field name="Grants for hamadmin@%">GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, RELOAD, PROCESS, REFERENCES, INDEX, ALTER, SHOW DATABASES, CREATE TEMPORARY TABLES, LOCK TABLES, EXECUTE, REPLICATION SLAVE, REPLICATION CLIENT, CREATE VIEW, SHOW VIEW, CREATE ROUTINE, EVENT, TRIGGER ON *.* TO `hamadmin`@`%`</field>
      </row>
    </resultset>
    """

    Then result of query: "show databases;" with user: root and password: root on host: mysql-s1 and port: 3306 should be
    """
    <?xml version="1.0"?>

    <resultset statement="show databases" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <row>
	    <field name="Database">hamdb</field>
      </row>

      <row>
	    <field name="Database">information_schema</field>
      </row>

      <row>
	    <field name="Database">mysql</field>
      </row>

      <row>
	    <field name="Database">performance_schema</field>
      </row>

      <row>
	    <field name="Database">remotedb</field>
      </row>

      <row>
	    <field name="Database">sys</field>
      </row>

      <row>
	    <field name="Database">test</field>
      </row>
    </resultset>
    """

    Given restart mysql manager with env ETCD_HOST=etcd ETCD_USERNAME=mm ETCD_PASSWORD=password ETCD_PREFIX=mm/cluster1/
    And sleep 30 seconds
    Then cluster status must be
    """
    source=up
    replica=up
    
    """
    And result of query: "show replica status;" with user: root and password: root on host: mysql-s1 and port: 3306 should be
    """
    <?xml version="1.0"?>

    <resultset statement="show replica status" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"></resultset>
    """
    # Then result of query: "show master status;" with user: root and password: root on host: mysql-s2 and port: 3306 should be
    # """
    # """
    
    # Then result of query: "show replica status;" with user: root and password: root on host: mysql-s1 and port: 3306 should be
    # """
    # """
    
    # Then result of query: "show master status;" with user: root and password: root on host: mysql-s1 and port: 3306 should be
    # """
    # """


  Scenario: test migration to cluster with one server and promotion
    Given setup etcd with name etcd and image: quay.hamdocker.ir/coreos/etcd:v3.5.9-amd64
    And setup user root with password: password for etcd
    And setup user mm for etcd with password: password access to path mm/cluster1/
    And setup default mysql with server_id 1 and image: hub.hamdocker.ir/library/mysql:8.0.35-bullseye
    And setup default mysql with server_id 3 and name remote and image: hub.hamdocker.ir/library/mysql:8.0.35-bullseye
    And execute mysql query with user: root, password: root, host: remote and port: 3306 query: create database remotedb; use remotedb; CREATE TABLE t1 (c1 INT PRIMARY KEY, c2 TEXT NOT NULL);INSERT INTO t1 VALUES (120, 'Remoters');
    And execute mysql query with user: root, password: root, host: remote and port: 3306 query: use mysql; INSTALL PLUGIN clone SONAME 'mysql_clone.so';
    And setup mysql_manager with remote(remote, root, root, 3306) with name mm with env ETCD_HOST=etcd ETCD_USERNAME=mm ETCD_PASSWORD=password ETCD_PREFIX=mm/cluster1/
    And setup haproxy with name hap1 with env ETCD_HOST=http://etcd:2379 ETCD_USERNAME=mm ETCD_PASSWORD=password ETCD_PREFIX=mm/cluster1/
    And setup haproxy with name hap2 with env ETCD_HOST=http://etcd:2379 ETCD_USERNAME=mm ETCD_PASSWORD=password ETCD_PREFIX=mm/cluster1/
    And init mysql cluster spec standby of remote mysql
    And sleep 50 seconds
    ## testing clone
    Then cluster status must be
    """
    source=replicating_remote
    replica=down

    """
    And result of query: "select * from remotedb.t1;" with user: root and password: root on host: mysql-s1 and port: 3306 should be
    """
    <?xml version="1.0"?>

    <resultset statement="select * from remotedb.t1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <row>
	    <field name="c1">120</field>
	    <field name="c2">Remoters</field>
      </row>
    </resultset>
    """
    ## testing replication
    Given execute mysql query with user: root, password: root, host: remote and port: 3306 query: use remotedb; INSERT INTO t1 VALUES (121, 'RemoteLuis');
    And sleep 5 seconds
    Then result of query: "select * from remotedb.t1;" with user: root and password: root on host: mysql-s1 and port: 3306 should be
    """
    <?xml version="1.0"?>

    <resultset statement="select * from remotedb.t1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <row>
	    <field name="c1">120</field>
	    <field name="c2">Remoters</field>
      </row>
      <row>
	    <field name="c1">121</field>
	    <field name="c2">RemoteLuis</field>
      </row>
    </resultset>
    """

    And result of query: "select HOST from performance_schema.replication_connection_configuration;" with user: root and password: root on host: mysql-s1 and port: 3306 should be
    """
    <?xml version="1.0"?>

    <resultset statement="select HOST from performance_schema.replication_connection_configuration" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <row>
	    <field name="HOST">remote</field>
      </row>
    </resultset>
    """

    ## test promotion
    Given promote mysql cluster 
    And sleep 30 seconds
    Then cluster status must be
    """
    source=up
    replica=down
    
    """
    And result of query: "show replica status;" with user: root and password: root on host: mysql-s1 and port: 3306 should be
    """
    <?xml version="1.0"?>

    <resultset statement="show replica status" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"></resultset>
    """
    And result of query: "SELECT user FROM mysql.user;" with user: root and password: root on host: mysql-s1 and port: 3306 should be
    """
    <?xml version="1.0"?>

    <resultset statement="SELECT user FROM mysql.user" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <row>
	    <field name="user">exporter</field>
      </row>

      <row>
	    <field name="user">hamadmin</field>
      </row>

      <row>
	    <field name="user">replica</field>
      </row>

      <row>
	    <field name="user">root</field>
      </row>

      <row>
	    <field name="user">mysql.infoschema</field>
      </row>

      <row>
	    <field name="user">mysql.session</field>
      </row>

      <row>
	    <field name="user">mysql.sys</field>
      </row>

      <row>
	    <field name="user">root</field>
      </row>
    </resultset>
    """

    Then result of query: "show grants for hamadmin;" with user: root and password: root on host: mysql-s1 and port: 3306 should be
    """
    <?xml version="1.0"?>

    <resultset statement="show grants for hamadmin" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <row>
	    <field name="Grants for hamadmin@%">GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, RELOAD, PROCESS, REFERENCES, INDEX, ALTER, SHOW DATABASES, CREATE TEMPORARY TABLES, LOCK TABLES, EXECUTE, REPLICATION SLAVE, REPLICATION CLIENT, CREATE VIEW, SHOW VIEW, CREATE ROUTINE, EVENT, TRIGGER ON *.* TO `hamadmin`@`%`</field>
      </row>
    </resultset>
    """

    Then result of query: "show databases;" with user: root and password: root on host: mysql-s1 and port: 3306 should be
    """
    <?xml version="1.0"?>

    <resultset statement="show databases" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <row>
	    <field name="Database">hamdb</field>
      </row>

      <row>
	    <field name="Database">information_schema</field>
      </row>

      <row>
	    <field name="Database">mysql</field>
      </row>

      <row>
	    <field name="Database">performance_schema</field>
      </row>

      <row>
	    <field name="Database">remotedb</field>
      </row>

      <row>
	    <field name="Database">sys</field>
      </row>

      <row>
	    <field name="Database">test</field>
      </row>
    </resultset>
    """

    Given restart mysql manager with env ETCD_HOST=etcd ETCD_USERNAME=mm ETCD_PASSWORD=password ETCD_PREFIX=mm/cluster1/
    And sleep 30 seconds
    Then cluster status must be
    """
    source=up
    replica=down
    
    """
    And result of query: "show replica status;" with user: root and password: root on host: mysql-s1 and port: 3306 should be
    """
    <?xml version="1.0"?>

    <resultset statement="show replica status" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"></resultset>
    """
    # Then result of query: "show master status;" with user: root and password: root on host: mysql-s2 and port: 3306 should be
    # """
    # """
    
    # Then result of query: "show replica status;" with user: root and password: root on host: mysql-s1 and port: 3306 should be
    # """
    # """
    
    # Then result of query: "show master status;" with user: root and password: root on host: mysql-s1 and port: 3306 should be
    # """
    # """


  Scenario: test migration to cluster with one server and promotion with different password and user in remote 
    Given setup etcd with name etcd and image: quay.hamdocker.ir/coreos/etcd:v3.5.9-amd64
    And setup user root with password: password for etcd
    And setup user mm for etcd with password: password access to path mm/cluster1/
    And setup default mysql with server_id 1 and image: hub.hamdocker.ir/library/mysql:8.0.35-bullseye
    And setup default mysql with server_id 3 and name remote and image: hub.hamdocker.ir/library/mysql:8.0.35-bullseye
    And execute mysql query with user: root, password: root, host: remote and port: 3306 query: create user 'su_remote'@'%' identified with mysql_native_password by 'su_remote_password'; grant all on *.* to 'su_remote'@'%'; flush privileges;
    And execute mysql query with user: root, password: root, host: remote and port: 3306 query: create database remotedb; use remotedb; CREATE TABLE t1 (c1 INT PRIMARY KEY, c2 TEXT NOT NULL);INSERT INTO t1 VALUES (120, 'Remoters');
    And execute mysql query with user: root, password: root, host: remote and port: 3306 query: use mysql; INSTALL PLUGIN clone SONAME 'mysql_clone.so';
    And setup mysql_manager with remote(remote, su_remote, su_remote_password, 3306) with name mm with env ETCD_HOST=etcd ETCD_USERNAME=mm ETCD_PASSWORD=password ETCD_PREFIX=mm/cluster1/
    And setup haproxy with name hap1 with env ETCD_HOST=http://etcd:2379 ETCD_USERNAME=mm ETCD_PASSWORD=password ETCD_PREFIX=mm/cluster1/
    And setup haproxy with name hap2 with env ETCD_HOST=http://etcd:2379 ETCD_USERNAME=mm ETCD_PASSWORD=password ETCD_PREFIX=mm/cluster1/
    And init mysql cluster spec standby of remote mysql
    And sleep 30 seconds
    ## testing clone
    Then cluster status must be
    """
    source=replicating_remote
    replica=down

    """
    And result of query: "select * from remotedb.t1;" with user: root and password: root on host: mysql-s1 and port: 3306 should be
    """
    <?xml version="1.0"?>

    <resultset statement="select * from remotedb.t1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <row>
	    <field name="c1">120</field>
	    <field name="c2">Remoters</field>
      </row>
    </resultset>
    """
    ## testing replication
    Given execute mysql query with user: root, password: root, host: remote and port: 3306 query: use remotedb; INSERT INTO t1 VALUES (121, 'RemoteLuis');
    And sleep 5 seconds
    Then result of query: "select * from remotedb.t1;" with user: root and password: root on host: mysql-s1 and port: 3306 should be
    """
    <?xml version="1.0"?>

    <resultset statement="select * from remotedb.t1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <row>
	    <field name="c1">120</field>
	    <field name="c2">Remoters</field>
      </row>
      <row>
	    <field name="c1">121</field>
	    <field name="c2">RemoteLuis</field>
      </row>
    </resultset>
    """

    And result of query: "select HOST from performance_schema.replication_connection_configuration;" with user: root and password: root on host: mysql-s1 and port: 3306 should be
    """
    <?xml version="1.0"?>

    <resultset statement="select HOST from performance_schema.replication_connection_configuration" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <row>
	    <field name="HOST">remote</field>
      </row>
    </resultset>
    """

    ## test promotion
    Given promote mysql cluster 
    And sleep 30 seconds
    Then cluster status must be
    """
    source=up
    replica=down
    
    """
    And result of query: "show replica status;" with user: root and password: root on host: mysql-s1 and port: 3306 should be
    """
    <?xml version="1.0"?>

    <resultset statement="show replica status" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"></resultset>
    """
    And result of query: "SELECT user FROM mysql.user;" with user: root and password: root on host: mysql-s1 and port: 3306 should be
    """
    <?xml version="1.0"?>

    <resultset statement="SELECT user FROM mysql.user" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <row>
	    <field name="user">exporter</field>
      </row>

      <row>
	    <field name="user">hamadmin</field>
      </row>

      <row>
	    <field name="user">replica</field>
      </row>

      <row>
	    <field name="user">root</field>
      </row>

      <row>
	    <field name="user">su_remote</field>
      </row>

      <row>
	    <field name="user">mysql.infoschema</field>
      </row>

      <row>
	    <field name="user">mysql.session</field>
      </row>

      <row>
	    <field name="user">mysql.sys</field>
      </row>

      <row>
	    <field name="user">root</field>
      </row>
    </resultset>
    """

    Then result of query: "show grants for hamadmin;" with user: root and password: root on host: mysql-s1 and port: 3306 should be
    """
    <?xml version="1.0"?>

    <resultset statement="show grants for hamadmin" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <row>
	    <field name="Grants for hamadmin@%">GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, RELOAD, PROCESS, REFERENCES, INDEX, ALTER, SHOW DATABASES, CREATE TEMPORARY TABLES, LOCK TABLES, EXECUTE, REPLICATION SLAVE, REPLICATION CLIENT, CREATE VIEW, SHOW VIEW, CREATE ROUTINE, EVENT, TRIGGER ON *.* TO `hamadmin`@`%`</field>
      </row>
    </resultset>
    """

    Then result of query: "show databases;" with user: root and password: root on host: mysql-s1 and port: 3306 should be
    """
    <?xml version="1.0"?>

    <resultset statement="show databases" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <row>
	    <field name="Database">hamdb</field>
      </row>

      <row>
	    <field name="Database">information_schema</field>
      </row>

      <row>
	    <field name="Database">mysql</field>
      </row>

      <row>
	    <field name="Database">performance_schema</field>
      </row>

      <row>
	    <field name="Database">remotedb</field>
      </row>

      <row>
	    <field name="Database">sys</field>
      </row>

      <row>
	    <field name="Database">test</field>
      </row>
    </resultset>
    """

    Given restart mysql manager with env ETCD_HOST=etcd ETCD_USERNAME=mm ETCD_PASSWORD=password ETCD_PREFIX=mm/cluster1/
    And sleep 30 seconds
    Then cluster status must be
    """
    source=up
    replica=down
    
    """
    And result of query: "show replica status;" with user: root and password: root on host: mysql-s1 and port: 3306 should be
    """
    <?xml version="1.0"?>

    <resultset statement="show replica status" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"></resultset>
    """
    # Then result of query: "show master status;" with user: root and password: root on host: mysql-s2 and port: 3306 should be
    # """
    # """
    
    # Then result of query: "show replica status;" with user: root and password: root on host: mysql-s1 and port: 3306 should be
    # """
    # """
    
    # Then result of query: "show master status;" with user: root and password: root on host: mysql-s1 and port: 3306 should be
    # """
    # """
    

  Scenario: test migration to cluster with one server and promotion with different password and root user in remote 
    Given setup etcd with name etcd and image: quay.hamdocker.ir/coreos/etcd:v3.5.9-amd64
    And setup user root with password: password for etcd
    And setup user mm for etcd with password: password access to path mm/cluster1/
    And setup default mysql with server_id 1 and image: hub.hamdocker.ir/library/mysql:8.0.35-bullseye
    And setup default mysql with server_id 3 and name remote and image: hub.hamdocker.ir/library/mysql:8.0.35-bullseye
    And execute mysql query with user: root, password: root, host: remote and port: 3306 query: alter user 'root'@'%' identified by 'password'; alter user 'root'@'localhost' identified by 'password'; flush privileges;
    And execute mysql query with user: root, password: password, host: remote and port: 3306 query: create database remotedb; use remotedb; CREATE TABLE t1 (c1 INT PRIMARY KEY, c2 TEXT NOT NULL);INSERT INTO t1 VALUES (120, 'Remoters');
    And execute mysql query with user: root, password: password, host: remote and port: 3306 query: use mysql; INSTALL PLUGIN clone SONAME 'mysql_clone.so';
    And setup mysql_manager with remote(remote, root, password, 3306) with name mm with env ETCD_HOST=etcd ETCD_USERNAME=mm ETCD_PASSWORD=password ETCD_PREFIX=mm/cluster1/
    And setup haproxy with name hap1 with env ETCD_HOST=http://etcd:2379 ETCD_USERNAME=mm ETCD_PASSWORD=password ETCD_PREFIX=mm/cluster1/
    And setup haproxy with name hap2 with env ETCD_HOST=http://etcd:2379 ETCD_USERNAME=mm ETCD_PASSWORD=password ETCD_PREFIX=mm/cluster1/
    And init mysql cluster spec standby of remote mysql
    And sleep 50 seconds
    ## testing clone
    Then cluster status must be
    """
    source=replicating_remote
    replica=down

    """
    Then result of query: "select * from remotedb.t1;" with user: root and password: root on host: mysql-s1 and port: 3306 should be
    """
    <?xml version="1.0"?>

    <resultset statement="select * from remotedb.t1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <row>
	    <field name="c1">120</field>
	    <field name="c2">Remoters</field>
      </row>
    </resultset>
    """
    ## testing replication
    Given execute mysql query with user: root, password: password, host: remote and port: 3306 query: use remotedb; INSERT INTO t1 VALUES (121, 'RemoteLuis');
    And sleep 5 seconds
    Then result of query: "select * from remotedb.t1;" with user: root and password: root on host: mysql-s1 and port: 3306 should be
    """
    <?xml version="1.0"?>

    <resultset statement="select * from remotedb.t1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <row>
	    <field name="c1">120</field>
	    <field name="c2">Remoters</field>
      </row>
      <row>
	    <field name="c1">121</field>
	    <field name="c2">RemoteLuis</field>
      </row>
    </resultset>
    """

    And result of query: "select HOST from performance_schema.replication_connection_configuration;" with user: root and password: root on host: mysql-s1 and port: 3306 should be
    """
    <?xml version="1.0"?>

    <resultset statement="select HOST from performance_schema.replication_connection_configuration" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <row>
	    <field name="HOST">remote</field>
      </row>
    </resultset>
    """

    ## test promotion
    Given promote mysql cluster 
    And sleep 30 seconds
    Then cluster status must be
    """
    source=up
    replica=down
    
    """
    And result of query: "show replica status;" with user: root and password: root on host: mysql-s1 and port: 3306 should be
    """
    <?xml version="1.0"?>

    <resultset statement="show replica status" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"></resultset>
    """
    And result of query: "SELECT user FROM mysql.user;" with user: root and password: root on host: mysql-s1 and port: 3306 should be
    """
    <?xml version="1.0"?>

    <resultset statement="SELECT user FROM mysql.user" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <row>
	    <field name="user">exporter</field>
      </row>

      <row>
	    <field name="user">hamadmin</field>
      </row>

      <row>
	    <field name="user">replica</field>
      </row>

      <row>
	    <field name="user">root</field>
      </row>

      <row>
	    <field name="user">mysql.infoschema</field>
      </row>

      <row>
	    <field name="user">mysql.session</field>
      </row>

      <row>
	    <field name="user">mysql.sys</field>
      </row>

      <row>
	    <field name="user">root</field>
      </row>
    </resultset>
    """

    Then result of query: "show grants for hamadmin;" with user: root and password: root on host: mysql-s1 and port: 3306 should be
    """
    <?xml version="1.0"?>

    <resultset statement="show grants for hamadmin" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <row>
	    <field name="Grants for hamadmin@%">GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, RELOAD, PROCESS, REFERENCES, INDEX, ALTER, SHOW DATABASES, CREATE TEMPORARY TABLES, LOCK TABLES, EXECUTE, REPLICATION SLAVE, REPLICATION CLIENT, CREATE VIEW, SHOW VIEW, CREATE ROUTINE, EVENT, TRIGGER ON *.* TO `hamadmin`@`%`</field>
      </row>
    </resultset>
    """

    Then result of query: "show databases;" with user: root and password: root on host: mysql-s1 and port: 3306 should be
    """
    <?xml version="1.0"?>

    <resultset statement="show databases" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <row>
	    <field name="Database">hamdb</field>
      </row>

      <row>
	    <field name="Database">information_schema</field>
      </row>

      <row>
	    <field name="Database">mysql</field>
      </row>

      <row>
	    <field name="Database">performance_schema</field>
      </row>

      <row>
	    <field name="Database">remotedb</field>
      </row>

      <row>
	    <field name="Database">sys</field>
      </row>

      <row>
	    <field name="Database">test</field>
      </row>
    </resultset>
    """

    Given restart mysql manager with env ETCD_HOST=etcd ETCD_USERNAME=mm ETCD_PASSWORD=password ETCD_PREFIX=mm/cluster1/
    And sleep 30 seconds
    Then cluster status must be
    """
    source=up
    replica=down
    
    """
    And result of query: "show replica status;" with user: root and password: root on host: mysql-s1 and port: 3306 should be
    """
    <?xml version="1.0"?>

    <resultset statement="show replica status" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"></resultset>
    """
    # Then result of query: "show master status;" with user: root and password: root on host: mysql-s2 and port: 3306 should be
    # """
    # """
    
    # Then result of query: "show replica status;" with user: root and password: root on host: mysql-s1 and port: 3306 should be
    # """
    # """
    
    # Then result of query: "show master status;" with user: root and password: root on host: mysql-s1 and port: 3306 should be
    # """
    # """

