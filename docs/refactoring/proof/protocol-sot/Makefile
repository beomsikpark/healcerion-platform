# HC protocol canonical header - proof of equivalence.
#
#   make            generate + verify (default)
#   make report     divergence report between the three original declarations
#   make generate   regenerate include/hc_protocol.h and vendored/ from the mirrors
#   make check      fail if the generated files are stale (this is the CI gate)
#   make verify     compile and run the layout proof
#   make clean

CC      ?= cc
CFLAGS  ?= -std=c11 -Wall -Wextra -Werror -O0 -g
PYTHON  ?= python3
BUILD   := build

GENERATED := include/hc_protocol.h compat_test.c \
             vendored/belle_header.h vendored/moana_header.h vendored/c500_header.h

.PHONY: all report generate check verify clean
all: check verify

report:
	@$(PYTHON) reconcile.py --report

generate:
	@$(PYTHON) reconcile.py --emit-header --emit-vendored --emit-compat

check: $(GENERATED)
	@$(PYTHON) reconcile.py --check

verify: $(BUILD)/verify_layout $(BUILD)/compat_test
	@$(BUILD)/verify_layout
	@echo
	@$(BUILD)/compat_test

$(BUILD)/verify_layout: verify_layout.c $(GENERATED) | $(BUILD)
	@$(CC) $(CFLAGS) -I. -o $@ $<

$(BUILD)/compat_test: compat_test.c $(GENERATED) | $(BUILD)
	@$(CC) $(CFLAGS) -I. -o $@ $<

$(BUILD):
	@mkdir -p $(BUILD)

clean:
	@rm -rf $(BUILD)
