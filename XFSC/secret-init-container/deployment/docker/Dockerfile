FROM openbao/openbao:2.5

USER root

RUN apk add --no-cache \
      bash \
      ca-certificates \
      coreutils \
      jq \
      openssl \
      util-linux \
    && mkdir -p /opt/xfsc/bin \
    && chown -R 65532:65532 /opt/xfsc

COPY ../openbao-init.sh /opt/xfsc/bin/openbao-init.sh

RUN chmod 0755 /opt/xfsc/bin/openbao-init.sh

USER 65532:65532

ENTRYPOINT ["/opt/xfsc/bin/openbao-init.sh"]