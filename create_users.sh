#!/bin/bash


user_file="$1"

# Log file and password storage 
log_file="/var/log/user_management.log"
password_file="/var/secure/user_passwords.txt"

# Function to explain the script usage
usage() {
  echo "Usage: $0 <user_list_file>" >&2
  echo "  user_list_file: Path to a text file containing usernames and groups (username;group1,group2,...groupN)"
  exit 1
}

if [ $# -ne 1 ]; then
  usage
  exit 1
fi

# Check if required arguments and files exist
if [[ -z "$user_file" || ! -f "$user_file" ]]; then
  usage
  exit 1
fi

# Function to generate a random password
generate_password() {
  length=16
  cat /dev/urandom | tr -dc 'A-Za-z0-9!@#$%^&*' | fold -w "$length" | head -n 1
}


# If the directory does not exist , create one
if [[ ! -d $(dirname "$log_file") ]]; then
  sudo mkdir -p $(dirname "$log_file")
fi

if [[ ! -d $(dirname "$password_file") ]]; then
  sudo mkdir -p $(dirname "$password_file")
fi

# Open the log file for writing 
exec &>> "$log_file"

# Loop through users in the file
while IFS=';' read -r username groups; do

  # Remove leading/trailing whitespace
  username=$(echo "$username" | xargs)
  groups=$(echo "$groups" | xargs | tr -d ' ')

  # Check if user already exists
  if id "$username" &> /dev/null; then
    echo "$(date +'%Y-%m-%d %H:%M:%S') WARNING: User '$username' already exists. Skipping..." >> "$log_file"
    continue
  fi

  # Create user's primary group if it doesn't exist
  if ! getent group "$username" >/dev/null 2>&1; then
    sudo groupadd "$username"
    echo "$(date +'%Y-%m-%d %H:%M:%S') Created primary group '$username' for user." >> "$log_file"
  fi

  # Generate random password
  password=$(generate_password)

  # Create user with home directory, primary group, and set password using openssl
  useradd -m -g "$username" -s /bin/bash -p $(echo "$password" | openssl passwd -1) "$username"

  # Store password to the password file
  echo "$username,$password" >> "$password_file"

  # Add user to additional groups, if any
  for group in $(echo "$groups" | tr ',' ' '); do

    # Adds a user to a group if the group exists
    # And creates and adds a user to a group if it does not exists
    sudo gpasswd -a "$username" "$group_name"
  done

  # Log success message with date
  echo "$(date +'%Y-%m-%d %H:%M:%S') Successfully created user '$username'." >> "$log_file"
done < "$user_file"

echo "$(date +'%Y-%m-%d %H:%M:%S') User creation process completed. Check $log_file for details." >> "$log_file"