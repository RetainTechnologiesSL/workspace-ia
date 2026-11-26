.PHONY: setup projects project

# Full workspace setup: clone all projects
setup: projects

# Clone or update all projects
projects:
	@./scripts/clone-projects.sh

# Clone or update a single project: make project NAME=devx
project:
	@./scripts/clone-projects.sh "$(NAME)"
