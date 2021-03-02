function log(){
    echo -e "\e[92m$(date +"%r")\e[0m: \e[4;32m$2\e[0m : >> $1"
}

function print_line(){
    echo -e "--------------------------"
}

function clean_docker(){
    # Only use this if you hate life and want to end it all.
    docker-compose down
    docker volume rm pgadmin-container_postgres pgadmin-container_pgadmin
    docker system prune -f
    docker rmi $(docker images --filter "dangling=true" -q)
}

function execute_sql(){
    log "PGPASSWORD=xxxx psql -h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USER" "execute_sql"
    PGPASSWORD=$POSTGRES_PASSWORD psql --host=$POSTGRES_HOST --port=$POSTGRES_PORT --username=$POSTGRES_USER --command="$1"
}

function list_databases(){
    PGPASSWORD=$POSTGRES_PASSWORD psql --host=$POSTGRES_HOST --port=$POSTGRES_PORT --username=$POSTGRES_USER -lqt
}

function database_exists(){
    if list_databases | cut -d \| -f 1 | grep -qw "$1" 
    then
        echo 0
    else
        echo 1
    fi
}

function get_db_index(){
    for i in "${!dbs[@]}"
    do 
        if [[ "${dbs[$i]}" = "$1" ]]
        then
            echo "${i}"
        fi 
    done
}

function configure_pgadmin(){
    if [ -f "/credentials/pgpassfile" ]
    then
        > /credentials/pgpassfile
    fi

    log "Configuring PGPASSFILE for Admin User: $POSTGRES_USER" "configure_pgadmin"
    echo "$POSTGRES_HOST:$POSTGRES_PORT:*:$POSTGRES_USER:$POSTGRES_PASSWORD" >> /credentials/pgpassfile

    for i in ${dbs[@]}
    do
        db_index="$(get_db_index $i)"
        user=${users[$db_index]}
        password=${passwords[$db_index]}
        
        log "Configuring PGPASSFILE for User='$user' on Database='$i'" "configure_pgadmin"
        echo "$POSTGRES_HOST:$POSTGRES_PORT:$i:$user:$password" >> /credentials/pgpassfile
    done

    log "Configuring PGAdmin4's 'servers.json' With Secret Credentials" "configure_pgadmin"
    sed -i "s/__username__/$POSTGRES_USER/g" /servers/servers.json
    sed -i "s/__host__/$POSTGRES_HOST/g" /servers/servers.json
    sed -i "s/__port__/$POSTGRES_PORT/g" /servers/servers.json
    
}