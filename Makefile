.PHONY: build install uninstall

build:
	conda build .

install:
	conda install --use-local --yes bash-completion

uninstall:
	conda uninstall --yes bash-completion
