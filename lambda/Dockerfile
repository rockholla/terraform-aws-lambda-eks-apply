FROM public.ecr.aws/lambda/python:3.14

RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
RUN chmod +x ./kubectl
RUN mv ./kubectl /usr/local/bin

COPY requirements.txt  .
RUN  pip3 install -r requirements.txt --target "${LAMBDA_TASK_ROOT}"

COPY main.py "${LAMBDA_TASK_ROOT}"
COPY secrets.py "${LAMBDA_TASK_ROOT}"

CMD [ "main.handler" ]
