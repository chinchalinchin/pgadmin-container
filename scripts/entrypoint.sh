#!/bin/bash

#########################
# DATABASE INITIALIZATION
#########################

dbs=($FIRST_DB_NAME $SECOND_DB_NAME $THIRD_DB_NAME)
users=($FIRST_DB_USER $SECOND_DB_USER $THIRD_DB_USER)
passwords=($FIRST_DB_PASSWORD $SECOND_DB_PASSWORD $THIRD_DB_PASSWORD)


function get_db_index(){
    for i in "${!dbs[@]}"
    do 
        if [[ "${dbs[$i]}" = "$1" ]]
        then
            echo "${i}"
        fi 
    done
}

function execute_sql(){
    PGPASSWORD=$POSTGRES_PASSWORD psql -h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USER -c "$1"
}

function list_databases(){
    PGPASSWORD=$POSTGRES_PASSWORD psql -h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USER -lqt
}

function database_exists(){
    if list_databases | cut -d \| -f 1 | grep -qw "$1" 
    then
        echo 0
    else
        echo 1
    fi
}

nl=$'\n'
sleep 5s

if [ ! -f "/credentials/pgpassfile" ]
then
    touch /credentials/pgpassfile
    echo "$POSTGRES_HOST:$POSTGRES_PORT:*:$POSTGRES_USER:$POSTGRES_PASSWORD ${nl}" >> /credentials/pgpassfile
fi

for i in ${dbs[@]}
do
    exists=$(database_exists $i)

    if [ "$exists" == 0 ]
    then
        echo "NOTE: $i Database Already Exists, Skipping Creation"
    else
        db_index="$(get_db_index $i)"
        user=${users[$db_index]}
        password=${passwords[$db_index]}

        echo "-------------------------"
        echo "$i Database Configuration"
        echo "-------------------------"

        echo "Creating Database: $i"
        CREATE_CMD="CREATE DATABASE $i;"
        execute_sql "$CREATE_CMD"

        echo "Creating User : $user"
        USER_CMD="CREATE USER $user WITH ENCRYPTED PASSWORD '$password';"
        execute_sql "$USER_CMD"

        echo "Granting User : $user All Privileges On Database : $i"
        GRANT_CMD="GRANT ALL PRIVILEGES ON DATABASE $i TO $user;"
        execute_sql "$GRANT_CMD"

        echo "Configuring PGPASSFILE for User $user on Database $i"
        echo "$POSTGRES_HOST:$POSTGRES_PORT:$i:$user:$password ${nl}" >> /credentials/pgpassfile
    fi
    
done
echo "-------------------------"

echo "Configuring PGAdmin4's servers.json With Secret Credentials"
sed -i "s/__username__/$POSTGRES_USER/g" /servers/servers.json
sed -i "s/__host__/$POSTGRES_HOST/g" /servers/servers.json
sed -i "s/__port__/$POSTGRES_PORT/g" /servers/servers.json


##################################
# START DEFAULT PGADMIN ENTRYPOINT
##################################

# Populate config_distro.py. This has some default config, as well as anything
# provided by the user through the PGADMIN_CONFIG_* environment variables.
# Only update the file on first launch. The empty file is created during the
# container build so it can have the required ownership.
if [ `wc -m /pgadmin4/config_distro.py | awk '{ print $1 }'` = "0" ]; then
    cat << EOF > /pgadmin4/config_distro.py
HELP_PATH = '../../docs'
DEFAULT_BINARY_PATHS = {
        'pg': '/usr/local/pgsql-13'
}
EOF

    # This is a bit kludgy, but necessary as the container uses BusyBox/ash as
    # it's shell and not bash which would allow a much cleaner implementation
    for var in $(env | grep PGADMIN_CONFIG_ | cut -d "=" -f 1); do
        echo ${var#PGADMIN_CONFIG_} = $(eval "echo \$$var") >> /pgadmin4/config_distro.py
    done
fi

if [ ! -f /var/lib/pgadmin/pgadmin4.db ]; then
    if [ -z "${PGADMIN_DEFAULT_EMAIL}" -o -z "${PGADMIN_DEFAULT_PASSWORD}" ]; then
        echo 'You need to specify PGADMIN_DEFAULT_EMAIL and PGADMIN_DEFAULT_PASSWORD environment variables'
        exit 1
    fi

    # Set the default username and password in a
    # backwards compatible way
    export PGADMIN_SETUP_EMAIL=${PGADMIN_DEFAULT_EMAIL}
    export PGADMIN_SETUP_PASSWORD=${PGADMIN_DEFAULT_PASSWORD}

    # Initialize DB before starting Gunicorn
    # Importing pgadmin4 (from this script) is enough
    python run_pgadmin.py

    export PGADMIN_SERVER_JSON_FILE=${PGADMIN_SERVER_JSON_FILE:-/pgadmin4/servers.json}
    # Pre-load any required servers
    if [ -f "${PGADMIN_SERVER_JSON_FILE}" ]; then
        # When running in Desktop mode, no user is created
        # so we have to import servers anonymously
        if [ "${PGADMIN_CONFIG_SERVER_MODE}" = "False" ]; then
            /usr/local/bin/python /pgadmin4/setup.py --load-servers "${PGADMIN_SERVER_JSON_FILE}"
        else
            /usr/local/bin/python /pgadmin4/setup.py --load-servers "${PGADMIN_SERVER_JSON_FILE}" --user ${PGADMIN_DEFAULT_EMAIL}
        fi
    fi
fi

# Start Postfix to handle password resets etc.
if [ -z ${PGADMIN_DISABLE_POSTFIX} ]; then
    sudo /usr/sbin/postfix start
fi

# Get the session timeout from the pgAdmin config. We'll use this (in seconds)
# to define the Gunicorn worker timeout
TIMEOUT=$(cd /pgadmin4 && python -c 'import config; print(config.SESSION_EXPIRATION_TIME * 60 * 60 * 24)')

# NOTE: currently pgadmin can run only with 1 worker due to sessions implementation
# Using --threads to have multi-threaded single-process worker

if [ ! -z ${PGADMIN_ENABLE_TLS} ]; then
    exec gunicorn --timeout ${TIMEOUT} --bind ${PGADMIN_LISTEN_ADDRESS:-[::]}:${PGADMIN_LISTEN_PORT:-443} -w 1 --threads ${GUNICORN_THREADS:-25} --access-logfile ${GUNICORN_ACCESS_LOGFILE:--} --keyfile /certs/server.key --certfile /certs/server.cert -c gunicorn_config.py run_pgadmin:app
else
    exec gunicorn --timeout ${TIMEOUT} --bind ${PGADMIN_LISTEN_ADDRESS:-[::]}:${PGADMIN_LISTEN_PORT:-80} -w 1 --threads ${GUNICORN_THREADS:-25} --access-logfile ${GUNICORN_ACCESS_LOGFILE:--} -c gunicorn_config.py run_pgadmin:app
fi