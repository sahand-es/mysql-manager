from mysql_manager.exceptions import PluginsAreNotInstalled, DifferentMysqlVariable, SourceAndReplAreInDifferentSeries, WrongMysqlVariableValue
from mysql_manager.instance import Mysql
from mysql_manager.enums import PluginStatus


class CloneHelper:
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

    @staticmethod
    def check_required_plugins_on_src(src: Mysql, repl: Mysql):
        src_active_plugins = src.get_plugins(status=PluginStatus.ACTIVE.value)
        repl_active_plugins = repl.get_plugins(status=PluginStatus.ACTIVE.value)
        required_plugins_on_src = repl_active_plugins - src_active_plugins
        if required_plugins_on_src:
            raise PluginsAreNotInstalled(
                plugin_names=[
                    plugin.name for plugin in required_plugins_on_src
                ]
            )

    @staticmethod
    def check_must_be_the_same_variables(src: Mysql, repl: Mysql):
        must_be_the_same_variables = [
            "innodb_page_size",
            "innodb_data_file_path",
            "character_set_database",
            "collation_database"
        ]
        for variable in must_be_the_same_variables:
            value_in_src = src.get_variable(variable)
            value_in_repl = repl.get_variable(variable)
            if value_in_src != value_in_repl:
                raise DifferentMysqlVariable(
                    variable_name=variable,
                    src_value=value_in_src,
                    repl_value=value_in_repl
                )
    @classmethod
    def check_is_same_series(cls, src: Mysql, repl: Mysql):
        src_version = src.get_variable("version")
        repl_version = repl.get_variable("version")
        if not cls.is_same_series(src_version, repl_version):
            raise SourceAndReplAreInDifferentSeries(
                src_version=src_version,
                repl_version=repl_version
            )
    @classmethod
    def check_max_allowed_packet(cls, src: Mysql, repl: Mysql):
        minimum_max_allowed_packet = 2097152
        src_max_allowed_packet = int(src.get_variable("max_allowed_packet"))
        repl_max_allowed_packet = int(repl.get_variable("max_allowed_packet"))
        if src_max_allowed_packet < minimum_max_allowed_packet:
            raise WrongMysqlVariableValue(
                variable_name="max_allowed_packet",
                variable_value=src_max_allowed_packet,
            )
        if repl_max_allowed_packet < minimum_max_allowed_packet:
            raise WrongMysqlVariableValue(
                variable_name="max_allowed_packet",
                variable_value=repl_max_allowed_packet,
            )

    @classmethod
    def is_clone_possible(cls, src: Mysql, repl: Mysql) -> bool:
        cls.check_is_same_series(src, repl)
        cls.check_max_allowed_packet(src, repl)
        cls.check_required_plugins_on_src(src, repl)
        cls.check_must_be_the_same_variables(src, repl)
        return True
