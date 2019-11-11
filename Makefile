# aliases for maintaining this conda package

.PHONY: build install

build:
	conda build .

install:
	conda install --use-local --yes --force-reinstall bash-completion
