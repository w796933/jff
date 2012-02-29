#!/bin/sh

export BACKUP_DIR=${BACKUP_DIR:-/root/cfg-bak/`date +%Y%m%d-%H%M%S`}
[ `expr index "$BACKUP_DIR" /` -eq 1 ] || {
    echo "BACKUP_DIR must be absolute path!" >&2
    exit 1
}


save_etc () {
    local msg="$1"

    dpkg -l > /tmp/dpkg-list.$$
    cmp -s /tmp/dpkg-list.$$ /etc/dpkg-list.txt || cp /tmp/dpkg-list.$$ /etc/dpkg-list.txt

    ! etckeeper unclean || etckeeper commit "$msg"
}


ensure_mode_user_group () {
    local file="$1" mode="$2" user="$3" group="$4"

    [ "$1" -a "$2" -a "$3" -a "$4" ] || return 1

    [ -e "$file" ] || {
        echo "[WARN] ensure_mode_user_group(): file not exist - $file"
        return 0
    }

    [ x`stat --printf=%a "$file"` = x$mode ] || chmod $mode "$file"
    [ x`stat --printf=%U "$file"` = x$user -a x`stat --printf=%G "$file"` = x$group ] ||
        chown $user:$group "$file"
}


cmp_file () {
    local src="$1" dst="$2"

    [ -e "$dst" ] && cmp -s "$src" "$dst"
}


cmp_dir () {
    local src="$1" dst="$2"

    [ -d "$dst" ] && diff -aurNq "$@" >/dev/null
}


overwrite_file () {
    local src="$1" dst="$2" bdir="$BACKUP_DIR/`dirname $2`"

    mkdir -p `dirname "$dst"` "$bdir"
    rsync -b --backup-dir "$bdir" -c -av --no-owner --no-group "$src" "$dst"
}


overwrite_dir () {
    local src="$1" dst="$2" bdir="$BACKUP_DIR/$2"

    mkdir -p `dirname "$dst"` "$bdir"
    shift 2
    rsync -b --backup-dir "$bdir" -c -avr --delete --no-owner --no-group "$src/" "$dst" "$@"
}


overwrite_dir_ignore_extra () {
    local src="$1" dst="$2" bdir="$BACKUP_DIR/$2"

    mkdir -p `dirname "$dst"` "$bdir"
    shift 2
    rsync -b --backup-dir "$bdir" -c -avr --no-owner --no-group "$src/" "$dst" "$@"
}


sync_file () {
    cmp_file "$@" || overwrite_file "$@"
}


sync_dir () {
    cmp_dir "$@" || overwrite_dir "$@"
}


file_newer () {
    [ "$1" -a "$2" -a -e "$1" -a -e "$2" -a \( "$1" -nt "$2" \) ]
}

file_older () {
    [ "$1" -a "$2" -a -e "$1" -a -e "$2" -a \( "$1" -ot "$2" \) ]
}

ensure_service_started () {
    local name="$1" cmd="$2"

    [ "$cmd" ] || cmd="$name"

    [ "`pidof $cmd`" ] || service "$name" start
}

run_psql () {
    {
        echo '\set ON_ERROR_STOP'
        echo "$@"
    } | su -c "psql -w -X -1 -f -" postgres
}

set_postgresql_role_password () {
    local role="$1" passwd="$2"

    run_psql "ALTER ROLE $role WITH ENCRYPTED PASSWORD '$passwd'"
}

capture_match () {
    local pattern="$1" file="$2" flags="$3"

    perl -ne "if ( m{$pattern}$flags ) { print \"\$1\"; exit(0); }" "$file"
}

parse_password_by_pattern () {
    local pattern="$1" file="$2" dummy="$3" newflag="$4" passwd=

    [ ! -e "$file" ] || {
        passwd=$(capture_match "$pattern" "$file")
        [ "$passwd" != "$dummy" ] || passwd=
    }

    [ "$passwd" ] || {
        passwd=`pwgen -cnys 24 1`
        [ -z "$newflag" ] || eval $newflag=1
    }

    echo "$passwd"
}

substitude_template () {
    local tmpl="$1" file="$2" mode="$3" og="$4" flag="$5"

    shift 5
    sed "$@" $tmpl | diff -q $file - >/dev/null || {
        sed "$@" $tmpl > $file
        chmod $mode $file
        chown $og $file
        eval $flag=1
    }
}


