ARG VERSION=9
ARG REGISTRY=docker.io/library
FROM $REGISTRY/mysql:$VERSION-oracle

USER 0

ENV MYSQL_DATA_DIR=/var/lib/mysql \
    MYSQL_RUN_DIR=/var/run/mysqld \
    MYSQL_LOG_DIR=/var/log/mysql \
    MYSQL_ETC_DIR=/etc/mysql \
    MYSQL_INIT_DIR=/docker-entrypoint-initdb.d \
    MYSQL_FILES_DIR=/var/lib/mysql-files

ENV GO_ON_NON_ROOT_1=1 \
    UMASK=0660 \
    UMASK_DIR=0770

RUN rm -rf ${MYSQL_DATA_DIR} ${MYSQL_RUN_DIR} ${MYSQL_FILES_DIR} && \
    mkdir -p ${MYSQL_DATA_DIR} ${MYSQL_RUN_DIR} ${MYSQL_LOG_DIR} ${MYSQL_ETC_DIR} ${MYSQL_INIT_DIR} ${MYSQL_FILES_DIR} && \
    chgrp -R 0 ${MYSQL_DATA_DIR} ${MYSQL_RUN_DIR} ${MYSQL_LOG_DIR} ${MYSQL_ETC_DIR} ${MYSQL_INIT_DIR} ${MYSQL_FILES_DIR} && \
    chmod -R g+rwX ${MYSQL_DATA_DIR} ${MYSQL_RUN_DIR} ${MYSQL_LOG_DIR} ${MYSQL_ETC_DIR} ${MYSQL_INIT_DIR} ${MYSQL_FILES_DIR}

USER 1031
