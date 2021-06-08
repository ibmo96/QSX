#!/bin/bash

#force nginx.pid generation
sudo pkill -9 nginx && nginx -c /etc/nginx/nginx.conf && nginx -s reload 

#invalid argument for nginx.pid
sudo mkdir /etc/systemd/system/nginx.service.d
  printf "[Service]\nExecStartPost=/bin/sleep 0.1\n" | \
    sudo tee /etc/systemd/system/nginx.service.d/override.conf
  sudo systemctl daemon-reload
  sudo systemctl restart nginx
