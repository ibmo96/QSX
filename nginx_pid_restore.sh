#!/bin/bash

sudo mkdir /etc/systemd/system/nginx.service.d
  printf "[Service]\nExecStartPost=/bin/sleep 0.1\n" | \
    sudo tee /etc/systemd/system/nginx.service.d/override.conf
  sudo systemctl daemon-reload
  sudo systemctl restart nginx
