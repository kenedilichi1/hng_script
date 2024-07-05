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
  local length=16
  tr -dc 'A-Za-z0-9!@#$%^&*' < /dev/urandom | fold -w "$length" | head -n 1
}

# Set log and password file paths
log_file="/var/log/user_management.log"
password_file="/var/secure/user_passwords.txt"

# Create log and password storage directories if they don't exist
sudo mkdir -p $(dirname "$log_file")
sudo mkdir -p $(dirname "$password_file")

# Ensure log and password files have secure permissions
sudo touch "$log_file" "$password_file"
sudo chmod 600 "$password_file"
sudo chmod 644 "$log_file"

# Redirect standard output and error to log file
exec &>> "$log_file"

# Function to log messages
log() {
  echo "$(date +'%Y-%m-%d %H:%M:%S') $1" | sudo tee -a "$log_file" > /dev/null
}

# Loop through users in the file
while IFS=';' read -r username groups; do

  # Remove leading/trailing whitespace from username and groups
  username=$(echo "$username" | xargs)
  groups=$(echo "$groups" | xargs | tr -d ' ')

  # Generate a random password
  password=$(generate_password)

  # Check if user already exists
  if id -u "$username" &> /dev/null; then
    log "WARNING: User '$username' already exists. Adding to specified groups."
  else
    # Create primary group if it does not exist
    if ! getent group "$username" >/dev/null 2>&1; then
      sudo groupadd "$username"
      log "Created primary group '$username' for user."
    fi

    # Create user with home directory and specified shell
    sudo useradd -m -g "$username" -s /bin/bash -p $(echo "$password" | openssl passwd -1) "$username"
    if [ $? -eq 0 ]; then
      log "Successfully created user '$username'."
      echo "$username,$password" | sudo tee -a "$password_file" > /dev/null
    else
      log "ERROR: Failed to create user '$username'."
      continue
    fi
  fi

  # Set home directory permissions and ownership
  sudo chmod 700 /home/"$username"
  sudo chown "$username":"$username" /home/"$username"
  log "Set permissions and ownership for /home/$username."

  # Add user to primary group
  sudo usermod -g "$username" "$username"
  log "Added user '$username' to primary group '$username'."

  # Add user to additional groups
  for group in $(echo "$groups" | tr ',' ' '); do
    if ! getent group "$group" >/dev/null 2>&1; then
      sudo groupadd "$group"
      log "Created group '$group'."
    fi
    sudo gpasswd -a "$username" "$group"
    log "Added user '$username' to group '$group'."
  done

  # Verification logs
  if id "$username" &> /dev/null; then
    log "User '$username' creation verified."
  else
    log "ERROR: User '$username' creation failed."
  fi

  for group in $(echo "$groups" | tr ',' ' '); do
    if id -nG "$username" | grep -qw "$group"; then
      log "User '$username' is a member of group '$group'."
    else
      log "ERROR: User '$username' is not a member of group '$group'."
    fi
  done

  if id -nG "$username" | grep -qw "$username"; then
    log "User '$username' is a member of their personal group '$username'."
  else
    log "ERROR: User '$username' is not a member of their personal group '$username'."
  fi

done < "$1"

log "User creation process completed. Check $log_file for details."
