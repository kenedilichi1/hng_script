#!/bin/bash

#create log and password file
LOG_MANAGER_FILE="/var/log/user_management.log"
PASSWORD_FILE="/var/secure/user_password.txt"


#generate random password
generate_password() {
    openssl  rand -base64 16
}

#log messages into the log manager file
log_message() {
    echo "$(date +'%Y-%M-%D-%S') - " "$1" >> "$LOG_MANAGER_FILE"
}

#ensure txt file is provided as argument
if [ "$#" -eq 0 ]; then
 log_message "Error: user file not found. Please pass the user file as base argument "
 exit 1
fi


#use root privilege to create log file if it does not exists
if [ ! -f "$LOG_MANAGER_FILE" ]; then
 sudo touch "$LOG_MANAGER_FILE"
 log_message "created log management file at"
fi

#use root privilege to create password file if it does not exist
if [ ! -f "$PASSWORD_FILE" ]; then
 echo "creating secure password directory..."
 sudo mkdir -p /var/secure
 sudo chmod 700 /var/secure
 sudo touch "$PASSWORD_FILE"
 sudo chmod go-rwx "$PASSWORD_FILE"
 log_message "created Password file "
fi


#use internal field separator(IFS) to get the username and group name
while IFS=";" read -r username groups; do

 username=$(echo "$username" | xargs)
 groups=$(echo "$groups" | xargs)

 #create group with username as group name
 groupadd "$username"  &>> "$LOG_MANAGER_FILE"
 log_message "created user group"

 #check if user already exists
 if id -u "$username" &> /dev/null; then
  log_message "user already exists"
  continue
 fi

 #add user in the /home directory
 useradd -m -g  "$username" "$username" &>> "$LOG_MANAGER_FILE"
 log_message "user created in home directory"

 #add group in the etc/group directory
 for group in $(echo "$groups" | tr ',' ' '); do
    if ! grep -q  "^$groups:" /etc/group; then
     groupadd "$group" &>> "$LOG_MANAGER_FILE"
     log_message "created group: $group"
    fi

   usermod -aG  "$group" "$username"
   log_message  "Added user: $username to: $group"
 done

 #assign passwords to users
 password=$(generate_password)
 echo "$username, $password" >> "$PASSWORD_FILE"
 echo "$password" | passwd --stdin "$username" &>> "$LOG_MANAGER_FILE"
 log_message "User Password generated and set for: $username"

done < "$1"

log_message "succeful"