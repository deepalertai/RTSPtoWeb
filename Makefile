APP=RTSPtoWeb
SERVER_FLAGS ?= -config config.json

P="\\033[34m[+]\\033[0m"

# create preprod branch release-[0-9]+.[0-9]+.[0-9]+
# get user input and confirmation to push the branch, triggering the preprod workflow
preprod-release:
	@git fetch --tags
	@current_branch=$$(git rev-parse --abbrev-ref HEAD); \
	if [ "$$current_branch" != "dev" ]; then \
		echo "Error: Must be on 'dev' branch (currently on '$$current_branch')"; \
		exit 1; \
	fi; \
	latest_tag=$$(git tag -l 'v[0-9]*' | sort -V | tail -n1); \
	if [ -z "$$latest_tag" ]; then \
		default_version="0.0.1"; \
	else \
		default_version=$$(echo $$latest_tag | sed 's/^v//' | awk -F. '{printf "%d.%d.%d", $$1, $$2, $$3+1}'); \
	fi; \
	read -p "Use $$default_version or enter release version: " input_version; \
	version=$${input_version:-$$default_version}; \
	branch="release-$$version"; \
	git checkout -b $$branch; \
	echo "Created branch $$branch"; \
	read -p "ENTER to push $$branch: " _; \
	git push -u origin $$branch

# create a tag based on release branch version
# confirm with the user and push the tag, triggering the prod workflow
prod-release:
	@current_branch=$$(git rev-parse --abbrev-ref HEAD); \
	case "$$current_branch" in \
		release-[0-9]*.[0-9]*.[0-9]*) ;; \
		*) echo "Error: Must be on a release branch (got '$$current_branch')"; exit 1 ;; \
	esac; \
	version=$$(echo $$current_branch | sed 's/^release-/v/'); \
	read -p "ENTER to create tag: $$version (Ctrl+C to abort) " _; \
	git tag -a $$version -m ""; \
	git push origin $$version

# create a hotfix tag based on the prod release tag
hotfix-release:
	@current_branch=$$(git rev-parse --abbrev-ref HEAD); \
	case "$$current_branch" in \
		release-[0-9]*.[0-9]*.[0-9]*) ;; \
		*) echo "Error: Must be on a release branch (got '$$current_branch')"; exit 1 ;; \
	esac; \
	version=$$(echo $$current_branch | sed 's/^release-/v/'); \
	if ! git rev-parse "$$version" >/dev/null 2>&1; then \
		echo "Error: Release tag '$$version' does not exist. Run prod-release first."; \
		exit 1; \
	fi; \
	tag="$$version-hotfix"; \
	n=1; \
	while git rev-parse "$$tag" >/dev/null 2>&1; do \
		n=$$((n + 1)); \
		tag="$$version-hotfix$$n"; \
	done; \
	read -p "ENTER to create hotfix tag: $$tag (Ctrl+C to abort) " _; \
	git tag -a "$$tag" -m ""; \
	git push origin "$$tag"

build:
	@echo "$(P) build"
	GO111MODULE=on go build *.go

run:
	@echo "$(P) run"
	GO111MODULE=on go run *.go

serve:
	@$(MAKE) server

server:
	@echo "$(P) server $(SERVER_FLAGS)"
	./${APP} $(SERVER_FLAGS)

test:
	@echo "$(P) test"
	bash test.curl
	bash test_multi.curl

lint:
	@echo "$(P) lint"
	go vet

.NOTPARALLEL:

.PHONY: build run server test lint prod-release preprod-release
