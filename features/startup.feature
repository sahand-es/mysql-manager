Feature: startup
  We should check that startup the database and its components.

  Scenario: check start one mysql with one proxysql
    Given setup default proxysql with name: proxysql and image: hub.hamdocker.ir/proxysql/proxysql:2.6.2
    AND setup default mysql with server_id 1 and image: hub.hamdocker.ir/library/mysql:8.0.35-bullseye
    AND setup mysql_manager with name mm
    When execute mysql query with user: hamadmin, password: password, host: proxysql query: use hamdb; CREATE TABLE t1 (c1 INT PRIMARY KEY, c2 TEXT NOT NULL);INSERT INTO t1 VALUES (1, 'Luis');
    Then result of query: "select * from hamdb.t1;" with user: hamadmin and password: password on host: proxysql should be "c1 c2 1 Luis "
    AND result of query: "select * from hamdb.t1;" with user: root and password: root on host: mysql-s1 should be "c1 c2 1 Luis "

