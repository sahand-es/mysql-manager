import time
import xmltodict
import logging
from behave import *


logger = logging.getLogger(__name__)

@given('sleep {n:d} seconds')
def sleep(context, n):
    time.sleep(n)

@given('setup default proxysql with name: {name:w} and image: {image}')
def start_default_proxysql(context, name, image):
    context.test_env.setup_proxysql(
        {
            "name": name,
            "image": image, 
            "local_username": "admin", 
            "local_password": "pwd", 
            "remote_username": "radmin", 
            "remote_password": "pwd"
        }
    )

@given('setup default mysql with server_id {server_id:d} and image: {image}')
def start_proxysql(context, server_id, image):
    context.test_env.setup_mysql(
        {"server_id": server_id, "image": image}
    )

@given('setup mysql_manager with name {name:w}')
def start_mysql_manager(context, name):
    context.test_env.setup_mysql_manager(
        {"name": name, "image": context.mysql_manager_image}
    )

@given('stop mysql with server_id {server_id:d}')
def start_mysql(context, server_id):
    context.test_env.stop_mysql(server_id)

@given('start mysql with server_id {server_id:d}')
def stop_mysql(context, server_id):
    context.test_env.start_mysql(server_id)

@given('restart mysql manager')
def restart_mysql_manager(context):
    context.test_env.restart_mysql_manager()


@when('execute mysql query with user: {user:w}, password: {password:w}, host: {host} and port: {port} query: {query}')
def exec_query(context, user, password, host, port, query):
    mysql = context.test_env.get_one_up_mysql()
    command = f"""mysql -u{user} -p{password} -h {host} -P {port} -e "{query}"
"""
    mysql.exec(command)

@then('result of query: "{query}" with user: {user:w} and password: {password: w} on host: {host} and port: {port} should be')
def evaluate_query_result(context, query, user, password, host, port):
    result = context.text
    mysql = context.test_env.get_one_up_mysql()
    command = f"""mysql -u{user} -p{password} -h {host} -P {port} -X -e "{query}"
"""
    output = mysql.exec(command).output.decode()
    output = output.split("mysql: [Warning] Using a password on the command line interface can be insecure.\n")
    output = output[1]
    assert xmltodict.parse(output) == xmltodict.parse(result)
