import os
from configparser import ConfigParser

import click

from mysql_manager.cluster import ClusterManager
from mysql_manager.constants import DEFAULT_CONFIG_PATH
from mysql_manager.instance import MysqlInstance
from mysql_manager.proxysql import ProxySQL

current_dir = os.getcwd()
BASE_DIR = os.path.abspath(os.path.join(current_dir, os.pardir))


def read_config_file(config_file):
    config = ConfigParser()
    config.read(config_file)
    return config


def get_option_or_config(option, config, section, key, default=None):
    if option:
        return option
    if config and config.has_option(section, key):
        return config.get(section, key)
    if default:
        return default
    raise click.BadParameter(f'Missing required parameter: {key}')


def get_instance_from_config(config, name):
    return {
        'host': config.get(name, 'host'),
        'user': config.get(name, 'user'),
        'password': config.get(name, 'password'),
        'port': int(config.get(name, 'port'))
    }


@click.group()
@click.pass_context
def cli(ctx):
    ctx.ensure_object(dict)
    os.makedirs('/etc/mm', exist_ok=True)
    ctx.obj['CONFIG'] = read_config_file(DEFAULT_CONFIG_PATH) if DEFAULT_CONFIG_PATH else None


@cli.group()
@click.pass_context
def mysql(ctx):
    pass


@mysql.command()
@click.option('-n', '--name', help='MySQL name', required=True)
@click.option('-h', '--host', help='MySQL host', required=True)
@click.option('-u', '--user', help='Username for MySQL', default='root')
@click.option('-p', '--password', help='Password for MySQL', required=True)
@click.option('--port', help='Port for MySQL', type=int, default=3306)
@click.pass_context
def add(ctx, name, host, user, password, port):
    config = ConfigParser()
    config.read(DEFAULT_CONFIG_PATH)

    if not config.has_section(name):
        config.add_section(name)

    config.set(name, 'host', host)
    config.set(name, 'user', user)
    config.set(name, 'password', password)
    config.set(name, 'port', str(port))

    with open(DEFAULT_CONFIG_PATH, 'w') as configfile:
        config.write(configfile)


@mysql.command()
@click.option('-n', '--name', help='MySQL name')
@click.option('-u', '--user', help='Username for new user')
@click.option('-p', '--password', help='Password for new user')
@click.option('--roles', help='Comma-separated roles for the new user')
@click.pass_context
def create_user(ctx, name, user, password, roles):
    config = ctx.obj['CONFIG']

    print(f"Creating user '{user}' with roles {roles.split(',')} on mysql '{name}'")
    ins = MysqlInstance(**get_instance_from_config(config, name))
    ins.create_new_user(user, password, roles.split(','))


def create_config_file_from_env(nodes_count: int):
    filename = "/etc/mm/config.ini"
    # if os.path.isfile(filename):
    #     return
    
    config = ConfigParser()
    config.add_section("mysql-s1")
    config.set("mysql-s1", "host", os.getenv("MYSQL_S1_HOST"))
    config.set("mysql-s1", "user", "root")
    config.set("mysql-s1", "password", os.getenv("MYSQL_ROOT_PASSWORD"))
    if nodes_count == 2:
        config.add_section("mysql-s2")
        config.set("mysql-s2", "host", os.getenv("MYSQL_S2_HOST"))
        config.set("mysql-s2", "user", "root")
        config.set("mysql-s2", "password", os.getenv("MYSQL_ROOT_PASSWORD"))
    
    config.add_section("proxysql-1")
    config.set("proxysql-1", "host", os.getenv("PROXYSQL_HOST"))
    config.set("proxysql-1", "user", "radmin")
    config.set("proxysql-1", "password", os.getenv("PROXYSQL_PASSWORD"))

    config.add_section("users")
    config.set("users", "repl_password", os.getenv("MYSQL_REPL_PASSWORD"))
    config.set("users", "exporter_password", os.getenv("MYSQL_EXPORTER_PASSWORD"))
    config.set("users", "proxysql_mon_password", os.getenv("PROXYSQL_MON_PASSWORD"))
    config.set("users", "nonpriv_user", os.getenv("MYSQL_NONPRIV_USER"))
    config.set("users", "nonpriv_password", os.getenv("MYSQL_NONPRIV_PASSWORD"))

    os.makedirs(os.path.dirname(filename), exist_ok=True)
    with open(filename, "w") as configfile:
        config.write(configfile)


