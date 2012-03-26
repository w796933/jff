#!/bin/sh

set -e -x

SCRIPT_DIR=$(readlink -f $(dirname $0))
. $SCRIPT_DIR/lib.sh


#########################################################################################
ensure_service_started postgresql postgres

f=/etc/dbconfig-common/redmine/instances/default.conf
tmpl=$SCRIPT_DIR$f
dummy='@@REDIMINE_DB_PASSWORD@@'
isnew=
set +x
parse_password_by_pattern "dbc_dbpass\\s*=\\s*['\"]([^'\"]+)" $f $dummy db_passwd isnew
[ ! "$isnew" ] || pg_set_role_password redmine "$db_passwd"

substitude_template "$tmpl" "$f" 600 root:root CONF_CHANGED -e "s/$dummy/$db_passwd/"

f=/etc/redmine/default/database.yml
tmpl=$SCRIPT_DIR$f
dummy='@@REDIMINE_DB_PASSWORD@@'
substitude_template "$tmpl" "$f" 640 root:www-data CONF_CHANGED -e "s/$dummy/$db_passwd/"
set -x
#########################################################################################


cmp_dir $SCRIPT_DIR/etc/redmine /etc/redmine --exclude database.yml --exclude session.yml || {
    overwrite_dir $SCRIPT_DIR/etc/redmine /etc/redmine --exclude database.yml --exclude session.yml
    CONF_CHANGED=1
}


ensure_mode_user_group /etc/dbconfig-common                 755 root root
ensure_mode_user_group /etc/dbconfig-common/redmine         755 root root
ensure_mode_user_group /etc/dbconfig-common/redmine/instances   755 root root
ensure_mode_user_group /etc/dbconfig-common/redmine/instances/default.conf  600 root root

ensure_mode_user_group /etc/redmine                         755 root root
ensure_mode_user_group /etc/redmine/default                 755 www-data www-data
ensure_mode_user_group /etc/redmine/default/database.yml    640 root www-data
ensure_mode_user_group /etc/redmine/default/session.yml     640 root www-data



[ -z "$CONF_CHANGED" ] || service apache2 restart

ensure_service_started apache2 apache2

