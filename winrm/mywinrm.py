#!/usr/bin/env python3

import winrm

p = winrm.protocol.Protocol(
    endpoint='https://192.168.122.156:5986/wsman',
    transport='certificate',
    server_cert_validation='ignore',
    cert_pem='pki/client.pem',
    cert_key_pem='pki/client.key')
shell_id = p.open_shell()
command_id = p.run_command(shell_id, 'ipconfig', ['/all'])
std_out, std_err, status_code = p.get_command_output(shell_id, command_id)

print(std_out.decode('sjis'), end="")

p.cleanup_command(shell_id, command_id)
p.close_shell(shell_id)
