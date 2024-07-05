#!/bin/bash

# Function to explain script usage
usage() {
  echo "Usage: $0 <user_list_file>" >&2
  echo "  user_list_file: Path to a text file containing usernames and groups (username;group1,group2,...groupN)"
  exit 1
}

# Check if exactly one argument is provided
if [ $# -ne 1 ]; then
  usage
  exit 1
fi

# Check if user list file exists
if [[ -z "$1" || ! -f "$1" ]]; then
  echo "Error: User list file '$1' does not exist." >&2
  exit 1
fi

# Function to generate a random password
generate_password() {
  length=16
  cat /dev/urandom | tr -dc 'A-Za-z0-9!@#$%^&*' | fold -w "$length" | head -n 1
}

# Create log and password storage directories if they don't exist
log_file="/var/log/user_management.log"
password_file="/var/secure/user_passwords.txt"

if [[ ! -d $(dirname "$log_file") ]]; then
  sudo mkdir -p $(dirname "$log_file")
fi

if [[ ! -d $(dirname "$password_file") ]]; then
  sudo mkdir -p $(dirname "$password_file")
fi

# Redirect standard output and error to log file
exec &>> "$log_file"

# Function to log messages
log() {
  echo "$(date +'%Y-%m-%d %H:%M:%S') $1" >> "$log_file"
}

# Ensure password file has secure permissions
sudo chmod 600 "$password_file"

# Loop through users in the file
while IFS=';' read -r username groups; do

  # Remove leading/trailing whitespace from username and groups
  username=$(echo "$username" | xargs)
  groups=$(echo "$groups" | xargs | tr -d ' ')

  password=$(generate_password)

  # Check if user already exists
  if id -u "$username" &> /dev/null; then
    log "WARNING: User '$username' already exists. Adding to specified groups."
  else
    # Create primary group if the primary group does not exist
    if ! getent group "$username" >/dev/null 2>&1; then
      sudo groupadd "$username"
      log "Created primary group '$username' for user."
    fi

    # Create user with extra options
    sudo useradd -m -g "$username" -s /bin/bash -p $(echo "$password" | openssl passwd -1) "$username"
    if [ $? -eq 0 ]; then
      log "Successfully created user '$username'."
    else
      log "ERROR: Failed to create user '$username'."
      continue
    fi

    # Store username and password in a password file
    echo "$username,$password" | sudo tee -a "$password_file" > /dev/null
  fi

  # Add user to primary group
  sudo usermod -g "$username" "$username"
  log "Added user '$username' to primary group '$username'."

  # Add user to additional groups
  for group in $(echo "$groups" | tr ',' ' '); do
    if ! getent group "$group" >/dev/null 2>&1; then
      sudo groupadd "$group" &>> "$log_file"
      log "Created group '$group'."
    fi
    sudo gpasswd -a "$username" "$group" &>> "$log_file"
    log "Added user '$username' to group '$group'."
  done

  # Check if user belongs to all specified groups
  for group in $(echo "$groups" | tr ',' ' '); do
    if id -nG "$username" | grep -qw "$group"; then
      log "User '$username' is a member of group '$group'."
    else
      log "ERROR: User '$username' is not a member of group '$group'."
    fi
  done

  # Check if user belongs to their personal group
  if id -nG "$username" | grep -qw "$username"; then
    log "User '$username' is a member of their personal group '$username'."
  else
    log "ERROR: User '$username' is not a member of their personal group '$username'."
  fi

done < "$1"

log "User creation process completed. Check $log_file for details."