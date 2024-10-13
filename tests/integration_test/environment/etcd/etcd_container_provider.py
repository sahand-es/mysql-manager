import os
from testcontainers.core.container import Network
from testcontainers.mysql import MySqlContainer
from tests.integration_test.environment.component_provider import ComponentProvider
from testcontainers.core.generic import DockerContainer


class EtcdContainerProvider(ComponentProvider):
    def __init__(self,
        name: str,
        network: Network,
        image: str, 
    ) -> None:
        super().__init__(
            name=name,
            network=network,
            image=image,
            component=DockerContainer,
        )
    
    def setup(self):
        super().setup()
        self.component.with_command(
            [
                "etcd",
                "--name=mm-etcd",
                f"--advertise-client-urls=http://{self.name}:2379",
                "--initial-cluster-token=etcd-cluster",
                "--initial-cluster-state=new",
                "--listen-client-urls=http://0.0.0.0:2379",
                "--listen-metrics-urls=http://0.0.0.0:2381",
                "--listen-peer-urls=http://0.0.0.0:2380",
                "--auto-compaction-mode=revision",
                "--auto-compaction-retention=5"
            ]
        ).with_exposed_ports(
            2379, 2380, 2381
        )
