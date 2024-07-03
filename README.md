# Create Users Script

This script automates the creation of user accounts and group assignments on a Linux system. It takes a user list file as input, parses the information, and creates users with random passwords, primary groups, and assigns them to additional groups (if specified).

### Features

- Creates user accounts with random passwords.
- Creates primary groups for users if they don't exist.
- Assigns users to additional groups based on the user list file.
- Logs all actions with timestamps to a designated log file (/var/log/user_management.log).

### Requirements

- Linux system with bash interpreter.
- sudo privileges to run the script.

## Usage

- Prepare a text file containing user information in the following format (one user per line):
  username;group1,group2,...groupN

- username: The desired username for the account.
  group1,group2,...groupN (optional): Comma-separated list of groups the user should belong to (in addition to the primary group).

- Run the script with the user list file as an argument:
  Bash
  `sudo ./create_users.sh /path/to/user_list.txt`

The script logs all actions with timestamps to /var/log/user_management.log. This file can be used to track the user creation process and identify any potential issues.
