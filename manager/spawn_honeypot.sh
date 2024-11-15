#!/bin/bash

# Get the user's IP address
USER_IP=$(echo $SSH_CLIENT | awk '{print $1}')

# Print the user's IP address
#echo "User IP: ${USER_IP}"

# Generate a unique container name
CONTAINER_NAME="host_${USER_IP//./_}_$(date +%s)"

# Spawn the honeypot container with a random high port
HONEYPOT_PORT=$(shuf -i 20000-65000 -n 1) # Use a high port for production

#echo "Starting honeypot container on port ${HONEYPOT_PORT}..."

docker run --rm --name "${CONTAINER_NAME}" \
    --network honeypot_net \
    -p "0.0.0.0:${HONEYPOT_PORT}:22" \
    -e MANAGER_IP=manager_container \
    -d honeypot_image

# Wait for SSHD to initialize
#echo "Waiting for SSHD to initialize..."
#docker exec "${CONTAINER_NAME}" service sshd start
#docker exec "${CONTAINER_NAME}" service sshd status

# Function to get the honeypot container's internal IP
get_honeypot_ip() {
    docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "${CONTAINER_NAME}"
}

HONEYPOT_IP=$(get_honeypot_ip)
#echo "Honeypot internal IP: ${HONEYPOT_IP}"

# Function to check container health by connecting to internal IP
check_container_health() {
    # Check if container is running
    if ! docker ps --filter "name=${CONTAINER_NAME}" --format '{{.Names}}' | grep -q "${CONTAINER_NAME}"; then
        #echo "Container not running"
        return 1
    fi

    # Check if SSH is responding internally
    if ! nc -zv "${HONEYPOT_IP}" 22 > /dev/null 2>&1; then
        #echo "SSH port not open on ${HONEYPOT_IP}"
        return 1
    fi

    #echo "Container health check passed"
    return 0
}

# Wait for container to be ready
#echo "Waiting for honeypot container to initialize..."
for i in {1..30}; do
    #echo "Health check attempt $i/30..."
    if check_container_health; then
        #echo "Container is healthy"
        break
    fi
    if [ $i -eq 30 ]; then
        #echo "Container failed to initialize properly"
        docker logs "${CONTAINER_NAME}"
        exit 1
    fi
    sleep 1
done

# Schedule container to stop after 2 minutes
(sleep 30; docker stop "${CONTAINER_NAME}") &

# Try to connect to the honeypot using internal IP
#echo "Attempting to connect to honeypot..."

MAX_RETRIES=1
connection_successful=false

# Define the connection attempts
declare -A attempts
attempts=(
    ["Attempt #1"]="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 22 test@${CONTAINER_NAME}"
)

# Loop through each attempt
for attempt_label in "${!attempts[@]}"; do
    #echo "$attempt_label"
    for i in $(seq 1 $MAX_RETRIES); do
        #echo "Connection attempt $i/$MAX_RETRIES..."
        eval ${attempts[$attempt_label]} && {
            connection_successful=true
            #echo "Connection successful on $attempt_label."
            break 2  # Exit both loops
        }
        sleep 2
    done
done

# Check if connection was successful
if [ "$connection_successful" = false ]; then
    #echo "Failed to connect after all attempts"
    # Print the hostname of the container
    docker exec "${CONTAINER_NAME}" hostname
    #echo "Container logs:"
    docker logs "${CONTAINER_NAME}"
    exit 1
fi

# Exit the script after successful connection
exit
