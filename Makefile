# no buildin rules and variables
MAKEFLAGS =+ -rR --warn-undefined-variables

.PHONY: composer-install composer-update phpstan cs-fixer examples docker run

CONFLUENT_VERSION ?= latest
CONFLUENT_NETWORK_SUBNET ?= 192.168.104.0/24
SCHEMA_REGISTRY_IPV4 ?= 192.168.104.103
KAFKA_BROKER_IPV4 ?= 192.168.104.102
ZOOKEEPER_IPV4 ?= 192.168.104.101
COMPOSER ?= bin/composer.phar
COMPOSER_VERSION ?= 2.0.4
PHP ?= bin/php
PHP_VERSION ?= 7.3
XDEBUG_VERSION ?= 2.9.8
export

docker:
	docker build \
	  --build-arg PHP_VERSION=$(PHP_VERSION) \
	  --build-arg XDEBUG_VERSION=$(XDEBUG_VERSION) \
	  -t avro-serializer-php:$(PHP_VERSION) \
	  -f Dockerfile \
	  .

composer-install:
	PHP_VERSION=$(PHP_VERSION) $(PHP) $(COMPOSER) install --no-interaction --no-progress --no-scripts --prefer-stable

composer-update:
	PHP_VERSION=$(PHP_VERSION) $(PHP) $(COMPOSER) update --no-interaction --no-progress --no-scripts --prefer-stable

phpstan:
	PHP_VERSION=$(PHP_VERSION) $(PHP) vendor/bin/phpstan.phar analyse

cs-fixer:
	PHP_VERSION=$(PHP_VERSION) $(PHP) bin/php-cs-fixer.phar fix --config=.php_cs.dist --diff -v --dry-run \
	  --path-mode=intersection --allow-risky=yes src test

cs-fixer-modify:
	PHP_VERSION=$(PHP_VERSION) $(PHP) bin/php-cs-fixer.phar fix --config=.php_cs.dist --diff -v \
	  --path-mode=intersection --allow-risky=yes src test

phpunit:
	PHP_VERSION=$(PHP_VERSION) $(PHP) vendor/bin/phpunit --exclude-group integration

phpunit-integration:
	PHP_VERSION=$(PHP_VERSION) $(PHP) vendor/bin/phpunit --group integration

coverage:
	mkdir -p build
	PHP_VERSION=$(PHP_VERSION) $(PHP) vendor/bin/phpunit --exclude-group integration \
	  --coverage-clover=build/coverage.clover --coverage-text
	PHP_VERSION=$(PHP_VERSION) $(PHP) bin/ocular.phar code-coverage:upload --format=php-clover \
	  --repository=g/flix-tech/avro-serde-php build/coverage.clover

run:
	PHP_VERSION=$(PHP_VERSION) $(PHP) $(ARGS)

ci-local: cs-fixer phpstan phpunit

examples:
	PHP_VERSION=$(PHP_VERSION) $(PHP) examples/*

install-phars:
	curl http://cs.sensiolabs.org/download/php-cs-fixer-v2.phar -o bin/php-cs-fixer.phar -LR -z bin/php-cs-fixer.phar
	chmod a+x bin/php-cs-fixer.phar
	curl https://scrutinizer-ci.com/ocular.phar -o bin/ocular.phar -LR -z bin/ocular.phar
	chmod a+x bin/ocular.phar
	curl https://getcomposer.org/download/$(COMPOSER_VERSION)/composer.phar -o bin/composer.phar -LR -z bin/composer.phar
	chmod a+x bin/composer.phar

platform:
	docker-compose down
	docker-compose up -d
	bin/wait-for-all.sh

clean:
	rm -rf build
	docker-compose down

benchmark:
	docker-compose down
	docker-compose up -d
	bin/wait-for-all.sh
	PHP_VERSION=$(PHP_VERSION) $(PHP) ./vendor/bin/phpbench run benchmarks/AvroEncodingBench.php --report=aggregate --retry-threshold=5
	docker-compose down
