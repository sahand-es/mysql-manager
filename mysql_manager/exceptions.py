class ProgramKilled(Exception):
    def __init__(self) -> None:
        super().__init__("Got signal from OS to stop")

class MysqlConnectionException(Exception): 
    def __init__(self) -> None:
        super().__init__("Could not connect to MySQL")


class MysqlReplicationException(Exception): 
    def __init__(self) -> None:
        super().__init__("Could not start MySQL replication")


class MysqlAddPITREventException(Exception):
    def __init__(self) -> None:
        super().__init__("Could not add PITR Event to Mysql")
