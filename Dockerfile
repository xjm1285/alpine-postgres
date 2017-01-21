FROM daocloud.io/xjm1285/alpine-postgres
MAINTAINER Jimmy Xiao <xjm1285@gmail.com>

ENV PGDATA=/var/lib/postgresql/data
ENV GOSU_VERSION=1.10

COPY root /
RUN apk add --update --no-cache \
    curl postgresql postgresql-dev \
  && curl -o /bin/gosu -sSL "https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-amd64" \
  && chmod +x /bin/gosu \
  && chmod -R +x /etc/cont-init.d \
  && chmod -R +x /etc/services.d \
  && apk del --no-cache curl libcurl libssh2 ca-certificates


EXPOSE 5432
