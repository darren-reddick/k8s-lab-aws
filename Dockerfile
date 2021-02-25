FROM hashicorp/terraform:0.13.6

RUN apk add --no-cache \
  python3 \
  py3-pip \
  && pip3 install --upgrade pip \
  && pip3 install \
  awscli \
  && rm -rf /var/cache/apk/*

RUN aws --version
