from mysql_manager.exceptions import PluginsAreNotInstalled, DifferentMysqlVariable
from mysql_manager.instance import Mysql
from mysql_manager.enums import PluginStatus


class CloneHelper:
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
    def is_clone_possible(cls, src: Mysql, repl: Mysql):
        cls.check_must_be_the_same_variables(src, repl)
        cls.check_required_plugins_on_src(src, repl)
