# FROM hub.hamdocker.ir/library/python:3.11.3
FROM docker.arvancloud.ir/library/python:3.11.3
COPY requirements.txt .
COPY pip.conf /root/.pip/
RUN pip install -r requirements.txt
WORKDIR /app
COPY . . 
ENV PYTHONUNBUFFERED 1
RUN pip install .

CMD ["python", "cli/mysql-cli.py", "mysql", "run"]
