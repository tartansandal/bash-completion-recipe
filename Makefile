.PHONY: build install uninstall

build:
	conda build .

install:
	conda install --use-local --yes --force-reinstall bash-completion
