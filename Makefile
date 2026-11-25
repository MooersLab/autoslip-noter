# Makefile for autoslip-noter
# Test and byte-compile the bridge between autoslip-roam and org-noter.

# ==============================================================================
# Configuration
# ==============================================================================

# Emacs executable
EMACS ?= emacs

# Package files
PACKAGE = autoslip-noter.el
TEST_FILE = test-autoslip-noter.el

# Where the dependencies live.
# straight.el build directory. Packages here have unversioned directory names.
STRAIGHT_BUILD_DIR ?= $(HOME)/minimal-emacs.d/var/straight/build
# package.el directories. Packages here have versioned directory names.
CUSTOM_PACKAGE_DIR ?= ~/e30fewpackages/elpa
STANDARD_PACKAGE_DIR ?= ~/.emacs.d/elpa
# Local checkout of autoslip-roam. It is preferred over an installed copy,
# so that the two packages can be developed side by side.
AUTOSLIP_ROAM_DIR ?= ../autoslip-roam

# ==============================================================================
# Auto-detect Dependencies
# ==============================================================================

# find-dep: look for package $(1) in the straight build directory first,
# then for a versioned directory (for example org-roam-2.2.2) in the elpa
# directories.
find-dep = $(firstword $(wildcard $(STRAIGHT_BUILD_DIR)/$(1)) \
  $(shell find $(CUSTOM_PACKAGE_DIR) $(STANDARD_PACKAGE_DIR) -maxdepth 1 -type d -name "$(1)-[0-9]*" 2>/dev/null | head -1))

AUTOSLIP_ROAM_PATH := $(firstword $(wildcard $(AUTOSLIP_ROAM_DIR)) $(call find-dep,autoslip-roam))
ORG_ROAM_PATH := $(call find-dep,org-roam)
ORG_NOTER_PATH := $(call find-dep,org-noter)

# Required packages are checked by check-deps. Optional ones are added to
# the load path when they are found.
OPTIONAL_DEPS = org transient compat cond-let llama seq dash s f emacsql magit-section
OPTIONAL_PATHS := $(foreach dep,$(OPTIONAL_DEPS),$(call find-dep,$(dep)))

LOAD_PATH = -L . $(foreach dir,$(OPTIONAL_PATHS) $(ORG_ROAM_PATH) $(ORG_NOTER_PATH) $(AUTOSLIP_ROAM_PATH),-L $(dir))

# Batch mode flags
BATCH_FLAGS = -Q --batch $(LOAD_PATH)

# ==============================================================================
# Targets
# ==============================================================================

.PHONY: all test test-batch test-verbose test-specific check-deps compile \
        clean help list-tests

all: compile

check-deps: ## Check that the required dependencies are available
	@echo "Checking dependencies..."
	@if [ -z "$(AUTOSLIP_ROAM_PATH)" ]; then \
		echo "ERROR: autoslip-roam not found"; \
		echo "  Set AUTOSLIP_ROAM_DIR (now: $(AUTOSLIP_ROAM_DIR))"; \
		exit 1; \
	else \
		echo "✓ autoslip-roam: $(AUTOSLIP_ROAM_PATH)"; \
	fi
	@if [ -z "$(ORG_ROAM_PATH)" ]; then \
		echo "ERROR: org-roam not found"; \
		echo "  Set STRAIGHT_BUILD_DIR (now: $(STRAIGHT_BUILD_DIR))"; \
		exit 1; \
	else \
		echo "✓ org-roam: $(ORG_ROAM_PATH)"; \
	fi
	@if [ -z "$(ORG_NOTER_PATH)" ]; then \
		echo "ERROR: org-noter not found"; \
		echo "  Set STRAIGHT_BUILD_DIR (now: $(STRAIGHT_BUILD_DIR))"; \
		exit 1; \
	else \
		echo "✓ org-noter: $(ORG_NOTER_PATH)"; \
	fi
	@for dir in $(OPTIONAL_PATHS); do echo "✓ $$dir"; done
	@echo "Dependency check complete."

test: check-deps test-batch ## Run all tests (default test target)

test-batch: ## Run all tests in batch mode
	@echo "Running all tests..."
	$(EMACS) $(BATCH_FLAGS) \
		-l ert \
		-l $(TEST_FILE) \
		-f ert-run-tests-batch-and-exit

test-verbose: ## Run all tests and show the messages of each test
	$(EMACS) $(BATCH_FLAGS) \
		-l ert \
		-l $(TEST_FILE) \
		--eval '(let ((ert-batch-print-level 10) (ert-batch-print-length 120)) (ert-run-tests-batch-and-exit))'

test-specific: ## Run one test (use TEST=test-name)
	@if [ -z "$(TEST)" ]; then \
		echo "Usage: make test-specific TEST=test-autoslip-noter-creates-linked-note"; \
		exit 1; \
	fi
	$(EMACS) $(BATCH_FLAGS) \
		-l ert \
		-l $(TEST_FILE) \
		--eval '(ert-run-tests-batch-and-exit "$(TEST)")'

list-tests: ## List the names of the tests
	@grep -o '(ert-deftest [^ ]*' $(TEST_FILE) | sed 's/(ert-deftest //'

compile: check-deps ## Byte-compile the package
	$(EMACS) $(BATCH_FLAGS) -f batch-byte-compile $(PACKAGE)

clean: ## Remove byte-compiled files
	rm -f *.elc

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*## "} {printf "  %-16s %s\n", $$1, $$2}'
