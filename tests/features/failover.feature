Feature: test failover
  setup 2 nodes, kill master and check failover, after that restart previous master and it should join the cluster as a replica node

## TODO: check read only values on servers
  Scenario: start first mysql and add second replica
    Given setup etcd with name etcd and image: quay.hamdocker.ir/coreos/etcd:v3.5.9-amd64
    And setup user root with password: password for etcd
    And setup user mm for etcd with password: password access to path mm/cluster1/
    And setup default mysql with server_id 1 and image: hub.hamdocker.ir/library/mysql:8.0.35-bullseye
    And setup default mysql with server_id 2 and image: hub.hamdocker.ir/library/mysql:8.0.35-bullseye
    And setup mysql_manager with name mm with env ETCD_HOST=etcd ETCD_USERNAME=mm ETCD_PASSWORD=password ETCD_PREFIX=mm/cluster1/
    And setup haproxy with name hap1 with env ETCD_HOST=http://etcd:2379 ETCD_USERNAME=mm ETCD_PASSWORD=password ETCD_PREFIX=mm/cluster1/
    And setup haproxy with name hap2 with env ETCD_HOST=http://etcd:2379 ETCD_USERNAME=mm ETCD_PASSWORD=password ETCD_PREFIX=mm/cluster1/
    And init mysql cluster spec
    And sleep 50 seconds
    When execute mysql query with user: hamadmin, password: password, host: hap1 and port: 3306 query: use hamdb; CREATE TABLE t1 (c1 INT PRIMARY KEY, c2 TEXT NOT NULL);INSERT INTO t1 VALUES (1, 'Luis');
    Given stop mysql with server_id 1
    And sleep 40 seconds
    Then cluster status must be
    """
    source=up
    replica=down

    """
    Then result of query: "show replica status;" with user: root and password: root on host: mysql-s2 and port: 3306 should be
    """
    <?xml version="1.0"?>

    <resultset statement="show replica status" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"></resultset>
    """

    # Then result of query: "show master status;" with user: root and password: root on host: mysql-s2 and port: 3306 should be
    # """
    # """
    
    Then result of query: "select * from hamdb.t1;" with user: hamadmin and password: password on host: hap1 and port: 3306 should be
    """
    <?xml version="1.0"?>

    <resultset statement="select * from hamdb.t1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <row>
	    <field name="c1">1</field>
	    <field name="c2">Luis</field>
      </row>
    </resultset>
    """

    Then result of query: "select * from hamdb.t1;" with user: hamadmin and password: password on host: hap2 and port: 3306 should be
    """
    <?xml version="1.0"?>

    <resultset statement="select * from hamdb.t1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <row>
	    <field name="c1">1</field>
	    <field name="c2">Luis</field>
      </row>
    </resultset>
    """

    Then result of query: "SELECT user FROM mysql.user;" with user: root and password: root on host: mysql-s2 and port: 3306 should be
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
    
    Then result of query: "show grants for hamadmin;" with user: root and password: root on host: mysql-s2 and port: 3306 should be
    """
    <?xml version="1.0"?>

    <resultset statement="show grants for hamadmin" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <row>
	    <field name="Grants for hamadmin@%">GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, RELOAD, PROCESS, REFERENCES, INDEX, ALTER, SHOW DATABASES, CREATE TEMPORARY TABLES, LOCK TABLES, EXECUTE, REPLICATION SLAVE, REPLICATION CLIENT, CREATE VIEW, SHOW VIEW, CREATE ROUTINE, EVENT, TRIGGER ON *.* TO `hamadmin`@`%`</field>
      </row>
    </resultset>
    """

    Then result of query: "show databases;" with user: root and password: root on host: mysql-s2 and port: 3306 should be
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
	    <field name="Database">sys</field>
      </row>

      <row>
	    <field name="Database">test</field>
      </row>
    </resultset>
    """
    
    Given start mysql with server_id 1
    Given sleep 30 seconds
    Then cluster status must be
    """
    source=up
    replica=up

    """
    When execute mysql query with user: hamadmin, password: password, host: hap2 and port: 3306 query: INSERT INTO hamdb.t1 VALUES (2, 'Hassan');
    Then result of query: "show replica status;" with user: root and password: root on host: mysql-s2 and port: 3306 should be
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
    
    Then result of query: "select * from hamdb.t1;" with user: hamadmin and password: password on host: hap1 and port: 3306 should be
    """
    <?xml version="1.0"?>

    <resultset statement="select * from hamdb.t1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <row>
	    <field name="c1">1</field>
	    <field name="c2">Luis</field>
      </row>
      <row>
	    <field name="c1">2</field>
	    <field name="c2">Hassan</field>
      </row>
    </resultset>
    """
    
    Then result of query: "select * from hamdb.t1;" with user: hamadmin and password: password on host: hap2 and port: 3306 should be
    """
    <?xml version="1.0"?>

    <resultset statement="select * from hamdb.t1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <row>
	    <field name="c1">1</field>
	    <field name="c2">Luis</field>
      </row>
      <row>
	    <field name="c1">2</field>
	    <field name="c2">Hassan</field>
      </row>
    </resultset>
    """
    
    Then result of query: "select * from hamdb.t1;" with user: root and password: root on host: mysql-s1 and port: 3306 should be
    """
    <?xml version="1.0"?>

    <resultset statement="select * from hamdb.t1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <row>
	    <field name="c1">1</field>
	    <field name="c2">Luis</field>
      </row>
      <row>
	    <field name="c1">2</field>
	    <field name="c2">Hassan</field>
      </row>
    </resultset>
    """
    
    Then result of query: "select * from hamdb.t1;" with user: root and password: root on host: mysql-s2 and port: 3306 should be
    """
    <?xml version="1.0"?>

    <resultset statement="select * from hamdb.t1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <row>
	    <field name="c1">1</field>
	    <field name="c2">Luis</field>
      </row>
      <row>
	    <field name="c1">2</field>
	    <field name="c2">Hassan</field>
      </row>
    </resultset>
    """

    Given restart mysql manager with env ETCD_HOST=etcd ETCD_USERNAME=mm ETCD_PASSWORD=password ETCD_PREFIX=mm/cluster1/
    And sleep 20 seconds
    Then cluster status must be
    """
    source=up
    replica=up

    """
    Then result of query: "show replica status;" with user: root and password: root on host: mysql-s2 and port: 3306 should be
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
