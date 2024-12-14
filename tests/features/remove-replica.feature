Feature: two-mysqls-and-two-haproxies
  Setup two mysqls and two haproxies with mm

  Scenario: check start two mysqls with two haproxies
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
    Then cluster status must be
    """
    source=up
    replica=up

    """
    Given remove mysql with name: s2
    And sleep 50 seconds
    Then cluster status must be
    """
    source=up
    replica=down

    """
