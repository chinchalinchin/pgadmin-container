SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
SCRIPT_NAME="configure"
source "$SCRIPT_DIR/util.sh"

log "Invoking 'configure_pgadmin' Function" $SCRIPT_NAME
configure_pgadmin

log "Loading server group Into pgadmin" $SCRIPT_NAME
python $SCRIPT_DIR/pgadmin4/setup.py --load-servers $PGADMIN_SERVER_JSON_FILE --user $PGADMIN_DEFAULT_EMAIL