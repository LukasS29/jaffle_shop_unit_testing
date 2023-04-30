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

test_dbt_sad_vars_flag_only = '{\
	"is_e2e_test": true \
}'
test_dbt_sad_vars = '{\
	"is_e2e_test": true, \
	"${var}": "{{ ref(\"$(source)\") }}",\
}'
test\:single-sad:
	poetry run dbt --no-use-colors run --select +$(model) --vars $(test_dbt_sad_vars) --full-refresh --profiles-dir profiles/ && \
	poetry run dbt --no-use-colors test --select $(model) --vars $(test_dbt_sad_vars) --profiles-dir profiles/ \
	|| true

test\:sad:
	output_dir="/tmp/dbt_test_output" ; \
	mkdir -p $$output_dir ; \
	echo "> Seeding test data..." ; \
	poetry run dbt --no-use-colors seed --select seeds/tests/sad_path --vars $(test_dbt_sad_vars_flag_only) --full-refresh --profiles-dir profiles/ \
		| tee $$output_dir/seeds.txt \
		| grep 'identity provider\|URL' ; \
	for FILE in ./seeds/tests/sad_path/**/*.csv ; do \
		model_name=$$(basename $$(dirname $$FILE)) ; \
		test_name=$$(basename $$FILE .csv) ; \
		test_name_var=$${test_name%_vars_*} ; \
		test_name_source=$${test_name#*_vars_} ; \
		test_output=$$output_dir/$$model_name/$$test_name.txt; \
		mkdir -p $$(dirname $$test_output) ; \
		echo "> Asserting test fails for '$$model_name' with '$$test_name'..." ; \
		make test:single-sad model=$$model_name var=$$test_name_var source=$$test_name > $$test_output ; \
		cat $$test_output | grep -q "Failure in test $$test_name_source" \
		&& echo "\033[32mSUCCESS\033[0m" \
		|| { echo "\033[31mFAILED\033[0m"; echo "Full test output: $$test_output" ; exit 1 ; }  ; \
	done

test\:sad\:run:
	$(MAKE) -s test:sad