@mysql.command()
# @click.option('--config-file', help='Config file of Cluster Manager', required=False, default="/etc/mm/config.ini")
@click.option("--nodes", help="Node count for mysql cluster", required=False, default=1)
def start_cluster(nodes: int):
    create_config_file_from_env(nodes_count=nodes)
    print("Starting cluster...")
    clm = ClusterManager()
    clm.start()


@mysql.command()
@click.option("--nodes", help="Node count for mysql cluster", required=False, default=1)
def get_cluster_status(nodes: int):
    create_config_file_from_env(nodes_count=nodes)
    clm = ClusterManager()
    cluster_status = clm.get_cluster_status()
    print("master="+cluster_status["master"])
    print("replica="+cluster_status["replica"])


@mysql.command()
# @click.option("--nodes", help="Node count for mysql cluster", required=False, default=1)
def add_replica():
    create_config_file_from_env(nodes_count=2)
    clm = ClusterManager()
    clm.add_replica_to_master()

# @mysql.command()
# @click.option('--master', help='Master MySQL host for replication')
# @click.option('--replica', help='Replica MySQL host for replication')
# @click.pass_context
# def add_replica(ctx, master, replica):
#     config = ctx.obj['CONFIG']
#     print(f"Adding replica from master '{master}' to replica '{replica}'")
#     src = MysqlInstance(master, *get_instance_from_config(config, master))
#     repl = MysqlInstance(replica, *get_instance_from_config(config, master))
#     src.add_replica(repl)


@mysql.command()
@click.option('--master', help='Master MySQL name')
@click.option('--replica', help='MySQL name to start replication')
@click.option('--repl-user', help='Replication user')
@click.option('--repl-password', help='Replication user password')
@click.pass_context
def start_replication(ctx, master, replica, repl_user, repl_password):
    config = ctx.obj['CONFIG']

    print(f"Starting replication on mysql '{replica}' with repl_user '{repl_user}' on master '{master}'")
    master_instance = MysqlInstance(**get_instance_from_config(config, master))
    repl = MysqlInstance(**get_instance_from_config(config, replica))
    repl.set_master(master_instance)
    repl.start_replication(repl_user, repl_password)


@mysql.command()
@click.option('-n', '--name', help='MySQL name')
@click.option('--password', help='Monitoring user password')
@click.pass_context
def create_monitoring_user(ctx, name, password):
    config = ctx.obj['CONFIG']

    print(f"Creating monitoring user for mysql '{name}'")
    src = MysqlInstance(**get_instance_from_config(config, name))
    src.create_monitoring_user(password)


@cli.group()
@click.pass_context
def proxysql(ctx):
    pass


@proxysql.command()
@click.option('-n', '--name', help='MySQL name', required=True)
@click.option('-h', '--host', help='MySQL host', required=True)
@click.option('-u', '--user', help='Username for MySQL', default='root')
@click.option('-p', '--password', help='Password for MySQL', required=True)
@click.option('--port', help='Port for MySQL', type=int, default=6032)
@click.pass_context
def add(ctx, name, host, user, password, port):
    config = ConfigParser()
    config.read(DEFAULT_CONFIG_PATH)

    if not config.has_section(name):
        config.add_section(name)

    config.set(name, 'host', host)
    config.set(name, 'user', user)
    config.set(name, 'password', password)
    config.set(name, 'port', str(port))

    with open(DEFAULT_CONFIG_PATH, 'w') as configfile:
        config.write(configfile)


