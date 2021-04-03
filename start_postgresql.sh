export PGDATA=/home/jovyan/postgresql/pgdata
mkdir $PGDATA
pg_ctl initdb
pg_ctl start
psql -c "create database edu;" postgres
