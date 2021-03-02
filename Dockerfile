FROM dpage/pgadmin4:latest

USER root
WORKDIR /pgadmin4
RUN apk update -f && apk upgrade -f && apk add bash wget gettext moreutils && \
    wget https://raw.githubusercontent.com/vishnubob/wait-for-it/master/wait-for-it.sh &&\
    chown pgadmin:pgadmin /pgadmin4/wait-for-it.sh && chmod 700 /pgadmin4/wait-for-it.sh

RUN mkdir /credentials && touch /credentials/pgpassfile && mkdir /pgadmin4/servers
COPY /conf/servers.json /pgadmin4/servers/servers.json
COPY /scripts /pgadmin4
RUN chown -R pgadmin:pgadmin /pgadmin4/ /credentials/

USER pgadmin
ENTRYPOINT ["/pgadmin4/entrypoint.sh"]