@proxysql.command()
@click.option('-n', '--name', help='ProxySQL name')
@click.option('--mysql-user', help='MySQL username')
@click.option('--mysql-password', help='MySQL password')
@click.option('--monitor-user', help='Monitor username')
@click.option('--monitor-password', help='Monitor password')
@click.pass_context
def initialize(ctx, name, mysql_user, mysql_password, monitor_user, monitor_password):
    config = ctx.obj['CONFIG']

    proxysql_ins = get_instance_from_config(config, name)
    proxysql_ins.pop('port')

    print(f"Initializing ProxySQL on proxysql '{name}'")
    px = ProxySQL(
        **proxysql_ins,
        mysql_user=mysql_user,
        mysql_password=mysql_password,
        monitor_user=monitor_user,
        monitor_password=monitor_password,
    )
    px.initialize_setup()


@proxysql.command()
@click.option('--mysql-name', help='MySql name')
@click.option('--proxysql-name', help='MySql name')
@click.option('--read-weight', help='Read weight')
@click.option('--is-writer', is_flag=True, help='Specify if the backend is a writer')
@click.pass_context
def add_backend(ctx, mysql_name, proxysql_name, read_weight, is_writer):
    config = ctx.obj['CONFIG']

    role = 'writer' if is_writer else 'reader'
    print(f"Adding {role} backend to ProxySQL on {proxysql_name}'")

    mysql_ins = get_instance_from_config(config, mysql_name)
    mysql_instance = MysqlInstance(**mysql_ins)
    proxysql_ins = get_instance_from_config(config, proxysql_name)
    proxysql_ins.pop('port')
    px = ProxySQL(
        **proxysql_ins,
        mysql_user=mysql_ins.get('user'),
        mysql_password=mysql_ins.get('password'),
        monitor_user='',
        monitor_password='',
    )
    px.add_backend(mysql_instance, read_weight, is_writer)


@proxysql.command()
@click.option('-n', '--name', help='Proxysql name')
@click.option('--on', is_flag=True, help='Specify if read write should be split')
@click.option('--off', is_flag=True, help='Specify if read write should NOT be split')
@click.pass_context
def split_rw(ctx, name, on, off):
    if on == off:
        raise Exception("Cannot have both on and off options at the same time")
    config = ctx.obj['CONFIG']
    proxysql_ins = get_instance_from_config(config, name)
    proxysql_ins.pop('port')
    px = ProxySQL(
        **proxysql_ins,
        mysql_user='',
        mysql_password='',
        monitor_user='',
        monitor_password='',
    )
    res = px.split_read_write(True if on else False)


@mysql.command()
@click.option('-n', '--name', help='MySQL name')
@click.pass_context
def ping(ctx, name):
    config = ctx.obj['CONFIG']

    ins = MysqlInstance(**get_instance_from_config(config, name))
    res = ins.ping()
    print(f"Ping Result: {res}")


# @mysql.command()
# @click.option('-n', '--name', help='MySQL name')
# @click.option('-c', '--command', help='Command to be executed for MySQL')
# @click.pass_context
# def get_info(ctx, name, command):
#     config = ctx.obj['CONFIG']

#     ins = MysqlInstance(host, *get_instance_from_config(config, host))
#     res = ins.run_command(command)
#     print(f"Get-Info Result: {res}")


@mysql.command()
@click.option('-n', '--name', help='MySQL name')
@click.option('-i', '--intervals', help='Intervals of flushing PITR binlogs in minutes')
@click.pass_context
def add_pitr_event(ctx, name, intervals):
    config = ctx.obj['CONFIG']

    ins = MysqlInstance(**get_instance_from_config(config, name))
    res = ins.add_pitr_event(intervals)
    print(f"Add PITR Event Result: {res}")


if __name__ == '__main__':
    cli()
