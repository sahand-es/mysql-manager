Feature: add replica to cluster
  add one replica to current cluster and check its state

  Scenario: start first mysql and add second replica
    Given setup default proxysql with name: proxysql and image: hub.hamdocker.ir/proxysql/proxysql:2.6.2
	And setup etcd with name etcd and image: quay.hamdocker.ir/coreos/etcd:v3.5.9-amd64
    And setup user root with password: password for etcd
    And setup user mm for etcd with password: password access to path mm/cluster1/
    And setup default mysql with server_id 1 and image: hub.hamdocker.ir/library/mysql:8.0.35-bullseye
    And setup mysql_manager with name mm with env ETCD_HOST=etcd ETCD_USERNAME=mm ETCD_PASSWORD=password ETCD_PREFIX=mm/cluster1/
	And init mysql cluster spec
    And sleep 30 seconds
    When execute mysql query with user: hamadmin, password: password, host: proxysql and port: 3306 query: use hamdb; CREATE TABLE t1 (c1 INT PRIMARY KEY, c2 TEXT NOT NULL);INSERT INTO t1 VALUES (1, 'Luis');
    And execute mysql query with user: root, password: root, host: mysql-s1 and port: 3306 query: flush binary logs;
    And execute mysql query with user: root, password: root, host: mysql-s1 and port: 3306 query: purge binary logs before now();
    And execute mysql query with user: hamadmin, password: password, host: proxysql and port: 3306 query: use hamdb; INSERT INTO hamdb.t1 VALUES (2, 'Hassan');
    And execute mysql query with user: root, password: root, host: mysql-s1 and port: 3306 query: flush binary logs;
    
    Then result of query: "select * from hamdb.t1;" with user: hamadmin and password: password on host: proxysql and port: 3306 should be
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
    Given setup default mysql with server_id 2 and image: hub.hamdocker.ir/library/mysql:8.0.35-bullseye
	And add mysql to cluster with host: mysql-s2 and name: s2 and user: root and password: root
	And sleep 50 seconds
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
    
    # Then result of query: "show replica status;" with user: root and password: root on host: mysql-s2 and port: 3306 should be
    # """
    # <?xml version="1.0"?>
    #
    # <resultset statement="show replica status" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
    #   <row>
	   #  <field name="Replica_IO_State">Waiting for source to send event</field>
	   #  <field name="Source_Host">mysql-s1</field>
	   #  <field name="Source_User">replica</field>
	   #  <field name="Source_Port">3306</field>
	   #  <field name="Connect_Retry">1</field>
	   #  <field name="Source_Log_File">binlog.000006</field>
	   #  <field name="Read_Source_Log_Pos">197</field>
	   #  <field name="Relay_Log_File">relaylog.000002</field>
	   #  <field name="Relay_Log_Pos">367</field>
	   #  <field name="Relay_Source_Log_File">binlog.000006</field>
	   #  <field name="Replica_IO_Running">Yes</field>
	   #  <field name="Replica_SQL_Running">Yes</field>
	   #  <field name="Replicate_Do_DB"></field>
	   #  <field name="Replicate_Ignore_DB"></field>
	   #  <field name="Replicate_Do_Table"></field>
	   #  <field name="Replicate_Ignore_Table"></field>
	   #  <field name="Replicate_Wild_Do_Table"></field>
	   #  <field name="Replicate_Wild_Ignore_Table"></field>
	   #  <field name="Last_Errno">0</field>
	   #  <field name="Last_Error"></field>
	   #  <field name="Skip_Counter">0</field>
	   #  <field name="Exec_Source_Log_Pos">197</field>
	   #  <field name="Relay_Log_Space">570</field>
	   #  <field name="Until_Condition">None</field>
	   #  <field name="Until_Log_File"></field>
	   #  <field name="Until_Log_Pos">0</field>
	   #  <field name="Source_SSL_Allowed">No</field>
	   #  <field name="Source_SSL_CA_File"></field>
	   #  <field name="Source_SSL_CA_Path"></field>
	   #  <field name="Source_SSL_Cert"></field>
	   #  <field name="Source_SSL_Cipher"></field>
	   #  <field name="Source_SSL_Key"></field>
	   #  <field name="Seconds_Behind_Source">0</field>
	   #  <field name="Source_SSL_Verify_Server_Cert">No</field>
	   #  <field name="Last_IO_Errno">0</field>
	   #  <field name="Last_IO_Error"></field>
	   #  <field name="Last_SQL_Errno">0</field>
	   #  <field name="Last_SQL_Error"></field>
	   #  <field name="Replicate_Ignore_Server_Ids"></field>
	   #  <field name="Source_Server_Id">1</field>
	   #  <field name="Source_UUID">d1bfd4e1-855a-11ef-901e-0242c0a86003</field>
	   #  <field name="Source_Info_File">mysql.slave_master_info</field>
	   #  <field name="SQL_Delay">0</field>
	   #  <field name="SQL_Remaining_Delay" xsi:nil="true" />
	   #  <field name="Replica_SQL_Running_State">Replica has read all relay log; waiting for more updates</field>
	   #  <field name="Source_Retry_Count">10</field>
	   #  <field name="Source_Bind"></field>
	   #  <field name="Last_IO_Error_Timestamp"></field>
	   #  <field name="Last_SQL_Error_Timestamp"></field>
	   #  <field name="Source_SSL_Crl"></field>
	   #  <field name="Source_SSL_Crlpath"></field>
	   #  <field name="Retrieved_Gtid_Set"></field>
	   #  <field name="Executed_Gtid_Set">d1bfd4e1-855a-11ef-901e-0242c0a86003:1-28</field>
	   #  <field name="Auto_Position">1</field>
	   #  <field name="Replicate_Rewrite_DB"></field>
	   #  <field name="Channel_Name"></field>
	   #  <field name="Source_TLS_Version"></field>
	   #  <field name="Source_public_key_path"></field>
	   #  <field name="Get_Source_public_key">0</field>
	   #  <field name="Network_Namespace"></field>
    #   </row>
    # </resultset>
    # """

    Then result of query: "select * from runtime_mysql_servers;" with user: radmin and password: pwd on host: proxysql and port: 6032 should be
    """
    <?xml version="1.0"?>

    <resultset statement="select * from runtime_mysql_servers" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <row>
	    <field name="hostgroup_id">0</field>
	    <field name="hostname">mysql-s1</field>
	    <field name="port">3306</field>
	    <field name="gtid_port">0</field>
	    <field name="status">ONLINE</field>
	    <field name="weight">1</field>
	    <field name="compression">0</field>
	    <field name="max_connections">1000</field>
	    <field name="max_replication_lag">0</field>
	    <field name="use_ssl">0</field>
	    <field name="max_latency_ms">0</field>
	    <field name="comment"></field>
      </row>

      <row>
	    <field name="hostgroup_id">1</field>
	    <field name="hostname">mysql-s1</field>
	    <field name="port">3306</field>
	    <field name="gtid_port">0</field>
	    <field name="status">ONLINE</field>
	    <field name="weight">1</field>
	    <field name="compression">0</field>
	    <field name="max_connections">1000</field>
	    <field name="max_replication_lag">0</field>
	    <field name="use_ssl">0</field>
	    <field name="max_latency_ms">0</field>
	    <field name="comment"></field>
      </row>

      <row>
	    <field name="hostgroup_id">1</field>
	    <field name="hostname">mysql-s2</field>
	    <field name="port">3306</field>
	    <field name="gtid_port">0</field>
	    <field name="status">ONLINE</field>
	    <field name="weight">1</field>
	    <field name="compression">0</field>
	    <field name="max_connections">1000</field>
	    <field name="max_replication_lag">0</field>
	    <field name="use_ssl">0</field>
	    <field name="max_latency_ms">0</field>
	    <field name="comment"></field>
      </row>
    </resultset>
    """
