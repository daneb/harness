# The harness's own quality bar — the same one G2 would discover here.

SH = bin/harness lib/common.sh gates/*.sh adapters/*.sh tests/*.sh

lint:
	shellcheck $(SH)
	python3 -m py_compile lib/*.py

test:
	bash tests/run.sh

.PHONY: lint test
