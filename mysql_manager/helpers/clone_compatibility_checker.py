import logging
import datetime
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

    def _log(self, msg) -> None:
        print(str(datetime.datetime.now()) + "  " + msg)

    def are_required_plugins_installed_on_src(self) -> bool:
        src_active_plugins = self.src.get_plugins(status=PluginStatus.ACTIVE.value)
        remote_active_plugins = self.remote.get_plugins(status=PluginStatus.ACTIVE.value)
        required_plugins_on_src = remote_active_plugins - src_active_plugins
        if required_plugins_on_src:
            required_plugin_names=[
                plugin.name for plugin in required_plugins_on_src
            ]
            self._log(f"These plugins should be installed: {required_plugin_names}")
            return False
        return True

    def are_required_variables_matching(self) -> bool:
        """
        Checks if the required MySQL variables are the same between the source and remote databases.

        This function iterates through a predefined list of MySQL variables that must have identical
        values in both the source and remote databases. If any variable's value does not match between
        the two databases, it logs an error message and returns False. If all variables match, it returns True.

        Returns:
            bool: True if all required variables match between the source and remote databases, False otherwise.
        """
        for variable in self.MUST_BE_THE_SAME_VARIABLES:
            value_in_src = self.src.get_global_variable(variable)
            value_in_remote = self.remote.get_global_variable(variable)
            if value_in_src != value_in_remote:
                self._log(f"Variable {variable} must be the same in source and remote. Source value = {value_in_src}, remote value = {value_in_remote}")
                return False
        return True

    def is_max_packet_size_valid(self) -> bool:
        src_max_allowed_packet = int(self.src.get_global_variable("max_allowed_packet"))
        remote_max_allowed_packet = int(self.remote.get_global_variable("max_allowed_packet"))
        if src_max_allowed_packet < self.MINIMUM_MAX_ALLOWED_PACKET:
            self._log(f"Variable max_allowed_packet has wrong value in source database. It should be more than {self.MINIMUM_MAX_ALLOWED_PACKET} bytes, while current value is {src_max_allowed_packet} bytes.")
            return False
        if remote_max_allowed_packet < self.MINIMUM_MAX_ALLOWED_PACKET:
            self._log(f"Variable max_allowed_packet has wrong value in remote database. It should be more than {self.MINIMUM_MAX_ALLOWED_PACKET} bytes, while current value is {remote_max_allowed_packet} bytes.")
            return False
        return True

    def is_password_length_valid(self) -> bool:
        if len(self.remote.password) > 32:
            self._log("The length of replication password should be less than 32")
            return False
        return True

    def is_clone_possible(self) -> bool:
        return all(
            (
                self.is_password_length_valid(),
                self.is_max_packet_size_valid(),
                self.are_required_plugins_installed_on_src(),
                self.are_required_variables_matching()
            )
        )
