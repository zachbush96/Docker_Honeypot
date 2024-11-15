#!/usr/bin/env python3

import os
import socket
import pty
import select
import sys
import fcntl
import termios

def main():
    manager_ip = os.environ.get('MANAGER_IP', 'manager_container')
    manager_port = 5000
    #print(f"Attempting to connect to {manager_ip}:{manager_port}")

    # Connect to the manager's log listener
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        s.connect((manager_ip, manager_port))
        #print("Connection to manager successful")
    except Exception as e:
        #print(f"Connection to manager failed: {e}")
        return

    # Log that a connection has been made
    #s.sendall(b'Attacker shell started\n')
    #print("Sent 'Attacker shell started' to manager")

    # Open a pseudoterminal for command execution
    master_fd, slave_fd = pty.openpty()

    # Fork the process: parent handles I/O, child runs the shell
    pid = os.fork()
    if pid == 0:
        # Child process: set up the shell
        os.close(master_fd)

        # Start a new session and set the controlling terminal
        os.setsid()
        fcntl.ioctl(slave_fd, termios.TIOCSCTTY, 0)

        os.dup2(slave_fd, 0)  # Set stdin to slave end of pty
        os.dup2(slave_fd, 1)  # Set stdout to slave end of pty
        os.dup2(slave_fd, 2)  # Set stderr to slave end of pty

        # Set ENV variables to hide the honeypot
        os.environ['HISTFILE'] = '/dev/null'
        os.environ['HISTSIZE'] = '0'
        os.environ['HISTFILESIZE'] = '0'
        os.environ['HISTCONTROL'] = 'ignorespace'
        os.environ['PS1'] = '$'
        os.environ['TERM'] = 'xterm-256color'

        os.execv('/bin/bash', ['/bin/bash'])  # Start a bash shell
    else:
        # Parent process: manage I/O between shell and SSH client
        os.close(slave_fd)

        # Set up a loop for input/output handling
        while True:
            rlist, _, _ = select.select([master_fd, sys.stdin, s], [], [])

            if master_fd in rlist:
                # Read from shell output and send to both SSH client and manager
                output = os.read(master_fd, 1024)
                if output:
                    # Send shell output to SSH client and manager
                    #s.sendall(output)  # Send to manager
                    os.write(sys.stdout.fileno(), output)  # Send to SSH client

            if sys.stdin in rlist:
                # Read command from SSH input and send it to the shell
                command = os.read(sys.stdin.fileno(), 1024)
                if command:
                    os.write(master_fd, command)  # Write to shell
                    # Log the command to the manager without sending it back to SSH client
                    s.sendall(f"{command.decode()}".encode())

            if s in rlist:
                # Handle any incoming data from the manager socket
                data = s.recv(1024)
                if not data:
                     break

        # Clean up and close the socket after session ends
        s.sendall(b'Attacker shell ended\n')
        #print("Sent 'Attacker shell ended' to manager")
        s.close()

if __name__ == '__main__':
    main()
