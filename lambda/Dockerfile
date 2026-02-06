FROM public.ecr.aws/lambda/python:3.14

COPY requirements.txt  .
RUN  pip3 install -r requirements.txt --target "${LAMBDA_TASK_ROOT}"

COPY main.py "${LAMBDA_TASK_ROOT}"
COPY secrets.py "${LAMBDA_TASK_ROOT}"
COPY scripts/download-kubectl.sh ./
RUN chmod +x ./download-kubectl.sh && \
    ./download-kubectl.sh && \
    rm ./download-kubectl.sh

CMD [ "main.handler" ]
