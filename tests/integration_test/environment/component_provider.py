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
        component_kwargs: dict = {},
        is_up: bool = True
    ) -> None:
        self.name = name
        self.image = image
        self.network = network
        self.component = component(image, **component_kwargs)
        self.is_up = is_up

    def setup(self) -> None:
        self.component.with_name(
            self.name
        ).with_network(
            self.network
        ).with_network_aliases(
            self.name
        ).with_kwargs(
            restart_policy={"Name": "always"}
        )

    def start(self):
        self.is_up = True
        self.component.start()

    def destroy(self):
        self.is_up = False
        self.component.stop()

    def exec(self, command):
        return self.component.exec(command)

    def set_env(self, envs: dict):
        for key, value in envs.items():
            self.component.with_env(key, value) 

