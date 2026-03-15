# High Availability Video Streaming using Docker Swarm 

## Overview

This project demonstrates a high availability setup using Docker Swarm, Keepalived, and a floating Virtual IP (VIP) to maintain service availability during node failures.

The system runs on three nodes connected in a Docker Swarm cluster and host two video streaming websites deployed as services.


If one node fails, another node automatically takes over the Virtual IP, allowing the services to remain accessible without interruption.

This project demonstrates 4 phases:

- Creating a Docker Swarm cluster
- Virtual IP failover using VRRP and Keepalived
- Detecting node failures using a Swarm watcher service
- Deploying two highly available video streaming websites as services

## System Architecture

The infrastructure consists of **three nodes**:

| Node | Role |
|-----|------|
| node1 | Primary node for Website A and initial owner of statically defined VIP `.200` and a dynamically injected VIP `.102`
| node2 | Primary node for Website B and initial owner of a statically defined VIP `.201`
| node3 | Standby failover node for both website services and all three VIPs.


If a node fails:

1. Keepalived detects the failure using VRRP heartbeat monitoring.
2. The standby node with the highest priority becomes the new MASTER.
3. The Virtual IP moves to the new node.
4. Docker Swarm reschedules the affected service if required.


---

## Repository Structure

The repository contains configuration files for all three nodes.

```
High-Availability-Video-Streaming-Using-Docker-Swarm
│
├── node1
│   ├── keepalived
│   └── websiteA
│
├── node2
│   ├── keepalived
│   └── websiteB
│
├── node3
│   ├── keepalived
│   ├── swarm-watcher
│   └── docker-compose.yml
│
└── README.md
```

### node1
Contains configuration for:

- Keepalived VIP failover
- Website A service

### node2
Contains configuration for:

- Keepalived VIP failover
- Website B service

### node3
Contains configuration for:

- Keepalived standby node
- Swarm watcher monitoring service
- docker-compose.yml file for deploying both website services

Each node uses only its corresponding folder after cloning the repository.

---

## Project Workflow

The project is implemented in the following 4 major phases:

1. Docker Swarm Cluster Setup
2. Keepalived VIP Failover Configuration
3. Swarm Watcher Monitoring Service
4. Highly Available Website Deployment

Each section explains how the infrastructure components are configured and deploye
## Implementation

## Phase 1 - Create a Swarm Cluster with 3 systems

This phase sets up a 3-node Docker Swarm cluster using VirtualBox VMs.

The cluster runs on a VirtualBox Host-Only network.

VirtualBox automatically creates a private network:

```
192.168.56.0/24
```


Example IP assignment used in this setup:

| Node | IP Address |
|-----|-------------|
| node1 | 192.168.56.11 |
| node2 | 192.168.56.12 |
| node3 | 192.168.56.13 |

---

### Step 1 — Create 3 Virtual Machines

Using VirtualBox, create three Ubuntu VMs:

- `node1`
- `node2`
- `node3`

Before creating the VMs, ensure that DHCP is disabled on the VirtualBox Host-Only network, since the nodes will use manually assigned static IP addresses via netplan.

This prevents VirtualBox from automatically assigning IP addresses.

---

### Step 2 — Configure Network Adapters

Each VM should have two network adapters.

### Adapter 1
- Attached to **NAT**
- Provides internet access for installing packages

### Adapter 2
- Attached to **Host-Only Adapter**
- Provides private communication between the VMs

---

### Step3 - Set Host names

Set the hostname on each VM.

### Node1

```bash
sudo hostnamectl set-hostname node1
```

### Node2

```bash
sudo hostnamectl set-hostname node2
```

### Node3

```bash
sudo hostnamectl set-hostname node3
```

Reboot the system:

```bash
sudo reboot
```

---

### Step 4-Configure Static IP Addresses

Configure static IP addresses on the **Host-Only network interface (`enp0s8`)**.

Edit the netplan configuration file on all three nodes:

```bash
sudo nano /etc/netplan/01-network-manager-all.yaml
```

---

## Node1 Netplan Configuration

```
network:
  version: 2
  renderer: NetworkManager
  ethernets:
    enp0s8:
      dhcp4: no
      addresses:
        - 192.168.56.11/24
```

---

## Node2 Netplan Configuration

```
network:
  version: 2
  renderer: NetworkManager
  ethernets:
    enp0s8:
      dhcp4: no
      addresses:
        - 192.168.56.12/24
```

