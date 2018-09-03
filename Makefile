NAME := certificate_checker
PKG := github.com/spring-media/$(NAME)

VERSION ?= $(shell cat VERSION.txt)
REGION ?= eu-central-1
S3_BUCKET := tf-$(NAME)-deployment-$(REGION)

# Set an output prefix, which is the local directory if not specified
PREFIX?=$(shell pwd)
# Set the build dir, where built cross-compiled binaries will be output
BUILDDIR := $(PREFIX)/bin
FUNCDIR := func

all: clean build fmt lint test staticcheck vet

.PHONY: build
build: ## Builds static executables
	@echo "+ $@"
	@for dir in `ls $(FUNCDIR)`; do \
		CGO_ENABLED=0 go build -o $(BUILDDIR)/$$dir $(PKG)/$(FUNCDIR)/$$dir; \
	done

.PHONY: fmt
fmt: ## Verifies all files have men `gofmt`ed
	@echo "+ $@"
	@gofmt -s -l . | grep -v '.pb.go:' | grep -v vendor | tee /dev/stderr

.PHONY: lint
lint: ## Verifies `golint` passes
	@echo "+ $@"
	@golint ./... | grep -v '.pb.go:' | grep -v vendor | tee /dev/stderr

.PHONY: vet
vet: ## Verifies `go vet` passes
	@echo "+ $@"
	@go vet $(shell go list ./... | grep -v vendor) | grep -v '.pb.go:' | tee /dev/stderr

.PHONY: staticcheck
staticcheck: ## Verifies `staticcheck` passes
	@echo "+ $@"
	@staticcheck $(shell go list ./... | grep -v vendor) | grep -v '.pb.go:' | tee /dev/stderr

.PHONY: test
test: ## Runs the go tests
	@echo "+ $@"
	go test -v $(shell go list ./... | grep -v vendor)

.PHONY: cover
cover: ## Runs go test with coverage
	@echo "" > coverage.txt
	@for d in $(shell go list ./... | grep -v vendor); do \
		go test -race -coverprofile=profile.out -covermode=atomic "$$d"; \
		if [ -f profile.out ]; then \
			cat profile.out >> coverage.txt; \
			rm profile.out; \
		fi; \
	done;

.PHONY: release
release: ## Builds cross-compiled functions
	@echo "+ $@"
	@for dir in `ls $(FUNCDIR)`; do \
		GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build \
		-o $(BUILDDIR)/$$dir -a $(PKG)/$(FUNCDIR)/$$dir; \
	done

.PHONY: s3-init
s3-init: ## Creates AWS S3 bucket for deployments
	@echo "+ $@"
	@aws s3api create-bucket \
	--bucket=$(S3_BUCKET) \
	--create-bucket-configuration LocationConstraint=$(REGION) \
	--region=$(REGION)

.PHONY: s3-destroy
s3-destroy: ## Removes AWS S3 bucket including all deployments
	@echo "+ $@"
	@echo s3://$(S3_BUCKET)
	@aws s3 rb s3://$(S3_BUCKET) --force

.PHONY: package
package: release ## Creates and uploads S3 deployment packages for all functions
	@echo "+ $@"
	@for dir in `ls $(FUNCDIR)`; do \
		zip -j $(BUILDDIR)/$$dir.zip bin/$$dir; \
		aws s3 cp $(BUILDDIR)/$$dir.zip s3://$(S3_BUCKET)/$(VERSION)/$$dir.zip --region=$(REGION); \
	done

.PHONY: init
init: ## Initialize Terraform working directory
	@echo "+ $@"
	@cd terraform && terraform init

.PHONY: plan
plan: ## Generate and show a Terraform execution plan
	@echo "+ $@"
	@cd terraform && terraform plan \
	-var version=$(VERSION) \
	-var region=$(REGION) \
	-var s3_bucket=$(S3_BUCKET)

.PHONY: validate
validate: ## Validates the Terraform files
	@echo "+ $@"
	@cd terraform && terraform validate \
	-var version=$(VERSION) \
	-var region=$(REGION) \
	-var s3_bucket=$(S3_BUCKET)

.PHONY: deploy
deploy: ## Builds or changes infrastructure using Terraform
	@echo "+ $@"
	@cd terraform && terraform apply \
	-var version=$(VERSION) \
	-var region=$(REGION) \
	-var s3_bucket=$(S3_BUCKET)

.PHONY: destroy
destroy: ## Destroy Terraform-managed infrastructure
	@echo "+ $@"
	@cd terraform && terraform destroy \
	-var version=$(VERSION) \
	-var region=$(REGION) \
	-var s3_bucket=$(S3_BUCKET)

.PHONY: clean
clean: ## Cleanup any build binaries or packages
	@echo "+ $@"
	$(RM) $(NAME)
	$(RM) -r $(BUILDDIR)
	@for dir in `ls $(FUNCDIR)`; do \
		$(RM) $$dir ; \
	done	

.PHONY: help
help: ## Display this help screen
	@grep -E '^[0-9a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'	