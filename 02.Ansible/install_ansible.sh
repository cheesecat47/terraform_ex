#!/bin/bash

# Install pipx
# https://pipx.pypa.io/stable/#on-linux
sudo apt -qq update > /dev/null
sudo apt -qq -y install pipx > /dev/null
pipx ensurepath > /dev/null

# Install ansible using pipx
# https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html#pipx-install
pipx install -qq --include-deps ansible > /dev/null