---

## Node3 Netplan Configuration

```
network:
  version: 2
  renderer: NetworkManager
  ethernets:
    enp0s8:
      dhcp4: no
      addresses:
        - 192.168.56.13/24
```

---

Apply the configuration:

```bash
sudo netplan apply
```

Verify the IP:

```bash
ip a
```

You should see the configured IP on **interface `enp0s8`**.


---
### Step 5- Install Docker on all VMs
```bash
sudo apt update
sudo apt install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable docker
sudo systemctl start docker
sudo docker run hello-world
```
### Step 6- Create Docker Swarm Cluster
- Init Swarm on node 1 
    ```bash
    docker swarm init --advertise-addr 192.168.56.11
    ```
- Join node2 and node3 
    ```bash
    docker swarm join --token <TOKEN> 192.168.56.11:2377
    ```
- Verify cluster nodes:

  ```bash
   sudo docker node ls
  ```
  This will show the three nodes with node 1 as the manager node and nodes 2 and 3 as worker nodes.

---
## Phase 2 - Run keepalived as a Container on all 3 nodes and VIP Failover

Keepalived is deployed as a container on all three nodes to manage Virtual IP failover across the cluster.

Each node runs its own Keepalived container which participates in VRRP election to determine which node should own a particular VIP.

The configuration ensures that:

- VIP `.200` is primarily owned by node1.
- VIP `.201` is primarily owned by node2.
- VIP `.102`is dynamically generated and initially owned by node1.
- node3 acts as a standby node and takes over VIPs if either node1 or node2 fails



### Virtual IP Configuration

This setup uses three Virtual IPs (VIPs) to provide high availability across the cluster.

- Two VIPs (`.200` and `.201`) are statically defined in the `keepalived.conf.template` file.
- One VIP (`.102`) is dynamically generated using the `ip.sh` script and injected into the configuration during container startup.

#### Static VIPs

- VIP `192.168.56.200` is configured with priority:
   ```
   node1 > node3 > node2
   250   > 200   > 100
   ```


- VIP `192.168.56.201` is configured with priority:
  ```
  node2 > node3 > node1
  250   > 200   > 100
  ```

This means:

- `.200` is initially owned by **node1**, as it has the highest priority.  
  If **node1 fails**, **node3** takes over the VIP.

- `.201` is initially owned by **node2**, as it has the highest priority.  
  If **node2 fails**, **node3** takes over the VIP.

Both `.200` and `.201` are defined directly inside the **`keepalived.conf.template`** file for each node.

---

#### Dynamic VIP

A third VIP `192.168.56.102` is generated dynamically.

The IP address is specified inside:

```bash
ip.sh
```

Example:

```bash
192.168.56.102/24
```

Inside the `keepalived.conf.template`, the dynamic VIP is represented using:

```
VIP_PLACEHOLDER
```
VIP `192.168.56.102` is configured with priority:

```
node1 > node3 > node2
250   > 200   > 100
```
During container startup, the `start.sh` script:

1. Reads the VIP value from `ip.sh`
2. Replaces `VIP_PLACEHOLDER` in `keepalived.conf.template`
3. Generates the final `keepalived.conf` used by Keepalived

---
### Recreate the setup
After cloning the repository on each node, delete the other node folders on each node and navigate to the directory corresponding to that node.

- On node 1:
   ```bash
   cd High-Availability-Video-Streaming-Using-Docker-Swarm/node1/keepalived
   ```
   Delete node2 and node3 folders since we are only using node1 folder for node1.
- On node 2 :
   ```bash
   cd High-Availability-Video-Streaming-Using-Docker-Swarm/node2/keepalived
   ```
   Delete node1 and node3 folders since we are only using node2 folder for node2.
- On node 3 :
   ```bash
   cd High-Availability-Video-Streaming-Using-Docker-Swarm/node3/keepalived
   ```
   Delete node1 and node2 folders since we are only using node3 folder for node3.
- On all nodes:
  ```bash
  sudo chmod 755 check_docker.sh 
  sudo chmod 755 start.sh
  ```  
  This ensure check_docker.sh and start.sh are executable.

### Start Keepalived Containers

Run on each node:

```bash
sudo docker compose down
sudo docker compose up -d
```

