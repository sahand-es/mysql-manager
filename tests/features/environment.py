import os
from testcontainers.core.image import DockerImage
from tests.integration_test.environment.test_environment_factory import TestEnvironmentFactory

def before_all(context):
    context.mysql_manager_image = os.getenv("MYSQL_MANAGER_IMAGE", "mysql-manager:latest")
    context.haproxy_image = os.getenv("HAPROXY_IMAGE", "mm-haproxy:latest")
    context.mysql_image = os.getenv("MYSQL_IMAGE", "hub.hamdocker.ir/library/mysql:8.0.35-bullseye")
    if os.getenv("BUILD_IMAGE", "false") == "true":
        DockerImage(path=".", tag=context.mysql_manager_image).build()

def before_scenario(context, scenario):
    context.test_env = TestEnvironmentFactory()

def after_scenario(context, scenario):
    context.test_env.stop()
