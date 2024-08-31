FROM hub.hamdocker.ir/library/python:3.11.3
COPY requirements.txt .
RUN pip install -r requirements.txt
WORKDIR /app
COPY . . 
ENV PYTHONUNBUFFERED 1
RUN pip install .

ENTRYPOINT ["python", "cli/mysql-cli.py", "mysql", "run"]
