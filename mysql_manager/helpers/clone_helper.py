from mysql_manager.exceptions import PluginsAreNotInstalled
from mysql_manager.instance import Mysql
from mysql_manager.enums import PluginStatus


class CloneHelper:
    @staticmethod
    def get_required_plugins_on_src(src: Mysql, repl: Mysql):
        src_active_plugins = src.get_plugins(status=PluginStatus.ACTIVE.value)
        repl_active_plugins = repl.get_plugins(status=PluginStatus.ACTIVE.value)
        return src_active_plugins - repl_active_plugins

    @classmethod
    def is_clone_possible(cls, src: Mysql, repl: Mysql):
        required_plugins_on_src = cls.get_required_plugins_on_src(src, repl)
        if required_plugins_on_src:
            raise PluginsAreNotInstalled(
                plugin_names=[
                    plugin.name for plugin in required_plugins_on_src
                ]
            )
