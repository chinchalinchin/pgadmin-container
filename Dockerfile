FROM dpage/pgadmin4:latest

USER root
RUN apk update -f && apk upgrade -f && apk add bash

WORKDIR /pgadmin4
RUN mkdir /credentials && mkdir /servers && touch /credentials/pgpassfile
COPY /conf/servers.json /servers/servers.json
RUN chown -R pgadmin /servers && chown -R pgadmin /credentials
COPY /scripts/entrypoint.sh /entrypoint.sh
RUN chown pgadmin /entrypoint.sh

USER pgadmin
ENTRYPOINT ["/entrypoint.sh"]