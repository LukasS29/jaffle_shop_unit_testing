init:
	poetry run docker run --name jaffel_shop_db -p 5432:5432 -e POSTGRES_USER=jaffeler -e POSTGRES_PASSWORD=1234supersafe -e POSTGRES_DB=jaffel_shop -d postgres

configure:
	docker run --rm --link jaffel_shop_db:postgres --volume `pwd`/scripts:/scripts -e PGPASSWORD=1234supersafe postgres psql --host postgres --username jaffeler -d jaffel_shop --file /scripts/setup_postgres.sql