- The container runs `start.sh`, which reads the VIP address from `ip.sh`.
- The script replaces `VIP_PLACEHOLDER` in `keepalived.conf.template` with the VIP specified in `ip.sh` (for example `192.168.56.102/24`), generating the final `keepalived.conf`.
- The static VIPs `.200` and `.201` are already defined directly in the template and are included in the generated configuration.

Verify keepalived container is running on all nodes:

```bash
sudo docker ps
```

---

### Test VIP Failover

Simulate a node failure on node1:

```bash
sudo systemctl stop docker
```

Check VIP migration:

```bash
ip a
```
VIPs .200 and .102 will have migrated to node 3

Now run ```sudo systemctl start docker``` on node 1 to migrate VIPs .200 and .102 back to node 1.

Test the same on node 2.


---
## Phase 3 - Create a swarm_watcher service that detects the failed node and its identity configuration (replicated only on node3)


In this phase, we create a Swarm watcher service that monitors the Docker Swarm cluster and detects when a node goes down.

The watcher service reads a dictionary file (`dict.yaml`) stored as a Docker Swarm config to map node names to their identity.


```yaml
node1: "this is node 1"
node2: "this is node 2"
node3: "this is node 3"
```

When a node fails, the watcher prints an alert along with the identity retrieved from this dictionary.This swarm service is constrained to run only on Node3 using a Docker Swarm node label.

### Step 1 — Promote nodes 2 and 3 to manager nodes
To allow all nodes to manage the cluster and support monitoring services,
promote node2 and node3 to manager nodes.

Run this on node1:

```bash
sudo docker node promote node2
sudo docker node promote node3
```
Check the nodes by running the command:
```bash
sudo docker node ls
```

---

### Step 2— Navigate to the Swarm Watcher Directory (Node3)

Navigate to the watcher directory in node 3:

```bash
cd High-Availability-Video-Streaming-Using-Docker-Swarm/node3/swarm-watcher
```
Run this command to ensure swarm_watcher.sh is executable:
```bash
sudo chmod +x swarm_watcher.sh
```
---
### Step 3 — Label Node3

The watcher service must run only on Node3, so we add a node label.

Run this command on node 3:

```bash
sudo docker node update --label-add watcher=true node3
```

Verify the label:

```bash
sudo docker node inspect node3 --format '{{ .Spec.Labels }}'
```
---
### Step 3 — Create the Swarm Config

Create the docker swarm config `node-dict` from `dict.yaml` file located in the swarm-watcher directory by running the command:

```bash
sudo docker config create node-dict dict.yaml
```

Verify the config:

```bash
sudo docker config ls
```
---

### Step 4 — Build the Swarm Watcher Image


Build the image:

```bash
sudo docker build -t swarm-watcher:1.0 .
```

---

### Step 5 — Deploy the Watcher Service

Deploy the watcher service using the stack configuration:

```bash
sudo docker stack deploy -c docker-compose.yml swarm-watcher
```

Verify the service is running:

```bash
sudo docker service ls
```

Check which node it is scheduled on:

```bash
sudo docker service ps swarm-watcher_watcher
```

The service should run **only on Node3** due to the placement constraint.

---

### Step 6 — Test the Watcher

Simulate a node failure on node 2.

```bash
sudo systemctl stop docker
```

The watcher container will detect the failure and output logs such as:

```
ALERT node2 is DOWN
Identity -> this is node 2
```

View watcher logs by running this command on node 3:

```bash
sudo docker service logs swarm-watcher_watcher
```
---
## Phase 4 - Deploy Highly Available Website Services

In this task, two website services are deployed using Docker Swarm.  
Each website streams a video file using Nginx and is accessed through Virtual IPs managed by Keepalived.

The goal is to ensure that:

- Website A runs on node1
- Website B runs on node2
- node3 acts as a standby node.

If node1 or node2 fails, the corresponding website service will be will be taken over by node3, while Keepalived moves the VIP.

### Website Service Files

Each website is built from a small Nginx container image using the files stored in the repository.

- Website A (node1) folder contains:

  - `Dockerfile` – builds the Nginx container image
  - `default.conf` – Nginx configuration file
  - `index.html` – webpage served by Nginx
  - `video1.mp4` – video file streamed by the webpage

- Website B (node2) folder contains:

  - `Dockerfile`
  - `default.conf`
  - `index.html`
  - `video2.mp4`


---

