#!/usr/bin/env bash
set -ev

echo "Installing Docker..."
sudo apt-get update
sudo apt-get remove docker docker.io
echo '* libraries/restart-without-asking boolean true' | sudo debconf-set-selections
sudo apt-get install apt-transport-https ca-certificates curl software-properties-common python3-pip -y
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg |  sudo apt-key add -
sudo apt-key fingerprint 0EBFCD88
sudo add-apt-repository \
      "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) \
      stable"
sudo apt-get update
sudo apt-get install -y docker-ce
# Restart docker to make sure we get the latest version of the daemon if there is an upgrade
sudo service docker restart
# Make sure we can actually use docker as the vagrant user
sudo usermod -aG docker vagrant
sudo docker --version
sudo pip3 install docker-compose

sudo mkdir -p /srv/loki/

cat <<EOF > /srv/loki/loki-config.yaml
auth_enabled: false

server:
  http_listen_port: 3100

ingester:
  lifecycler:
    address: 127.0.0.1
    ring:
      kvstore:
        store: inmemory
      replication_factor: 1
    final_sleep: 0s
  chunk_idle_period: 5m
  chunk_retain_period: 30s

schema_config:
  configs:
  - from: 2020-05-15
    store: boltdb
    object_store: filesystem
    schema: v11
    index:
      prefix: index_
      period: 168h

storage_config:
  boltdb:
    directory: /var/lib/loki/boltdb/

  filesystem:
    directory: /var/lib/loki/chunks/

limits_config:
  enforce_metric_name: false
  reject_old_samples: true
  reject_old_samples_max_age: 168h
EOF

cat <<EOF > /srv/loki/vector.toml
[api]
enabled = true
address = "127.0.0.1:8686"

# Host-level logs
[sources.logs]
type = "docker_logs"
include_labels = ["loki=1"]

# --> Add transforms here to parse, enrich, and process data

# print all events, replace this with your desired sink(s)
# https://vector.dev/docs/reference/sinks/
[sinks.out]
type = "console"
inputs = [ "logs" ]
encoding.codec = "json"

[sinks.loki]
type = "loki"
encoding.codec = "json"
inputs = [ "logs" ]
endpoint = "http://loki:3100"

labels.forwarder = "vector"
labels.source_type = "{{ source_type }}"
labels.container_name = "{{ container_name }}"
EOF

cat <<EOF > /srv/loki/docker-compose.yml
version: '3.8'
services:
  loki:
    image: grafana/loki:2.6.1
    user: root
    ports:
      - "3100:3100"
    command: -config.file=/etc/loki/local-config.yaml
    volumes:
      - ./loki-config.yaml:/etc/loki/local-config.yaml
      - /var/lib/loki/:/var/lib/loki/

  grafana:
    image: grafana/grafana:9.2.2
    ports:
      - "3000:3000"

  vector:
    image: timberio/vector:0.24.2-debian
    ports:
      - "8383:8383"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./vector.toml:/etc/vector/vector.toml:ro

networks:
  default:
    name: loki
EOF
cd /srv/loki/
sudo docker-compose pull
sudo docker-compose up -d


sudo mkdir -p /srv/whoami/

cat <<EOF > /srv/whoami/docker-compose.yml
version: '3.8'
services:
  whoami:
    image: jwilder/whoami
    labels:
      loki: 1
    ports:
      - "8000:8000"
EOF
cd /srv/whoami/
sudo docker-compose pull
sudo docker-compose up -d
