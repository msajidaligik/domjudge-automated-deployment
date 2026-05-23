# DOMjudge Docker Auto Deployment Script
This repository contains a Bash script to automatically deploy a ```DOMjudge 8.2.0``` server and judgehost using Docker. It simplifies the setup process for programming contests by handling configuration, deployment, and credential generation.


## Features

- Automated deployment of:
    - DOMjudge server
    - Judgehost


- Uses Docker images (version 8.2.0)
- DB Volume persistence
- Optional SSL support
- Interactive script with user prompts
- Stores generated credentials securely in a file

## Prerequisites
Before running the script, ensure you have:

- Docker installed
- Docker Compose installed (if required by your setup)
- Bash shell environment (Linux / macOS / WSL recommended)

## Setup Instructions
### Clone the Repository
```
git clone https://github.com/msajidaligik/domjudge-automated-deployment.git
cd domjudge-automated-deployment
```
### Configure Environment Variables
```
Edit the .env file and update as required
```
### (Optional) Enable SSL
If you want HTTPS support:
- Place your SSL certificates inside the ssl/ directory:
```
ssl/
├── domain_ssl.crt
└── domain_ssl.key
```
- The script will automatically detect and configure SSL if certificates are present.

### Run the Deployment Script
```
chmod +x domjudge-automated-deployment.sh
./domjudge-automated-deployment.sh
```
### Script Usage
The deployment script supports command-line arguments for managing the DOMjudge setup.
#### Basic Deployment
This will run the interactive setup and deploy the system.
```
./domjudge-automated-deployment.sh
```
####  Command Line Options
You can also control the deployment using the following flags:
- Delete Deployment (Keep Volumes)
    - Removes all containers and services
    - Preserves volumes (data remains intact)
```
./domjudge-automated-deployment.sh -dt
```
- Stop Services
    - Stops all running DOMjudge services
    - Does not remove containers or data
```
./domjudge-automated-deployment.sh -sp
```
- Start Services
    - Restarts previously stopped services
```
./domjudge-automated-deployment.sh -st
```

### Credentials
After successful deployment:

- Admin login credentials
- Judgehost API authentication details

will be saved in:
```
secrets.txt
```
