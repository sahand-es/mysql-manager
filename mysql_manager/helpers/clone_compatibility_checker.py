import logging
from mysql_manager.clone_exceptions import CloneException, PluginsAreNotInstalled, DifferentMysqlVariable, SourceAndRemoteAreInDifferentSeries, WrongMysqlVariableValue
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
    def are_versions_compatible(src_version: str, remote_version: str) -> bool:
        """
        Check if two MySQL version strings are compatible.

        This function checks if the source and destination MySQL versions are compatible.
        For versions before 8.0.37, the source and destination versions must be exactly the same.
        For versions 8.0.37 and later, only the major and minor version numbers need to match.

        Args:
            src_version (str): The source version string (e.g., "8.4.0").
            dest_version (str): The destination version string (e.g., "8.4.11").

        Returns:
            bool: True if the versions are compatible, False otherwise.

        Notes:
            Before version 8.0.37, the MySQL clone plugin requires that the source and destination versions
            must be the same. For more information, see:
            https://dev.mysql.com/doc/refman/8.0/en/clone-plugin-remote.html

        Example:
            >>> are_versions_compatible("8.4.0", "8.4.11")
            True
            >>> are_versions_compatible("8.4.0", "8.5.11")
            False
            >>> are_versions_compatible("8.0.35", "8.0.35")
            True
            >>> are_versions_compatible("8.0.35", "8.0.36")
            False
        """       # Split the version strings into major, minor, and patch components
        major1, minor1, patch1 = map(int, src_version.split('.'))
        major2, minor2, patch2 = map(int, remote_version.split('.'))
        if (major1, minor1, patch1) < (8, 0, 37) or (major2, minor2, patch2) < (8, 0, 37):
            # Before 8.0.37, src and dest version should be the same
            return (major1, minor1, patch1) == (major2, minor2, patch2)
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
        if not self.are_versions_compatible(src_version, remote_version):
            raise SourceAndRemoteAreInDifferentSeries(
                src_version=src_version,
                remote_version=remote_version
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
