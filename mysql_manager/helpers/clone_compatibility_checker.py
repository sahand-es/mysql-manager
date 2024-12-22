import logging
from mysql_manager.clone_exceptions import CloneException, PluginsAreNotInstalled, DifferentMysqlVariable, SourceAndReplAreInDifferentSeries, WrongMysqlVariableValue
from mysql_manager.exceptions import VariableIsNotSetInDatabase
from mysql_manager.instance import Mysql
from mysql_manager.enums import PluginStatus

logger = logging.getLogger(__name__)

class CloneCompatibilityChecker:
    MINIMUM_MAX_ALLOWED_PACKET = 2097152
    MUST_BE_THE_SAME_VARIABLES = [
        "innodb_page_size",
        "innodb_data_file_path",
        "character_set_database",
        "collation_database"
    ]

    def __init__(self, src: Mysql, remote: Mysql) -> None:
        self.src = src
        self.remote = remote

    @staticmethod
    def is_same_series(version1: str, version2: str) -> bool:
        """
        Check if two MySQL version strings are in the same series.

        Args:
            version1 (str): The first version string (e.g., "8.4.0").
            version2 (str): The second version string (e.g., "8.4.11").

        Returns:
            bool: True if the versions are in the same series, False otherwise.
        """
        # Split the version strings into major, minor, and patch components
        major1, minor1, _ = version1.split('.')
        major2, minor2, _ = version2.split('.')

        # Compare the major and minor components
        return major1 == major2 and minor1 == minor2

    def check_required_plugins_on_src(self):
        src_active_plugins = self.src.get_plugins(status=PluginStatus.ACTIVE.value)
        remote_active_plugins = self.remote.get_plugins(status=PluginStatus.ACTIVE.value)
        required_plugins_on_src = remote_active_plugins - src_active_plugins
        if required_plugins_on_src:
            raise PluginsAreNotInstalled(
                plugin_names=[
                    plugin.name for plugin in required_plugins_on_src
                ]
            )

    def check_must_be_the_same_variables(self):
        for variable in self.MUST_BE_THE_SAME_VARIABLES:
            value_in_src = self.src.get_variable(variable)
            value_in_remote = self.remote.get_variable(variable)
            if value_in_src != value_in_remote:
                raise DifferentMysqlVariable(
                    variable_name=variable,
                    src_value=value_in_src,
                    repl_value=value_in_remote
                )

    def check_is_same_series(self):
        src_version = self.src.get_variable("version")
        remote_version = self.remote.get_variable("version")
        if not self.is_same_series(src_version, remote_version):
            raise SourceAndReplAreInDifferentSeries(
                src_version=src_version,
                repl_version=remote_version
            )

    def check_max_allowed_packet(self):
        src_max_allowed_packet = int(self.src.get_variable("max_allowed_packet"))
        remote_max_allowed_packet = int(self.remote.get_variable("max_allowed_packet"))
        if src_max_allowed_packet < self.MINIMUM_MAX_ALLOWED_PACKET:
            raise WrongMysqlVariableValue(
                variable_name="max_allowed_packet",
                variable_value=src_max_allowed_packet,
            )
        if remote_max_allowed_packet < self.MINIMUM_MAX_ALLOWED_PACKET:
            raise WrongMysqlVariableValue(
                variable_name="max_allowed_packet",
                variable_value=remote_max_allowed_packet,
            )

    def is_clone_possible(self) -> bool:
        try:
            self.check_is_same_series()
            self.check_max_allowed_packet()
            self.check_required_plugins_on_src()
            self.check_must_be_the_same_variables()
        except (CloneException, VariableIsNotSetInDatabase) as e:
            logger.error(str(e))
            return False
        return True
