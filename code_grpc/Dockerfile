FROM python:3.8
ADD app/ /
RUN pip install -r requirements.txt

EXPOSE 9000
CMD [ "python", "./server.py"]