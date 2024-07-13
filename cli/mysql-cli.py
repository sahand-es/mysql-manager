import os
from configparser import ConfigParser

import click

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


def get_instance_from_config(config, host):
    return config.get(host, 'user'), config.get(host, 'password'), int(config.get(host, 'port'))


@click.group()
# @click.option('--config-file', type=click.Path(exists=True), help='Path to configuration file')
@click.pass_context
def cli(ctx, config_file='config.ini'):
    ctx.ensure_object(dict)
    ctx.obj['CONFIG'] = read_config_file(config_file) if config_file else None


@cli.group()
@click.pass_context
def mysql(ctx):
    pass


@mysql.command()
@click.option('-h', '--host', help='MySQL host', required=True)
@click.option('-u', '--user', help='Username for MySQL', default='root')
@click.option('-p', '--password', help='Password for MySQL', required=True)
@click.option('--port', help='Port for MySQL', type=int, default=3306)
@click.pass_context
def add(ctx, host, user, password, port):
    config = ConfigParser()
    config.read('config.ini')

    if not config.has_section(host):
        config.add_section(host)

    config.set(host, 'user', user)
    config.set(host, 'password', password)
    config.set(host, 'port', str(port))

    with open('config.ini', 'w') as configfile:
        config.write(configfile)


@mysql.command()
@click.option('-h', '--host', help='MySQL host')
@click.option('-u', '--user', help='Username for new user')
@click.option('-p', '--password', help='Password for new user')
@click.option('--roles', help='Comma-separated roles for the new user')
@click.pass_context
def create_user(ctx, host, user, password, roles):
    config = ctx.obj['CONFIG']

    print(f"Creating user '{user}' with roles {roles.split(',')} on host '{host}'")
    ins = MysqlInstance(host, *get_instance_from_config(config, host))
    ins.create_new_user(user, password, roles.split(','))


@mysql.command()
@click.option('--master', help='Master MySQL host for replication')
@click.option('--replica', help='Replica MySQL host for replication')
@click.pass_context
def add_replica(ctx, master, replica):
    config = ctx.obj['CONFIG']
    print(f"Adding replica from master '{master}' to replica '{replica}'")
    src = MysqlInstance(master, *get_instance_from_config(config, master))
    repl = MysqlInstance(replica, *get_instance_from_config(config, master))
    src.add_replica(repl)

@mysql.command()
@click.option('--master', help='Master MySQL host')
@click.option('--replica', help='MySQL host to start replication')
@click.option('--repl-user', help='Replication user')
@click.option('--repl-password', help='Replication user password')
@click.pass_context
def start_replication(ctx, master, replica, repl_user, repl_password):
    config = ctx.obj['CONFIG']

    print(f"Starting replication on host '{replica}' with repl_user '{repl_user}' on master '{master}'")
    master = MysqlInstance(master, *get_instance_from_config(config, master))
    repl = MysqlInstance(replica, *get_instance_from_config(config, replica))
    repl.set_master(master)
    repl.start_replication(repl_user, repl_password)


@mysql.command()
@click.option('--host', help='MySQL host')
@click.option('--password', help='Monitoring user password')
@click.pass_context
def create_monitoring_user(ctx, host, password):
    config = ctx.obj['CONFIG']

    print(f"Creating monitoring user for host '{host}'")
    src = MysqlInstance(host, *get_instance_from_config(config, host))
    src.create_monitoring_user(password)


@cli.group()
@click.pass_context
def proxysql(ctx):
    pass


@proxysql.command()
@click.option('-h', '--host', help='MySQL host', required=True)
@click.option('-u', '--user', help='Username for MySQL', default='root')
@click.option('-p', '--password', help='Password for MySQL', required=True)
@click.option('--port', help='Port for MySQL', type=int, default=6032)
@click.pass_context
def add(ctx, host, user, password, port):
    config = ConfigParser()
    config.read('config.ini')

    if not config.has_section(host):
        config.add_section(host)

    config.set(host, 'user', user)
    config.set(host, 'password', password)
    config.set(host, 'port', str(port))

    with open('config.ini', 'w') as configfile:
        config.write(configfile)

@proxysql.command()
@click.option('-h', '--host', help='ProxySQL host')
@click.option('--mysql-user', help='MySQL username')
@click.option('--mysql-password', help='MySQL password')
@click.option('--monitor-user', help='Monitor username')
@click.option('--monitor-password', help='Monitor password')
@click.pass_context
def initialize(ctx, host, mysql_user, mysql_password, monitor_user, monitor_password):
    config = ctx.obj['CONFIG']

    proxysql_user, proxysql_password, proxysql_port = get_instance_from_config(config, host)

    print(f"Initializing ProxySQL on host '{host}'")
    px = ProxySQL(
        host,
        proxysql_user,
        proxysql_password,
        mysql_user,
        mysql_password,
        monitor_user,
        monitor_password,
    )
    px.initialize_setup()


@proxysql.command()
@click.option('--mysql-host', help='MySql host')
@click.option('--proxysql-host', help='MySql host')
@click.option('--read-weight', help='Read weight')
@click.option('--is-writer', is_flag=True, help='Specify if the backend is a writer')
@click.pass_context
def add_backend(ctx, mysql_host, proxysql_host, read_weight, is_writer):
    config = ctx.obj['CONFIG']

    role = 'writer' if is_writer else 'reader'
    print(f"Adding {role} backend to ProxySQL on host {proxysql_host}'")

    mysql_instance = MysqlInstance(mysql_host, *get_instance_from_config(config, mysql_host))
    px = ProxySQL(
        proxysql_host,
        *get_instance_from_config(config, proxysql_host)[:2],
        *get_instance_from_config(config, mysql_host)[:2],
        '',
        '',
    )
    px.add_backend(mysql_instance, read_weight, is_writer)


@mysql.command()
@click.option('-h', '--host', help='MySQL host')
@click.pass_context
def ping(ctx, host):
    config = ctx.obj['CONFIG']

    ins = MysqlInstance(host, *get_instance_from_config(config, host))
    res = ins.ping()
    print(f"Ping Result: {res}")


@mysql.command()
@click.option('-h', '--host', help='MySQL host')
@click.option('-c', '--command', help='Command to be executed for MySQL')
@click.pass_context
def get_info(ctx, host, command):
    config = ctx.obj['CONFIG']

    ins = MysqlInstance(host, *get_instance_from_config(config, host))
    res = ins.get_info(command)
    print(f"Get-Info Result: {res}")


if __name__ == '__main__':
    cli()
