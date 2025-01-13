Feature: test migrate remote
  setup cluster nodes, setup another mysql, add data to it, migrate its data to mysql manager cluster and promote cluster 
  Scenario: test migration to cluster with two servers and promotion
    Given setup etcd with name etcd and image: quay.hamdocker.ir/coreos/etcd:v3.5.9-amd64
    And setup user root with password: password for etcd
    And setup user mm for etcd with password: password access to path mm/cluster1/
    And setup default mysql with server_id 1
    And setup default mysql with server_id 2
    And setup default mysql with server_id 3 and name remote
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
	    <field name="Grants for hamadmin@%">GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, RELOAD, SHUTDOWN, PROCESS, FILE, REFERENCES, INDEX, ALTER, SHOW DATABASES, CREATE TEMPORARY TABLES, LOCK TABLES, EXECUTE, REPLICATION SLAVE, REPLICATION CLIENT, CREATE VIEW, SHOW VIEW, CREATE ROUTINE, ALTER ROUTINE, CREATE USER, EVENT, TRIGGER, CREATE TABLESPACE, CREATE ROLE, DROP ROLE ON *.* TO `hamadmin`@`%` WITH GRANT OPTION</field>
      </row>
    
      <row>
	    <field name="Grants for hamadmin@%">GRANT APPLICATION_PASSWORD_ADMIN,AUDIT_ABORT_EXEMPT,AUDIT_ADMIN,AUTHENTICATION_POLICY_ADMIN,BACKUP_ADMIN,BINLOG_ADMIN,BINLOG_ENCRYPTION_ADMIN,CLONE_ADMIN,ENCRYPTION_KEY_ADMIN,FIREWALL_EXEMPT,FLUSH_OPTIMIZER_COSTS,FLUSH_STATUS,FLUSH_TABLES,FLUSH_USER_RESOURCES,GROUP_REPLICATION_ADMIN,GROUP_REPLICATION_STREAM,INNODB_REDO_LOG_ARCHIVE,INNODB_REDO_LOG_ENABLE,PASSWORDLESS_USER_ADMIN,PERSIST_RO_VARIABLES_ADMIN,REPLICATION_APPLIER,RESOURCE_GROUP_ADMIN,RESOURCE_GROUP_USER,ROLE_ADMIN,SENSITIVE_VARIABLES_OBSERVER,SERVICE_CONNECTION_ADMIN,SESSION_VARIABLES_ADMIN,SET_USER_ID,SHOW_ROUTINE,SYSTEM_USER,SYSTEM_VARIABLES_ADMIN,TABLE_ENCRYPTION_ADMIN,TELEMETRY_LOG_ADMIN,XA_RECOVER_ADMIN ON *.* TO `hamadmin`@`%` WITH GRANT OPTION</field>
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
    And setup default mysql with server_id 1
    And setup default mysql with server_id 3 and name remote
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
	    <field name="Grants for hamadmin@%">GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, RELOAD, SHUTDOWN, PROCESS, FILE, REFERENCES, INDEX, ALTER, SHOW DATABASES, CREATE TEMPORARY TABLES, LOCK TABLES, EXECUTE, REPLICATION SLAVE, REPLICATION CLIENT, CREATE VIEW, SHOW VIEW, CREATE ROUTINE, ALTER ROUTINE, CREATE USER, EVENT, TRIGGER, CREATE TABLESPACE, CREATE ROLE, DROP ROLE ON *.* TO `hamadmin`@`%` WITH GRANT OPTION</field>
      </row>
    
      <row>
	    <field name="Grants for hamadmin@%">GRANT APPLICATION_PASSWORD_ADMIN,AUDIT_ABORT_EXEMPT,AUDIT_ADMIN,AUTHENTICATION_POLICY_ADMIN,BACKUP_ADMIN,BINLOG_ADMIN,BINLOG_ENCRYPTION_ADMIN,CLONE_ADMIN,ENCRYPTION_KEY_ADMIN,FIREWALL_EXEMPT,FLUSH_OPTIMIZER_COSTS,FLUSH_STATUS,FLUSH_TABLES,FLUSH_USER_RESOURCES,GROUP_REPLICATION_ADMIN,GROUP_REPLICATION_STREAM,INNODB_REDO_LOG_ARCHIVE,INNODB_REDO_LOG_ENABLE,PASSWORDLESS_USER_ADMIN,PERSIST_RO_VARIABLES_ADMIN,REPLICATION_APPLIER,RESOURCE_GROUP_ADMIN,RESOURCE_GROUP_USER,ROLE_ADMIN,SENSITIVE_VARIABLES_OBSERVER,SERVICE_CONNECTION_ADMIN,SESSION_VARIABLES_ADMIN,SET_USER_ID,SHOW_ROUTINE,SYSTEM_USER,SYSTEM_VARIABLES_ADMIN,TABLE_ENCRYPTION_ADMIN,TELEMETRY_LOG_ADMIN,XA_RECOVER_ADMIN ON *.* TO `hamadmin`@`%` WITH GRANT OPTION</field>
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
    And setup default mysql with server_id 1
    And setup default mysql with server_id 3 and name remote
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
	    <field name="Grants for hamadmin@%">GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, RELOAD, SHUTDOWN, PROCESS, FILE, REFERENCES, INDEX, ALTER, SHOW DATABASES, CREATE TEMPORARY TABLES, LOCK TABLES, EXECUTE, REPLICATION SLAVE, REPLICATION CLIENT, CREATE VIEW, SHOW VIEW, CREATE ROUTINE, ALTER ROUTINE, CREATE USER, EVENT, TRIGGER, CREATE TABLESPACE, CREATE ROLE, DROP ROLE ON *.* TO `hamadmin`@`%` WITH GRANT OPTION</field>
      </row>
    
      <row>
	    <field name="Grants for hamadmin@%">GRANT APPLICATION_PASSWORD_ADMIN,AUDIT_ABORT_EXEMPT,AUDIT_ADMIN,AUTHENTICATION_POLICY_ADMIN,BACKUP_ADMIN,BINLOG_ADMIN,BINLOG_ENCRYPTION_ADMIN,CLONE_ADMIN,ENCRYPTION_KEY_ADMIN,FIREWALL_EXEMPT,FLUSH_OPTIMIZER_COSTS,FLUSH_STATUS,FLUSH_TABLES,FLUSH_USER_RESOURCES,GROUP_REPLICATION_ADMIN,GROUP_REPLICATION_STREAM,INNODB_REDO_LOG_ARCHIVE,INNODB_REDO_LOG_ENABLE,PASSWORDLESS_USER_ADMIN,PERSIST_RO_VARIABLES_ADMIN,REPLICATION_APPLIER,RESOURCE_GROUP_ADMIN,RESOURCE_GROUP_USER,ROLE_ADMIN,SENSITIVE_VARIABLES_OBSERVER,SERVICE_CONNECTION_ADMIN,SESSION_VARIABLES_ADMIN,SET_USER_ID,SHOW_ROUTINE,SYSTEM_USER,SYSTEM_VARIABLES_ADMIN,TABLE_ENCRYPTION_ADMIN,TELEMETRY_LOG_ADMIN,XA_RECOVER_ADMIN ON *.* TO `hamadmin`@`%` WITH GRANT OPTION</field>
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
    And setup default mysql with server_id 1
    And setup default mysql with server_id 3 and name remote
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
	    <field name="Grants for hamadmin@%">GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, RELOAD, SHUTDOWN, PROCESS, FILE, REFERENCES, INDEX, ALTER, SHOW DATABASES, CREATE TEMPORARY TABLES, LOCK TABLES, EXECUTE, REPLICATION SLAVE, REPLICATION CLIENT, CREATE VIEW, SHOW VIEW, CREATE ROUTINE, ALTER ROUTINE, CREATE USER, EVENT, TRIGGER, CREATE TABLESPACE, CREATE ROLE, DROP ROLE ON *.* TO `hamadmin`@`%` WITH GRANT OPTION</field>
      </row>
    
      <row>
	    <field name="Grants for hamadmin@%">GRANT APPLICATION_PASSWORD_ADMIN,AUDIT_ABORT_EXEMPT,AUDIT_ADMIN,AUTHENTICATION_POLICY_ADMIN,BACKUP_ADMIN,BINLOG_ADMIN,BINLOG_ENCRYPTION_ADMIN,CLONE_ADMIN,ENCRYPTION_KEY_ADMIN,FIREWALL_EXEMPT,FLUSH_OPTIMIZER_COSTS,FLUSH_STATUS,FLUSH_TABLES,FLUSH_USER_RESOURCES,GROUP_REPLICATION_ADMIN,GROUP_REPLICATION_STREAM,INNODB_REDO_LOG_ARCHIVE,INNODB_REDO_LOG_ENABLE,PASSWORDLESS_USER_ADMIN,PERSIST_RO_VARIABLES_ADMIN,REPLICATION_APPLIER,RESOURCE_GROUP_ADMIN,RESOURCE_GROUP_USER,ROLE_ADMIN,SENSITIVE_VARIABLES_OBSERVER,SERVICE_CONNECTION_ADMIN,SESSION_VARIABLES_ADMIN,SET_USER_ID,SHOW_ROUTINE,SYSTEM_USER,SYSTEM_VARIABLES_ADMIN,TABLE_ENCRYPTION_ADMIN,TELEMETRY_LOG_ADMIN,XA_RECOVER_ADMIN ON *.* TO `hamadmin`@`%` WITH GRANT OPTION</field>
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


  Scenario: test migration to cluster with wrong config (different innodb_page_size)
    Given setup etcd with name etcd and image: quay.hamdocker.ir/coreos/etcd:v3.5.9-amd64
    And setup user root with password: password for etcd
    And setup user mm for etcd with password: password access to path mm/cluster1/
    And setup mysql with config with server_id 1
    """
    [mysqld]
    server-id = 1
    gtid-mode = ON
    enforce-gtid-consistency = ON
    log-bin = binlog
    relay-log = relaylog
    datadir = /var/lib/mysql
    innodb_page_size = 8k
    """
    And setup default mysql with config with server_id 3 and name remote
    """
    [mysqld]
    server-id = 3
    gtid-mode = ON
    enforce-gtid-consistency = ON
    log-bin = binlog
    relay-log = relaylog
    datadir = /var/lib/mysql
    innodb_page_size = 16k
    """
    And execute mysql query with user: root, password: root, host: remote and port: 3306 query: use mysql; INSTALL PLUGIN clone SONAME 'mysql_clone.so';
    And setup mysql_manager with remote(remote, root, root, 3306) with name mm with env ETCD_HOST=etcd ETCD_USERNAME=mm ETCD_PASSWORD=password ETCD_PREFIX=mm/cluster1/
    And init mysql cluster spec standby of remote mysql
    And sleep 20 seconds
    Then logs of mm must contain
    """
    Variable innodb_page_size must be the same in source and remote. Source value = 8192, remote value = 16384
    """
    And cluster status must be
    """
    source=cloning
    replica=down

    """


  Scenario: test migration to cluster with wrong config (max_allowed_packet less than 2M)
    Given setup etcd with name etcd and image: quay.hamdocker.ir/coreos/etcd:v3.5.9-amd64
    And setup user root with password: password for etcd
    And setup user mm for etcd with password: password access to path mm/cluster1/
    And setup mysql with config with server_id 1
    """
    [mysqld]
    server-id = 1
    gtid-mode = ON
    enforce-gtid-consistency = ON
    log-bin = binlog
    relay-log = relaylog
    datadir = /var/lib/mysql
    """
    And setup default mysql with config with server_id 3 and name remote
    """
    [mysqld]
    server-id = 3
    gtid-mode = ON
    enforce-gtid-consistency = ON
    log-bin = binlog
    relay-log = relaylog
    datadir = /var/lib/mysql
    max_allowed_packet = 1M
    """
    And execute mysql query with user: root, password: root, host: remote and port: 3306 query: create database remotedb; use remotedb; CREATE TABLE t1 (c1 INT PRIMARY KEY, c2 TEXT NOT NULL);INSERT INTO t1 VALUES (120, 'Remoters');
    And execute mysql query with user: root, password: root, host: remote and port: 3306 query: use mysql; INSTALL PLUGIN clone SONAME 'mysql_clone.so';
    And setup mysql_manager with remote(remote, root, root, 3306) with name mm with env ETCD_HOST=etcd ETCD_USERNAME=mm ETCD_PASSWORD=password ETCD_PREFIX=mm/cluster1/
    And init mysql cluster spec standby of remote mysql
    And sleep 20 seconds
    Then logs of mm must contain
    """
    Variable max_allowed_packet has wrong value in remote database. It should be more than 2097152 bytes, while current value is 1048576 bytes
    """
    And cluster status must be
    """
    source=cloning
    replica=down

    """
  
  
  Scenario: test migration to cluster with wrong password length (33 characters)
    Given setup etcd with name etcd and image: quay.hamdocker.ir/coreos/etcd:v3.5.9-amd64
    And setup user root with password: password for etcd
    And setup user mm for etcd with password: password access to path mm/cluster1/
    And setup default mysql with server_id 1
    And setup default mysql with server_id 3 and name remote
    And execute mysql query with user: root, password: root, host: remote and port: 3306 query: alter user 'root' identified by 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    And execute mysql query with user: root, password: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa, host: remote and port: 3306 query: use mysql; INSTALL PLUGIN clone SONAME 'mysql_clone.so';
    And setup mysql_manager with remote(remote, root, aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa, 3306) with name mm with env ETCD_HOST=etcd ETCD_USERNAME=mm ETCD_PASSWORD=password ETCD_PREFIX=mm/cluster1/
    And init mysql cluster spec standby of remote mysql
    And sleep 20 seconds
    Then logs of mm must contain
    """
    The length of replication password should be less than 32
    """
    And cluster status must be
    """
    source=cloning
    replica=down

    """
