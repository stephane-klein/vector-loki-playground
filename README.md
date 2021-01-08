# Vector Loki playground

In this repository, I want to test [Vector](https://vector.dev/) with [Loki](https://github.com/grafana/loki) to centralize Docker container logs.

Vector is installed on Docker in [Agent Role](https://vector.dev/docs/setup/installation/platforms/docker/) mode.

## Prerequisite

- Virtualbox
- Vagrant
- [vagrant-hostmanager](https://github.com/devopsgroup-io/vagrant-hostmanager) plugin

On OSX, execute this command with [brew](https://brew.sh/index_fr.html) to install this prerequisite :

```sh
brew cask install vagrant virtualbox
vagrant plugin install vagrant-hostmanager --plugin-version 1.8.9
```

## Start Vagrant host

```sh
vagrant up
```

Go to http://myserver:3000

Configure Loki datasource:

- Url: `http://loki:3100`

Go to `http://myserver:8000/` to generate log event.

Docker container log with Docker Label `loki: 1` are forwarded to Loki server, for instance:

```
version: '3.8'
services:
  whoami:
    image: jwilder/whoami
    labels:
      loki: 1
    ports:
      - "8000:8000"
```