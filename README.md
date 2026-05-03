# Ansible Automation Labs

**By:** Eman Tarek  

---

## 📋 Project Overview

Two Ansible automation labs implemented as part of the ITI TelecomCloud DevOps curriculum, covering ad-hoc commands, playbooks, roles, Ansible Vault, and service deployment across heterogeneous Linux nodes — all running locally on Docker containers instead of cloud EC2 instances.

---

## 🏗️ Environment Architecture

Rocky Linux 9 VM (Control Node - 192.168.44.140)
│
├── node01 [Ubuntu 22.04 Container] - 172.20.0.10
│     • webserver.example.com
│     • Nginx web server target
│
└── node02 [Rocky Linux 9 Container] - 172.20.0.20
• jenkins.example.com
• dbserver1.example.com
• Jenkins CI/CD + MariaDB targe


| Component | Details |
|-----------|---------|
| Control Node | Rocky Linux 9 VM |
| Managed Nodes | Ubuntu 22.04 + Rocky Linux 9 (Docker containers) |
| Ansible Version | ansible-core 2.14.18 |
| Docker Compose | v2 (docker-compose-plugin) |
| Collections | ansible.posix, community.mysql |

---

## 📁 Project Structure

docker-ansible/
├── docker-compose.yml
├── Jenkinsfile
├── dockerfiles/
│   ├── Dockerfile.ubuntu
│   └── Dockerfile.rocky
├── lab1/
│   ├── ansible.cfg
│   ├── inventory
│   └── iti-webserver/
│       ├── site.yml
│       ├── ansible.cfg
│       ├── inventory
│       └── templates/
│           └── index.html.j2
└── lab2/
├── lab2/
│   ├── site.yml
│   ├── ansible.cfg
│   ├── inventory
│   └── roles/
│       ├── iti-webserver-role/
│       │   ├── tasks/main.yml
│       │   ├── handlers/main.yml
│       │   ├── defaults/main.yml
│       │   └── templates/index.html.j2
│       └── jenkins-role/
│           ├── tasks/main.yml
│           └── handlers/main.yml
└── mariadb-server/
├── site.yml
├── ansible.cfg
├── inventory
├── templates/
│   └── my_credentials.cnf.j2
└── vars/
└── vault.yml  ← encrypted with ansible-vault

---

## 🚀 Quick Start

### 1. Start the Docker containers
```bash
cd docker-ansible
chmod +x setup.sh
./setup.sh
```

### 2. Verify connectivity
```bash
cd lab1
ansible servers -m ping
```

---

## 🧪 Lab 01

### Question 1 – Ad-hoc Commands

```bash
cd lab1

# Ping all nodes
ansible servers -m ping

# Create user greenie with UID 4000
ansible servers -m ansible.builtin.user \
  -a "name=greenie uid=4000 state=present" --become

# Verify
ansible servers -m ansible.builtin.command -a "id greenie"
```

### Question 2 – ITI Web Server (Nginx)

```bash
cd lab1/iti-webserver

# Run playbook
ansible-playbook site.yml

# Test
curl http://node01.example.com
# Browser: http://192.168.44.140:8081
```

**Features:**
- Multi-distro support (apt for Ubuntu / dnf for Rocky)
- Jinja2 template with student name, hostname, and private IP
- Idempotent with handler-based Nginx reload

---

## 🧪 Lab 02

### Question 1 – Ansible Roles (Webserver + Jenkins)

```bash
cd lab2/lab2

ansible-playbook site.yml

# Test Nginx
curl http://webserver.example.com

# Test Jenkins
# Browser: http://192.168.44.140:8080
```

**Roles:**
| Role | Target | Service |
|------|--------|---------|
| iti-webserver-role | webserver.example.com | Nginx |
| jenkins-role | jenkins.example.com | Jenkins 2.555.1 |

**Jenkins notes:**
- Requires Java 21 (java-21-openjdk)
- Started with `nohup java -jar jenkins.war` (no systemd)
- `alternatives --set` used to set Java 21 as default

### Question 2 – MariaDB with Ansible Vault

```bash
cd lab2/mariadb-server

# Encrypt vault file (first time only)
ansible-vault encrypt vars/vault.yml

# Run playbook
ansible-playbook site.yml --ask-vault-pass

# Verify MariaDB login
docker exec -it node02 mysql -u root -h 127.0.0.1 -P 3306 -pansible_iti@2022
```

**Features:**
- mysql_install_db initializes data directory
- Root password secured with Ansible Vault
- Anonymous users and test DB removed
- Credentials written to /root/.my.cnf

---

## 🔁 CI/CD Pipeline (Jenkins)

Pipeline stages:
1. **Checkout** – pull from GitHub
2. **Syntax Check** – validate all playbooks
3. **Lint** – ansible-lint checks

To trigger: Jenkins → ansible-lab → Build Now

---

## 🔧 Common Commands

```bash
# Check containers are running
docker ps

# Restart containers
docker compose up -d

# Shell into Ubuntu container
docker exec -it node01 bash

# Shell into Rocky container
docker exec -it node02 bash

# bash script to run the project
./setup.sh
```

---

## ⚠️ Key Challenges Solved

| Challenge | Solution |
|-----------|----------|
| Containers exiting immediately | Replaced systemd with `sshd -D` as PID 1 |
| curl-minimal conflict in Rocky | Added `--allowerasing` to dnf install |
| Ubuntu SSH key auth rejected | Used `ansible_password` in inventory |
| Jenkins requires Java 21 | Upgraded to java-21-openjdk |
| No systemd in containers | Started services directly via shell/nohup |
| MariaDB tables missing | Added `mysql_install_db` initialization task |

---

*ITI TelecomCloud Track — Eman Tarek — May 2026*
