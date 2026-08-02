INTERPRETER = ./awkward
LIB_DIR = lib
TEST_DIR = tests
DOCS_DIR = docs
DOCS_GEN = scripts/generate-docs.sh
DOCS_OUT = $(DOCS_DIR)/
PREFIX = /usr/local

.PHONY: all test install docs clean

all: test

test:
	@echo "Running tests..."
	@bash $(TEST_DIR)/run_tests.sh

install:
	@echo "Installing awkward..."
	@mkdir -p $(PREFIX)/lib/awkward
	@cp -r $(LIB_DIR)/. $(PREFIX)/lib/awkward/
	@cp $(INTERPRETER) $(PREFIX)/bin/awkward
	@chmod +x $(PREFIX)/bin/awkward
	@echo "Installed to $(PREFIX)/bin/awkward (library: $(PREFIX)/lib/awkward)"

docs:
	@echo "Generating documentation..."
	@mkdir -p $(DOCS_DIR)
	@bash $(DOCS_GEN)
	@echo "Documentation generated at $(DOCS_OUT)"

clean:
	@echo "🧹 Cleaning..."
	@rm -f $(DOCS_OUT)
	@echo "Clean complete"
