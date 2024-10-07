from typing import Type, Union

from testcontainers.core.container import Network
from testcontainers.core.generic import DockerContainer


class ComponentProvider:
    def __init__(
        self, 
        name:str, 
        network: Network, 
        image: str,
        component: Type[DockerContainer],
        component_kwargs: dict = {}
    ) -> None:
        self.name = name
        self.image = image
        self.network = network
        self.component = component(image, **component_kwargs)

    def setup(self) -> None:
        self.component.with_name(
            self.name
        ).with_network(
            self.network
        ).with_network_aliases(
            self.name
        )

    def start(self):
        self.component.start()

    def destroy(self):
        self.component.stop()

    def exec(self, command):
        return self.component.exec(command)

