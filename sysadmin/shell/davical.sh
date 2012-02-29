#!/bin/sh

set -e -x

SCRIPT_DIR=$(readlink -f $(dirname $0))
. $SCRIPT_DIR/lib.sh

#### modified from /usr/share/davical/dba/create-database.sh
db_users() {
  su postgres -c 'psql -qXAt -c "SELECT usename FROM pg_user;" template1'
}

create_db_user() {
  if ! db_users | grep "^${1}$" >/dev/null ; then
    su postgres -c "psql -qXAt -c 'CREATE USER ${1} NOCREATEDB NOCREATEROLE;' template1"
  fi
}

#############################################################

ensure_service_started postgresql postgres

create_db_user davical_dba
create_db_user davical_app

set +x
f=/etc/davical/administration.yml
dummy=@@DAVICAL_DBA_PASSWORD@@
isnew=
davical_dba_passwd=$(parse_password_by_pattern '^\s*admin_db_pass\s*:\s*(\S+)' $f $dummy isnew)
[ ! "$isnew" ] || set_postgresql_role_password davical_dba "$davical_dba_passwd"
substitude_template "$SCRIPT_DIR$f" "$f" 640 postgres:postgres CONF_CHANGED -e "s/$dummy/$davical_dba_passwd/"

f=/etc/davical/config.php
dummy=@@DAVICAL_APP_PASSWORD@@
isnew=
davical_app_passwd=$(parse_password_by_pattern "^\\s*\\$.*pg_connect.*\\spassword=([^'\"]+)" $f $dummy isnew)
[ ! "$isnew" ] || set_postgresql_role_password davical_app "$davical_app_passwd"
substitude_template "$SCRIPT_DIR$f" "$f" 640 root:www-data CONF_CHANGED -e "s/$dummy/$davical_app_passwd/"
set -x

cmp_dir $SCRIPT_DIR/etc/davical /etc/davical --exclude administration.yml --exclude config.php || {
    overwrite_dir $SCRIPT_DIR/etc/davical /etc/davical --exclude administration.yml --exclude config.php
    CONF_CHANGED=1
}

ensure_mode_user_group /etc/davical/administration.yml      640 postgres postgres
ensure_mode_user_group /etc/davical/config.php              640 root www-data

[ -z "$CONF_CHANGED" ] || service apache2 restart

#############################################################
#### must create db users and copy configuration files first, see above
su postgres -c 'psql -c "" davical' 2>/dev/null || {
    su postgres -c /usr/share/davical/dba/create-database.sh
}

