SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

source "$SCRIPT_DIR/util.sh"
log "Invoking 'configure_pgadmin' Function" "init-dbs_script"
configure_pgadmin

log "Loading Servers Into pgadmin" "init-dbs_script"
python $SCRIPT_DIR/pgadmin4/setup.py --load-servers $CUSTOM_SERVER_JSON_FILE --user $PGADMIN_DEFAULT_EMAIL