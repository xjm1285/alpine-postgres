#!/usr/bin/with-contenv sh

chown -R postgres "$PGDATA"

if [ -z "$(ls -A "$PGDATA")" ]; then
    gosu postgres initdb
    sed -ri "s/^#(listen_addresses\s*=\s*)\S+/\1'*'/" "$PGDATA"/postgresql.conf

    : ${POSTGRES_USER:="postgres"}
    : ${POSTGRES_DB:="postgres"}

    # internal start of server in order to allow set-up using psql-client
    # does not listen on TCP/IP and waits until start finishes
    gosu postgres pg_ctl -D "$PGDATA" \
        -o "-c listen_addresses=''" \
        -w start
    echo
    
    if [ "$POSTGRES_DB" != 'postgres' ]; then
      createSql="CREATE DATABASE $POSTGRES_DB;"
      #echo $createSql | gosu postgres postgres --single -jE
      gosu postgres psql -c "$createSql"
      echo
    fi
    
    if [ "$POSTGRES_ADMIN_PASSWORD" ]; then
      admin_pass="PASSWORD '$POSTGRES_ADMIN_PASSWORD'"
      adminSql="ALTER USER postgres WITH SUPERUSER $admin_pass;"
      #echo $adminSql | gosu postgres postgres --single -jE
      gosu postgres psql -d postgres -c "$adminSql"
      echo
      { echo; echo "host all postgres 0.0.0.0/0 md5"; } >> "$PGDATA"/pg_hba.conf
    else
      echo "==============================="
      echo "!!! Use \$POSTGRES_ADMIN_PASSWORD env var to secure your database !!!"
      echo "==============================="
    fi
    echo
    
    if [ "$POSTGRES_USER_PASSWORD" ]; then
      user_pass="PASSWORD '$POSTGRES_USER_PASSWORD'"
      authMethod=md5
    else
      echo "==============================="
      echo "!!! Use \$POSTGRES_USER_PASSWORD env var to secure your database !!!"
      echo "==============================="
      user_pass=
      authMethod=trust
    fi
    echo


    if [ "$POSTGRES_USER" != 'postgres' ]; then
      gosu postgres createuser --createdb --no-createrole --no-superuser --username=postgres $POSTGRES_USER
      userSql="ALTER USER $POSTGRES_USER WITH $user_pass;"
      #echo $userSql | gosu postgres postgres --single -jE
      gosu postgres psql -d postgres -c "$userSql"
      { echo; echo "host all $POSTGRES_USER 0.0.0.0/0 $authMethod"; } >> "$PGDATA"/pg_hba.conf
      echo
    fi

    echo
    for f in /docker-entrypoint-initdb.d/*; do
        case "$f" in
            *.sh)  echo "$0: running $f"; . "$f" ;;
            *.sql) echo "$0: running $f"; psql --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" < "$f" && echo ;;
            *)     echo "$0: ignoring $f" ;;
        esac
        echo
    done

    gosu postgres pg_ctl -D "$PGDATA" -m fast -w stop

fi

#exec gosu postgres postgres
