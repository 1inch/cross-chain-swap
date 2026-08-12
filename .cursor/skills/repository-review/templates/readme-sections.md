# README snippets

Four snippets, inserted independently. Take the body under each heading, not the heading itself — except in the skeleton, which is a whole file.

Shields.io escapes a literal hyphen as `--`, so `BUSL-1.1` becomes `BUSL--1.1` in the badge URL while `{{LICENSE_NAME}}` stays readable in the label.

---

## Snippet: badges

Goes directly under the README title, before the description.

[![CI](https://github.com/{{SLUG}}/actions/workflows/{{WORKFLOW_FILE}}/badge.svg)](https://github.com/{{SLUG}}/actions/workflows/{{WORKFLOW_FILE}}) [![License: {{LICENSE_NAME}}](https://img.shields.io/badge/License-{{LICENSE_BADGE}}-blue.svg)]({{LICENSE_PATH}}) [![Solidity {{SOLC_VERSION}}](https://img.shields.io/badge/solidity-{{SOLC_VERSION}}-363636.svg)](https://docs.soliditylang.org/)

---

## Snippet: repository structure

Goes after the protocol description and before the build instructions. One row per top-level directory that exists — do not list directories the repository does not have.

## Repository structure

| Path | Contents |
|---|---|
{{STRUCTURE_ROWS}}

---

## Snippet: build and test

Goes after the repository structure.

## Build and test

This project uses {{TOOLCHAIN_NAME}}, with solc pinned to {{SOLC_VERSION}} in {{TOOLCHAIN_CONFIG}}.

### Prerequisites

{{PREREQUISITES}}

### Build

```bash
{{INSTALL_COMMAND}}
{{BUILD_COMMAND}}
```

### Test

```bash
{{TEST_COMMAND}}
```

### Lint

```bash
{{LINT_COMMAND}}
```

---

## Snippet: whole README skeleton

Only when the repository has no README at all. The badges, structure and build sections above are filled in as normal; the description is the one part that cannot be derived from the file system.

# {{REPO_NAME}}

<!-- badges snippet -->

TODO(repository-review): describe the protocol in two or three sentences — what it does and which problem it solves for whom. This is the first thing a reader sees and the one part of the README that cannot be generated from the code.

<!-- repository structure snippet -->

<!-- build and test snippet -->

## Deployments

TODO(repository-review): list the deployed addresses per network, or link the file that records them.

## Documentation, audits and bug bounty

TODO(repository-review): link the protocol documentation, the audit reports and the bug bounty programme.

## License

{{LICENSE_NAME}}, see [{{LICENSE_PATH}}]({{LICENSE_PATH}}).
