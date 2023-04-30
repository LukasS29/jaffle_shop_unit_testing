.PHONY: test\:happy

init:
	poetry run docker run --name jaffel_shop_db -p 5432:5432 -e POSTGRES_USER=jaffeler -e POSTGRES_PASSWORD=1234supersafe -e POSTGRES_DB=jaffel_shop -d postgres

configure:
	docker run --rm --link jaffel_shop_db:postgres --volume `pwd`/scripts:/scripts -e PGPASSWORD=1234supersafe postgres psql --host postgres --username jaffeler -d jaffel_shop --file /scripts/setup_postgres.sql

build:
	poetry run dbt build --profiles-dir profiles/


test_happy_dir = ./seeds/tests/happy_path
test\:happy:
	for FOLDER in $(test_happy_dir)/* ; do \
		count=-1; \
		echo "\033[1mRunning test case $$(basename $$FOLDER)\033[0m "; \
		source_customers=$$(basename $$FOLDER)_input_raw_customers; \
		source_orders=$$(basename $$FOLDER)_input_raw_orders; \
		source_payments=$$(basename $$FOLDER)_input_raw_payments; \
		expected_outcome_customers=$$(basename $$FOLDER)_outcome_customers; \
		expected_outcome_orders=$$(basename $$FOLDER)_outcome_orders; \
		output=$$(dbt build --vars '{\
			"source_customers": "{{ ref(\"'$${source_customers}'\") }}",\
			"source_orders": "{{ ref(\"'$${source_orders}'\") }}",\
			"source_payments": "{{ ref(\"'$${source_payments}'\") }}",\
			"expected_outcome_customers": "{{ ref(\"'$${expected_outcome_customers}'\") }}",\
			"expected_outcome_orders": "{{ ref(\"'$${expected_outcome_orders}'\") }}",\
			"is_unit_test": true\
			}'\
			--profiles-dir profiles/ | grep -E 'ERROR|WARN|FAIL'| tee output.txt); \
		echo "$$output"; \
		count=$$(($$count + `echo "$$output" | wc -l`)); \
		if [ "$$count" -eq "0" ]; then \
			echo "\033[32mSUCCESS\033[0m"; \
		else \
			echo "\033[31mFAILURE ($$count errors)\033[0m"; \
		fi; \
		echo ""; \
	done

test\:happy\:run:
	$(MAKE) -s test:happy
