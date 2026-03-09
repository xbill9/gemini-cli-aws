# Gemini CLI AWS & Google Cloud Development

This repository contains automation scripts and configuration for cross-platform development across Amazon AWS and Google Cloud, with a focus on various Linux distributions.

## Overview

The repository provides a set of utility scripts to streamline the setup and maintenance of development environments on Amazon Linux 2023 and Debian-based systems.

## Automation Scripts

### Amazon Linux 2023 Update (`al2023-update`)
Updates the system packages and installs essential libraries.
```bash
./al2023-update
```

### Debian/Ubuntu Update (`debian-update`)
Updates the system package list, upgrades existing packages, and ensures Git is installed.
```bash
./debian-update
```

### Gemini CLI Update (`gemini-update`)
Installs or updates the `@google/gemini-cli` globally using npm and verifies the installed versions of Node.js and Gemini.
```bash
./gemini-update
```

### NVM & Node.js Update (`nvm-update`)
Installs NVM (Node Version Manager) and sets up Node.js version 25.
```bash
./nvm-update
```

## Environment Requirements

- **Operating Systems:** Amazon Linux 2023, Debian, Ubuntu.
- **Tools:** Node.js, npm, Git.

## Project Metadata

- **Repository:** [github.com/xbill9/gemini-cli-aws](https://github.com/xbill9/gemini-cli-aws)
- **Developer Context:** Cross-platform developer working with Amazon AWS and Google Cloud.
