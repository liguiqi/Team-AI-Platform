SHELL := /bin/bash

.PHONY: init up down restart bootstrap render-auth sync-casdoor-auth sync-casdoor-providers sync-provider-models install-model-sync-cron sync-librechat-models health smoke smoke-zhipu smoke-deepseek smoke-aliyun backup restore doctor verify-no-secrets

init:
	bash scripts/init-local.sh

up:
	bash scripts/up.sh

down:
	bash scripts/down.sh

restart:
	bash scripts/restart.sh

bootstrap:
	bash scripts/bootstrap-new-api.sh

render-auth:
	bash scripts/render-casdoor-config.sh

sync-casdoor-auth:
	bash scripts/sync-casdoor-auth-config.sh

sync-casdoor-providers:
	bash scripts/sync-casdoor-providers.sh

sync-provider-models:
	bash scripts/sync-provider-models.sh

install-model-sync-cron:
	bash scripts/install-model-sync-cron.sh

sync-librechat-models:
	bash scripts/sync-librechat-models.sh

health:
	bash scripts/healthcheck.sh

smoke:
	bash scripts/smoke-test.sh

smoke-zhipu:
	bash scripts/smoke-test-zhipu.sh

smoke-deepseek:
	bash scripts/smoke-test-deepseek.sh

smoke-aliyun:
	bash scripts/smoke-test-aliyun.sh

backup:
	bash scripts/backup.sh

restore:
	bash scripts/restore.sh

doctor:
	bash scripts/doctor.sh

verify-no-secrets:
	bash scripts/verify-no-secrets.sh
