FROM dpage/pgadmin4:latest

USER root
RUN apk update -f && apk upgrade -f && apk add bash wait-for-it

WORKDIR /pgadmin4
RUN mkdir /credentials && mkdir /servers && touch /credentials/pgpassfile
COPY /conf/servers.json /servers/servers.json
COPY /scripts/entrypoint.sh /entrypoint.sh
COPY /scripts/util.sh /util.sh
RUN chown -R pgadmin /servers /credentials /entrypoint.sh /util.sh

USER pgadmin
ENTRYPOINT ["/entrypoint.sh"]