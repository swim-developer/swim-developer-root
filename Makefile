.DEFAULT_GOAL := help

.PHONY: help install

help:
	@echo "Targets:"
	@echo "  install    Install parent POM to local Maven repository"
	@echo ""
	@echo "This is the Maven parent POM for all swim-developer projects."
	@echo "Run 'make install' once after cloning so other projects resolve the parent artifact."

install:
	./mvnw clean install -DskipTests
