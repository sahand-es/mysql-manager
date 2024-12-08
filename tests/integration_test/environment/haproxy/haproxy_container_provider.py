import os
from testcontainers.core.generic import DockerContainer
from testcontainers.core.network import Network
from tests.integration_test.environment.component_provider import ComponentProvider


class HAProxyContainerProvider(ComponentProvider):
    def __init__(self,
        name: str,
        image: str,
        network: Network,
    ) -> None:
        super().__init__(
            name=name,
            network=network,
            image=image,
            component=DockerContainer
        )

    def setup(self):
        super().setup()

