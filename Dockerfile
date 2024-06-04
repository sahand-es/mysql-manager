FROM hub.hamdocker.ir/library/python:3.11.3
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . . 
RUN pip install .
