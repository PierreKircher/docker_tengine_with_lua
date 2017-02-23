NS = pierrekircher
VERSION ?= latest

REPO = tengine
NAME = tengine
INSTANCE = default

.PHONY: build push shell run start stop rm release

build:
	docker build -t $(NS)/$(REPO):$(VERSION) .

default: build
