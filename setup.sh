#!/usr/bin/env bash
# =============================================================================
# setup.sh  –  Build containers, install Ansible, wire SSH keys
# Run once from the docker-ansible/ directory:
#   chmod +x setup.sh && ./setup.sh
# =============================================================================
set -euo pipefail

YELLOW='\033[1;33m'; GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${YELLOW}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
err()   { echo -e "${RED}[ERR]${NC}   $*"; exit 1; }

# ── 0. Prerequisites ──────────────────────────────────────────────────────────
command -v docker        &>/dev/null || err "docker not found – install it first"
command -v docker-compose &>/dev/null || \
  docker compose version &>/dev/null || err "docker compose not found"

# Use 'docker compose' (v2) or 'docker-compose' (v1)
DC="docker compose"
$DC version &>/dev/null || DC="docker-compose"

# ── 1. Install Ansible on the Rocky 9 host ───────────────────────────────────
info "Installing Ansible on this Rocky 9 host..."
if ! command -v ansible &>/dev/null; then
  sudo dnf install -y epel-release
  sudo dnf install -y ansible
  ok "Ansible installed: $(ansible --version | head -1)"
else
  ok "Ansible already installed: $(ansible --version | head -1)"
fi

# Install required Ansible collections
info "Installing Ansible collections..."
ansible-galaxy collection install ansible.posix community.mysql --force-with-deps
ok "Collections installed"

# ── 2. Generate SSH key for ansible user ─────────────────────────────────────
SSH_KEY="$HOME/.ssh/ansible_lab"
if [[ ! -f "$SSH_KEY" ]]; then
  info "Generating SSH key pair at $SSH_KEY ..."
  mkdir -p "$HOME/.ssh"
  ssh-keygen -t ed25519 -C "ansible-lab" -f "$SSH_KEY" -N ""
  ok "SSH key generated"
else
  ok "SSH key already exists: $SSH_KEY"
fi

# ── 3. Build and start containers ─────────────────────────────────────────────
info "Building Docker images (this takes a few minutes first time)..."
$DC build

info "Starting containers..."
$DC up -d

info "Waiting 15 seconds for systemd to initialise inside containers..."
sleep 15

# ── 4. Copy SSH public key into containers ────────────────────────────────────
info "Installing SSH public key into containers..."

PUB_KEY=$(cat "${SSH_KEY}.pub")

for CONTAINER in node01 node02; do
  docker exec "$CONTAINER" bash -c "
    mkdir -p /home/ansible/.ssh
    echo '${PUB_KEY}' >> /home/ansible/.ssh/authorized_keys
    chmod 600 /home/ansible/.ssh/authorized_keys
    chown -R ansible:ansible /home/ansible/.ssh
  "
  ok "Key installed in $CONTAINER"
done

# ── 5. Add container hostnames to host /etc/hosts ────────────────────────────
info "Adding hostnames to /etc/hosts (requires sudo)..."

declare -A HOSTS=(
  ["172.20.0.10"]="node01.example.com webserver.example.com"
  ["172.20.0.20"]="node02.example.com jenkins.example.com dbserver1.example.com"
)

for IP in "${!HOSTS[@]}"; do
  NAMES="${HOSTS[$IP]}"
  # Remove old entries, add new
  sudo sed -i "/$NAMES/d" /etc/hosts 2>/dev/null || true
  echo "$IP  $NAMES" | sudo tee -a /etc/hosts > /dev/null
  ok "Added: $IP  $NAMES"
done

# ── 6. Update ansible.cfg to use our SSH key ─────────────────────────────────
info "Patching ansible.cfg files to use $SSH_KEY ..."
find "$(dirname "$0")" -name "ansible.cfg" | while read -r CFG; do
  # Add or update private_key_file line
  if grep -q "private_key_file" "$CFG"; then
    sed -i "s|private_key_file.*|private_key_file = $SSH_KEY|" "$CFG"
  else
    sed -i "/\[defaults\]/a private_key_file = $SSH_KEY" "$CFG"
  fi
  ok "Patched: $CFG"
done

# ── 7. Verify connectivity ────────────────────────────────────────────────────
info "Testing Ansible ping to all nodes..."
cd "$(dirname "$0")/lab1"

ansible all -i inventory \
  -m ping \
  --private-key "$SSH_KEY" \
  -u ansible && ok "All nodes reachable!" || {
  echo ""
  info "Ping failed – trying manual SSH to debug:"
  ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no \
      -p 2201 ansible@localhost "echo Ubuntu OK" || true
  ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no \
      -p 2202 ansible@localhost "echo Rocky OK" || true
}

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Setup complete!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "  Containers:  docker ps"
echo "  Ubuntu SSH:  ssh -i $SSH_KEY -p 2201 ansible@localhost"
echo "  Rocky  SSH:  ssh -i $SSH_KEY -p 2202 ansible@localhost"
echo ""
echo "  Run Lab1:    cd lab1/iti-webserver && ansible-playbook site.yml"
echo "  Run Lab2:    cd lab2/lab2          && ansible-playbook site.yml"
echo "  Run MariaDB: cd lab2/mariadb-server && ansible-playbook site.yml --ask-vault-pass"
echo ""
