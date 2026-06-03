#!/bin/bash

. /etc/bash/gaboshlib.include

list="wol-ai-lan.yml
radeon-rocm.yml
llamacpp-radeon-rocm.yml
comfyui-pics-cpu.yml
whisper-stt-cpu.yml
piper-tts-cpu.yml"

set -e
for ai_playbook in $list
do
  g_echo "==== $ai_playbook"
  scp $ai_playbook ai.lan:/root
  ansible-playbook --inventory ai.lan, --limit ai.lan -e "ansible_python_interpreter=/usr/bin/python3"  $ai_playbook
done



