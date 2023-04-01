# CI/CD Utils

CI/CD Utils is a manager of build numbers and Google Oauth2 Tokens. This project is basically a server (Docker based) and a command-line tool.

## Features

- Manage build number version
- Get or refresh Google Oauth2 Token

## Examples

### List all version numbers

```console
    ci-cd-utils version-list
```

### Create or get created build number of specific tag

```console
    ci-cd-utils version-build-number
```

### Get Google Oauth2 Token

```console
    ci-cd-utils google-oauth2-token
```

### Create server/client keys

```console
    ci-cd-utils create-keys
```

## Requirements

- Docker server
  > The docker image has only 5MB, the application boots up in 5 seconds
  >
  > You can use Google Cloud Run for free to host the application

- MongoDB server
  > You can use MongoDB atlas

## Setup

1. Setup MongoDB server

2. Setup configuration files
    1. Install Command Line tools:

        ```console
            brew install ranierjardim/ci-cd-utils/ci-cd-utils
        ```

    2. Create server/client credentials:

        ```console
            ci-cd-utils create-keys
        ````

    3. Copy

3. TODO

## Command-line tool Homebrew installation

```console
brew install ranierjardim/ci-cd-utils/ci-cd-utils
```

To unninstall:

```console
brew remove ranierjardim/ci-cd-utils/ci-cd-utils
```

This application was made in Dart 2.19.3
