ARG VERSION=9
ARG REGISTRY=docker.io/library
FROM $REGISTRY/mysql:$VERSION-oracle

USER 0

ENV MYSQL_DATA_DIR=/var/lib/mysql \
    MYSQL_RUN_DIR=/var/run/mysql \
    MYSQL_LOG_DIR=/var/log/mysql \
    MYSQL_ETC_DIR=/etc/mysql \
    MYSQL_INIT_DIR=/docker-entrypoint-initdb.d

ENV GO_ON_NON_ROOT_1=1

RUN mkdir -p ${MYSQL_DATA_DIR} ${MYSQL_RUN_DIR} ${MYSQL_LOG_DIR} ${MYSQL_INIT_DIR} && \
    chgrp -R 0 ${MYSQL_DATA_DIR} ${MYSQL_RUN_DIR} ${MYSQL_LOG_DIR} ${MYSQL_INIT_DIR} && \
    chmod -R g+rwX ${MYSQL_DATA_DIR} ${MYSQL_RUN_DIR} ${MYSQL_LOG_DIR} ${MYSQL_INIT_DIR}

USER 1031
