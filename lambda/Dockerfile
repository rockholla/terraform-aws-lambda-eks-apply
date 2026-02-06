FROM public.ecr.aws/lambda/python:3.14

COPY requirements.txt  .
RUN  pip3 install -r requirements.txt --target "${LAMBDA_TASK_ROOT}"

COPY main.py "${LAMBDA_TASK_ROOT}"
COPY secrets.py "${LAMBDA_TASK_ROOT}"
COPY scripts/download-kubectl.sh /tmp/
RUN chmod +x /tmp/download-kubectl.sh && \
    cd /tmp/ && \
    ./download-kubectl.sh && \
    rm ./download-kubectl.sh && \
    mv ./kubectl ${LAMBDA_TASK_ROOT}/

CMD [ "main.handler" ]
