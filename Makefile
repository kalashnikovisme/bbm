.PHONY: install test lint run clean help

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

install: ## Install dependencies
	bundle install

test: ## Run tests
	bundle exec rspec

lint: ## Run linter
	bundle exec rubocop

lint-fix: ## Auto-fix linting issues
	bundle exec rubocop -A

run: ## Run the application
        bin/run

clean: ## Clean temporary files
	rm -rf tmp/ vendor/bundle .bundle

setup: ## Initial setup (install dependencies and create .env)
	bundle install
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo ".env file created. Please edit it with your credentials."; \
	else \
		echo ".env file already exists."; \
	fi

terraform-init: ## Initialize Terraform
	cd terraform && terraform init

terraform-plan: ## Plan Terraform deployment
	cd terraform && terraform plan

deploy: ## Apply Terraform deployment
	cd terraform && terraform apply -auto-approve -input=false

destroy: ## Destroy Terraform infrastructure
	cd terraform && terraform destroy

terraform-run: ## Full cycle: apply then destroy
	cd terraform && terraform apply -auto-approve && terraform destroy -auto-approve
