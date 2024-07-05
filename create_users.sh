#!/bin/bash

# Function to display script usage with examples
usage() {
  echo "Usage: $0 <user_list_file>" >&2
  echo "  user_list_file: Path to a text file containing usernames and groups (username;group1,group2,...groupN)"
  echo "  Example: $0 /path/to/employees.txt"
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

# Function to generate a random password with specified length
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

# Loop through users in the file
while IFS=';' read -r username groups; do

  # Remove leading/trailing whitespace from username and groups
  username=$(echo "$username" | xargs)
  groups=$(echo "$groups" | xargs | tr -d ' ')

  # Generate a random password
  password=$(generate_password)

  # Check if user already exists
  if id "$username" &> /dev/null; then
    echo "$(date +'%Y-%m-%d %H:%M:%S') WARNING: User '$username' already exists. Skipping..."
  else
    # Create primary group if it doesn't exist
    if ! getent group "$username" >/dev/null 2>&1; then
      sudo groupadd "$username"
      echo "$(date +'%Y-%m-%d %H:%M:%S') Created primary group '$username' for user."
    fi

    # Create user with home directory, default shell, and set password
    useradd -m -g "$username" -s /bin/bash -p $(echo "$password" | openssl passwd -1) "$username"
    echo "$(date +'%Y-%m-%d %H:%M:%S') Successfully created user '$username'."

    # Set home directory permissions
    sudo chown "$username:$username" "/home/$username"
    sudo chmod 700 "/home/$username"  # Adjust permissions as needed

    # Add user to primary group
    sudo usermod -g "$username" "$username"
    echo "$(date +'%Y-%m-%d %H:%M:%S') Added user '$username' to primary group '$username'."

    # Add user to additional groups
    for group in $(echo "$groups" | tr ',' ' '); do
      if getent group "$group" >/dev/null 2>&1; then
        sudo gpasswd -a "$username" "$group"
        echo "$(date +'%Y-%m-%d %H:%M:%S') Added user '$username' to existing group '$group'."
      else
        sudo groupadd "$group"
        echo "$(date +'%Y-%m-%d %H:%M:%S') Created group '$group' and added user '$username'."
        sudo gpasswd -a "$username" "$group"
      fi
    done

    # Store username and password securely (consider a dedicated password manager)
    echo "$username,$password" >> "$password_file"
  fi

done < "$1"

echo "$(date +'%Y-%m-%d %H:%M:%S') User creation process completed. Check $log_file for details."
