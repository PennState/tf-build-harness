FROM golang:1.13-alpine as gobuilder

RUN apk add git
ENV GO111MODULE=on
RUN go get github.com/hashicorp/terraform-config-inspect \
 && cp `which terraform-config-inspect` /


FROM alpine:3.11

ENV TERRAFORM_VERSION=0.12.24
ENV RUBY_VERSION=2.4.9
ENV TERRATEST_LOG_PARSER_VERSION=0.23.4
ENV TERRAFORM_DOCS_VERSION=v0.8.1
ENV AWS_IAM_AUTHENTICATOR="1.15.10/2020-02-22"

ENV TF_BUILD_HARNESS_PATH=/tf-build-harness

# custom bin directory
RUN mkdir -p ${TF_BUILD_HARNESS_PATH}
ADD bin ${TF_BUILD_HARNESS_PATH}/bin
RUN chmod +x ${TF_BUILD_HARNESS_PATH}/bin/*
ENV PATH=${TF_BUILD_HARNESS_PATH}/bin:$PATH

# update/upgrade and all other packages
RUN apk update \
 && apk upgrade \
 && apk add curl gnupg go git unzip bash libssl1.1 libcrypto1.1 libffi-dev build-base linux-headers zlib-dev openssl-dev readline-dev openssh-client coreutils

# aws-iam-authenticator

RUN curl -o aws-iam-authenticator https://amazon-eks.s3-us-west-2.amazonaws.com/${AWS_IAM_AUTHENTICATOR}/bin/linux/amd64/aws-iam-authenticator \
 && curl -o aws-iam-authenticator.sha256 https://amazon-eks.s3-us-west-2.amazonaws.com/${AWS_IAM_AUTHENTICATOR}/bin/linux/amd64/aws-iam-authenticator.sha256 \
 && sha256sum -c --ignore-missing aws-iam-authenticator.sha256 \
 && chmod +x ./aws-iam-authenticator \
 && mv aws-iam-authenticator /usr/local/bin

# terraform
ADD pgp_keys.asc .
RUN curl -Os https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip \
 && curl -Os https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_SHA256SUMS \
 && cat pgp_keys.asc | gpg --import \
 && curl -Os https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_SHA256SUMS.sig \
 && gpg --verify terraform_${TERRAFORM_VERSION}_SHA256SUMS.sig terraform_${TERRAFORM_VERSION}_SHA256SUMS \
 && sha256sum -c terraform_${TERRAFORM_VERSION}_SHA256SUMS 2>&1 | grep "${TERRAFORM_VERSION}_linux_amd64.zip:\sOK" \
 && unzip terraform_${TERRAFORM_VERSION}_linux_amd64.zip -d /usr/local/bin \
 && rm -f terraform_${TERRAFORM_VERSION}_linux_amd64.zip

# terraform-docs
RUN curl -OsL https://github.com/segmentio/terraform-docs/releases/download/${TERRAFORM_DOCS_VERSION}/terraform-docs-${TERRAFORM_DOCS_VERSION}-linux-amd64 \
 && mv terraform-docs-${TERRAFORM_DOCS_VERSION}-linux-amd64 /usr/local/bin/terraform-docs \
 && chmod +x /usr/local/bin/terraform-docs

# gopath
ENV GOPATH /workdir

# rbenv
ENV PATH /usr/local/rbenv/shims:/usr/local/rbenv/bin:$PATH
ENV RBENV_ROOT /usr/local/rbenv
ENV RUBY_CONFIGURE_OPTS --disable-install-doc

RUN git clone https://github.com/rbenv/rbenv.git /usr/local/rbenv \
 && echo 'eval "$(rbenv init -)"' >> /etc/profile.d/rbenv.sh \
 && mkdir -p "$(rbenv root)"/plugins \
 && git clone https://github.com/rbenv/ruby-build.git "$(rbenv root)"/plugins/ruby-build

# ruby
RUN rbenv install ${RUBY_VERSION} \
 && rbenv rehash \
 && rbenv global ${RUBY_VERSION}

# bundler
RUN gem update --system && gem install --force bundler

# terratest_log_parser
RUN curl -Os \
 https://github.com/gruntwork-io/terratest/releases/download/${TERRATEST_LOG_PARSER_VERSION}/terratest_log_parser_linux_amd64 \
 && mv terratest_log_parser_linux_amd64 /usr/local/bin/terratest_log_parser \
 && chmod +x /usr/local/bin/terratest_log_parser

# terraform-config-inspect
COPY --from=gobuilder /terraform-config-inspect /usr/local/bin/terraform-config-inspect

WORKDIR /work
