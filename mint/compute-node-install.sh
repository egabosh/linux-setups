#!/bin/bash

. /etc/bash/gaboshlib.include

list="wake-on-lan.yml
radeon-rocm.yml
llamacpp-radeon-rocm-install.yml
llamacpp-radeon-rocm-uncensored.yml
comfyui-install.yml
comfyui-radeon-rocm.yml
whisper-stt-install.yml
whisper-stt-radeon-rocm.yml
xttsv2-tts-install.yml
xttsv2-tts-radeon-rocm.yml
tika-docker.yml
searxng-docker.yml
demucs-separate-cpu.yml"

set -e
for compute_playbook in $list
do
  g_echo "==== $compute_playbook"
  scp $compute_playbook compute.lan:/root
  ansible-playbook --inventory compute.lan, --limit compute.lan -e "ansible_python_interpreter=/usr/bin/python3"  $compute_playbook
done



