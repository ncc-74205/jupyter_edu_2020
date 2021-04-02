#mysqld --host=127.0.0.1 --port=3306 --skip-grant-tables &
/usr/local/bin/start.sh mysqld --init-file=/home/jovyan/mysql-init &

export PGDATA=/home/jovyan/pgdata
mkdir $PGDATA
pg_ctl initdb
pg_ctl start
psql -c "create database DEMO;" postgres

/usr/local/bin/start.sh jupyter lab --NotebookApp.token='' $*
#/usr/local/bin/start.sh jupyter notebook --NotebookApp.token='' $*
