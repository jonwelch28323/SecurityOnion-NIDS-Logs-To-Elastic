#!/bin/bash

set_variables() {
    read -p "Enter the host port value (e.g., 1-65535) ensure it is not a port that is already in use first (DEFAULT: 8220): " new_host_port
    if [ -z "$new_host_port" ]; then
        echo "Host port set to $(grep HOST_PORT= .env | awk -F'=' '{print $2}')"
    else 
        sed -i "s|^HOST_PORT=.*|HOST_PORT=$new_host_port|" .env
        echo "Host port set to $(grep HOST_PORT= .env | awk -F'=' '{print $2}')"
    fi

    read -p "Enter the enrollment token that is assigned in your fleet manager for the policy you want to add the agent to: " new_fleet_enrollment_token
    if [ -z "$new_fleet_enrollment_token" ]; then
        echo "Your enrollment token is: $(grep FLEET_ENROLLMENT_TOKEN= .env | awk -F'=' '{print $2}')"
    else
        sed -i "s|^FLEET_ENROLLMENT_TOKEN=.*|FLEET_ENROLLMENT_TOKEN=$new_fleet_enrollment_token|" .env
        echo "Your enrollment token is: $(grep FLEET_ENROLLMENT_TOKEN= .env | awk -F'=' '{print $2}')"
    fi
    
    read -p "Enter the name of the internal docker network to add the agent to (DEFAULT: sobridge): " new_docker_network
    if [ -z "$new_docker_network" ]; then
        echo "Your docker network is: $(grep DOCKER_NETWORK= .env | awk -F'=' '{print $2}')"
    else
        sed -i "s|^DOCKER_NETWORK=.*|DOCKER_NETWORK=$new_docker_network|" .env
        echo "Your docker network is: $(grep DOCKER_NETWORK= .env | awk -F'=' '{print $2}')"
    fi
    
    read -p "Enter the fleet url to connect the agent to (EXAMPLE "https://172.16.30.18:8220"): " new_fleet_url
    if [ -z "$new_fleet_url" ]; then
        echo -e "Connect to Elastic Fleet Url at: $(grep FLEET_URL= .env | awk -F'=' '{print $2}')"
    else    
        sed -i "s|^FLEET_URL=.*|FLEET_URL=$new_fleet_url|" .env
        echo -e "FLEET URL set to: $(grep FLEET_URL= .env | awk -F'=' '{print $2}')"
    fi
    
    read -p "Confirm the information above to continue (y/n): " confirm
    
    if [[ $confirm != "y" && $confirm != "Y" ]]; then
        echo "Configuration aborted"
        exit 0
    else
       echo "Loading Image"
       #load_image
       echo "Starting the Conatiner"
       #start_agent 
    fi
}


# Initialize an empty array to store IP addresses
ip_list=()

# Function to validate an IP address
valid_ip() {
    local ip=$1
    local stat=1

    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        if [[ ${ip} -le 255 && ${ip} -le 255 && ${ip} -le 255 && ${ip} -le 255 ]]; then
            stat=0
        fi
    fi
    return $stat
}

# Function to prompt user for IP addresses
collect_ips() {
    while true; do
        read -p "Enter SO Sensor IP address (or type 'done' to finish): " ip
        if [[ "$ip" == "done" ]]; then
            break
        fi
        if valid_ip "$ip"; then
            ip_list+=("$ip")
        else
            echo "Invalid IP address. Please try again."
        fi
    done
}

# Function to print the collected IP addresses
print_ips() {
    echo "SecurityOnion Sensor IP addresses:"
    for ip in "${ip_list[@]}"; do
        echo "$ip"
    done
}

#Copy files to the home directory
copy_files() {
    echo "COPYING THE REQUIRED FILES"
    for ip in "${ip_list[@]}"; do
        read -p "Enter the User Name for $ip: " username
        read -p "Password: " SSHPASS
        export SSHPASS
        sshpass -e ssh $username@$ip "mkdir elastic-agent"
        echo "Copying docker container image"
        sshpass -e scp elastic-agent* $username@$ip:/home/$username/elastic-agent
        echo "Copying .env file"
        sshpass -e scp .env $username@$ip:/home/$username/elastic-agent
        echo "Copying docker-compose.yml"
        sshpass -e scp docker-compose.yml $username@$ip:/home/$username/elastic-agent
        echo "All files are staged on all Sensors. You may continue....."
    done 
    
}

#Run this script to install the agent
run_install() {
   echo "Loading the image into the local docker repo"
   sshpass -e ssh welch@172.16.30.22 "sudo -S docker load -i elastic-agent/elastic-agent*"
   echo "Starting and connecting the elastic-agent to the Elastic Stack."
   sshpass -e ssh welch@172.16.30.22 "sudo -S docker compose -f elastic-agent/docker-compose.yml up -d"
}

# Check if the container is running
docker_check() {
    if sshpass -e ssh welch@172.16.30.22 "sudo -S docker ps --filter "name=701-CPT-elastic-agent" --filter "status=running" | grep -q 701-CPT-elastic-agent"; then
        echo "The container 701-CPT-elastic-agent is running."
    else
        echo "The container 701-CPT-elastic-agent is not running."
    fi
}

#Func to display the settings and the IPs
show_settings(){
    echo "YOUR CONFIG SETTINGS:"
    echo "======================================================================================="
    echo "Docker Port: $(grep HOST_PORT= .env | awk -F'=' '{print $2}')"
    echo "Enrollment Token: $(grep FLEET_ENROLLMENT_TOKEN= .env | awk -F'=' '{print $2}')"
    echo "Docker Network: $(grep DOCKER_NETWORK= .env | awk -F'=' '{print $2}')"
    echo "Fleet URL: $(grep FLEET_URL= .env | awk -F'=' '{print $2}')"
    echo "======================================================================================="
}

set_variables
show_settings
collect_ips
print_ips
copy_files
run_install
docker_check