FROM ubuntu:26.04
ARG TERRAFORM_DOCS_VERSION="v0.21.0"
ARG TFSWITCH_VERSION="1.13.0"

RUN apt update && \
    apt install -y curl git && \
    apt clean -y

RUN curl -sSLo ./terraform-docs.tar.gz https://terraform-docs.io/dl/${TERRAFORM_DOCS_VERSION}/terraform-docs-${TERRAFORM_DOCS_VERSION}-$(uname)-amd64.tar.gz && \
    tar -xzf terraform-docs.tar.gz && \
    chmod +x terraform-docs && \
    mv terraform-docs /usr/local/bin/terraform-docs

RUN curl -L https://raw.githubusercontent.com/warrensbox/terraform-switcher/release/install.sh | bash -s -- v"${TFSWITCH_VERSION}"

ENTRYPOINT [ "/bin/bash" ]
