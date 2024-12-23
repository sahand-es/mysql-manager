class CloneException(Exception):
    pass

class PluginsAreNotInstalled(CloneException):
    def __init__(self, plugin_names: list[str]) -> None:
        super().__init__(f"These plugins should be installed: {plugin_names}")

class WrongMysqlVariableValue(CloneException):
    def __init__(self, variable_name: str, variable_value) -> None:
        super().__init__(
            f"Variable {variable_name} has wrong value. value = {variable_value}"
        )

class DifferentMysqlVariable(CloneException):
    def __init__(self, variable_name: str, src_value: str, repl_value: str) -> None:
        super().__init__(
            f"Variable {variable_name} must be the same in src and repl. src_value={src_value}, repl_value={repl_value}"
        )

class SourceAndRemoteAreInDifferentSeries(CloneException):
    def __init__(self, src_version: str, remote_version: str) -> None:
        super().__init__(
            f"Src and remote are in different series. src_version={src_version}, remote_version={remote_version}"
        )

class CloneIsNotPossible(CloneException):
    def __init__(self) -> None:
        super().__init__(
            f"Clone is not possible"
        )

