# Script: build_project.ps1

# Define directories
$honeypotDir = "honeypot"
$managerDir = "manager"
$tarFileName = "honeypot_image.tar"
$tarFilePath = "../$managerDir/$tarFileName"

$starting_path = Get-Location

# Step 0: Cleanup any existing containers named honeypot or manager
Write-Output "Cleaning up any existing honeypot and manager containers..."
$containers = docker ps -a --format "{{.ID}} {{.Names}}" | ForEach-Object {
    if ($_ -match "honeypot|manager_container|host") {
        $containerId = $_.Split()[0]
        Write-Output "Stopping container $containerId..."
        docker stop $containerId | Out-Null
        Write-Output "Removing container $containerId..."
        docker rm $containerId | Out-Null
    } else {
        Write-Output "No honeypot or manager containers found."
    }
}

# Step 1: Build the honeypot image
Write-Output "Building honeypot image..."
Set-Location -Path $honeypotDir
#docker build --no-cache -t honeypot_image .
docker build -t honeypot_image .

# Step 2: Save the honeypot image to a tar file
Write-Output "Saving honeypot image to tar file..."
docker save honeypot_image > $tarFileName

# Step 3: Check if the tar file exists in the manager directory and delete if it does
if (Test-Path -Path $tarFilePath) {
    Write-Output "Old tar file detected in manager directory. Deleting..."
    Remove-Item -Path $tarFilePath
}

# Move the new tar file to the manager directory
Write-Output "Moving new tar file to manager directory..."
Move-Item -Path $tarFileName -Destination "../$managerDir"

# Step 4: Build the manager image
Write-Output "Building manager image..."
Set-Location -Path "../$managerDir"
docker build -t manager_image .

# Step 5: Clean up any existing manager container (redundant with step 0 but kept for safety)
Write-Output "Cleaning up any existing manager container..."
docker stop manager_container 2>$null
docker rm manager_container 2>$null

# Step 6: Create Docker network if it doesn't exist
Write-Output "Ensuring honeypot network exists..."
docker network create honeypot_net 2>$null

# Step 7: Run the manager container with specified network and port settings
Write-Output "Starting manager container..."
docker run -d --name manager_container --network honeypot_net --privileged -v /var/run/docker.sock:/var/run/docker.sock -p 0.0.0.0:22:22 -p 0.0.0.0:5000:5000 -p 0.0.0.0:8080:8080 manager_image
#docker run -d --name manager_container --privileged -v /var/run/docker.sock:/var/run/docker.sock -p 2222:22 -p 5000:5000 manager_image

Write-Output "Build and deployment process completed successfully."

# Return to starting directory
Set-Location -Path $starting_path