### Step 1 - Promote Nodes to Manager

Before deploying services, ensure all nodes are managers to maintain quorum.

Run on **node1**:

```bash
sudo docker node promote node2
sudo docker node promote node3
```
---

### Step 2 - Assign Node Labels

Node labels are used to control where services are scheduled.

Run on a manager node:
```bash
sudo docker node update --label-add webA=true node1
sudo docker node update --label-add primaryA=true node1

sudo docker node update --label-add webB=true node2
sudo docker node update --label-add primaryB=true node2
```
Verify the label on each node:

```bash
sudo docker node inspect node1 --format '{{ .Spec.Labels }}'
```
```bash
sudo docker node inspect node2 --format '{{ .Spec.Labels }}'
```
```bash
sudo docker node inspect node3 --format '{{ .Spec.Labels }}'
```

---
### Step 3 - Prepare Docker Images for Deployment

Before deploying the website services, the images must be built and pushed to **Docker Hub** so that all nodes in the Swarm cluster can pull them.

- Create a Docker Hub Account

   If you do not already have a Docker Hub account, create one at: https://hub.docker.com/

- Login to Docker Hub

  Run the following command on all 3 nodes:

  ```bash
  sudo docker login
  ```
---
### Step 4 — Build and Push Website Images

Build the images for both websites.
- **Important Points**
   - The image tag used during the build command must match the image tag specified in `docker-compose.yml` file located at `High-Availability-Video-Streaming-Using-Docker-Swarm/node3/` in node3.
   - Also replace `<your-dockerhub-username>` with your own Docker Hub username in the following commands. And make sure to edit the `docker-compose.yml` file also with the correct docker hub username

- Website A

  Run on **node1**:

  ```bash
  cd High-Availability-Video-Streaming-Using-Docker-Swarm/node1/websiteA
  sudo docker build -t <your-dockerhub-username>/weba:1.2 .
  sudo docker push <your-dockerhub-username>/weba:1.2
  ```
- Website B

  Run on node2:
  ```bash
  cd High-Availability-Video-Streaming-Using-Docker-Swarm/node2/websiteB
  sudo docker build -t <your-dockerhub-username>/webb:1.2 .
  sudo docker push <your-dockerhub-username>/webb:1.2
  ```
### Step 5 - Update `docker-compose.yml` file in node 3
In node3:
```bash
cd High-Availability-Video-Streaming-Using-Docker-Swarm/node3
sudo nano docker-compose.yml
```
Update the image names so they use your Docker Hub username and the same image tag you used while building.

Example:
```bash
services:
  websiteA:
    image: <your-dockerhub-username>/weba:1.2

  websiteB:
    image: <your-dockerhub-username>/webb:1.2
```
### Step 6 - Deploy the Stack 
Run on node3: 
```bash
cd High-Availability-Video-Streaming-Using-Docker-Swarm/node3 
sudo docker stack deploy -c docker-compose.yml website-demo 
```
This will deploy both website services across the Docker Swarm cluster.

---

### Step 7 — Verify Service Deployment

- Check that the services are running in the swarm cluster.

  ```bash
  sudo docker service ls
  ```
  It should show that `MODE: REPLICATED` and `REPLICAS: 1/1` for both website services.


 - Check where the services are running:
   ```bash
   sudo docker service ps website-demo_websiteA
   sudo docker service ps website-demo_websiteB
   ```
   or
   ```bash
   sudo docker stack ps website-demo | grep Running
   ```
   It should show Website A running on `node1` and Website B running on `node2`.
---

### Step 8 — Access the Websites

Website A can be accessed at - `http://192.168.56.200:8080`

Website B can be accessed at - `http://192.168.56.201:8081`

---

### Step 9 — Test Failover

Simulate a node failure.
```bash
sudo systemctl stop docker
```
Check which node now owns the VIP:
```bash
ip a
```
- VIP `192.168.56.200` moves from node 1 to 3

- The websiteA service is rescheduled on node3

- Verify service placement:
   ```bash
   sudo docker service ps website-demo_websiteA
   ```
   or
   ```bash
   sudo docker stack ps website-demo | grep Running
   ```
Check the website again to make sure its still accessible, confirming that failover works correctly.

----


### Step 10 — Restore the Failed Node
On node1:
```bash
sudo systemctl start docker
sudo docker service update --force website-demo_websiteA
```