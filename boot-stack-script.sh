#!/bin/bash
## forked from https://www.linode.com/stackscripts/view/?StackScriptID=3127
# <UDF name="ssh_key" Label="Paste in your public SSH key" default="" example="" optional="false" />
# <UDF name="private_ip" Label="Paste in your private ip" default="" example="" optional="false" />
# <UDF name="public_ip" Label="Paste in your public ip" default="" example="" optional="false" />
# <UDF name="default_gateway" Label="Paste in your default gateway" default="" example="" optional="false" />


# root ssh keys
mkdir /root/.ssh
echo $SSH_KEY >> /root/.ssh/authorized_keys
chmod 0700 /root/.ssh

# update to latest
apt-get update -y
apt-get upgrade -y

# install dependencies
apt-get install -y build-essential curl
apt-get install -y git || apt-get install -y git-core

# install node
apt-get install -y python-software-properties
apt-get install -y software-properties-common
add-apt-repository -y ppa:chris-lea/node.js
apt-get update
apt-get install -y nodejs
ln /usr/bin/node /usr/sbin/node

# install npm
curl https://npmjs.org/install.sh | sh

# setup a deploy user
useradd -U -s /bin/bash -m deploy

## NODE_ENV=production
echo 'export NODE_ENV=production' >> /home/deploy/.bashrc

## ssh directory
mkdir /home/deploy/.ssh
chmod -R 0700 /home/deploy/.ssh

## github known_hosts
ssh-keyscan -H github.com >> /home/deploy/.ssh/known_hosts

## ssh keys
echo $SSH_KEY >> /home/deploy/.ssh/authorized_keys

## permissions
chown -R deploy:deploy /home/deploy/.ssh

cd /home/deploy/
git clone https://github.com/sloanesturz/simple-node-proxy.git
cd simple-node-proxy
source ~/.bashrc
npm install

chown -R deploy:deploy /home/deploy/simple-node-proxy

# upstart script
# run node as `deploy` user.
cat <<'EOF' > /etc/init/node.conf 
description "node server"

start on filesystem or runlevel [2345]
stop on runlevel [!2345]

respawn
respawn limit 10 5
umask 022

script
  HOME=/home/deploy
  . $HOME/.profile
  exec sudo -u deploy /usr/bin/node $HOME/simple-node-proxy/js/lib/proxy.js >> $HOME/node.log 2>&1
end script

post-start script
  HOME=/home/deploy
  PID=`status node | awk '/post-start/ { print $4 }'`
  echo $PID > $HOME/app/shared/pids/node.pid
end script

post-stop script
  HOME=/home/deploy
  rm -f $HOME/app/shared/pids/node.pid
end script
EOF

# sudoers
cat <<EOF > /etc/sudoers.d/node
deploy     ALL=NOPASSWD: /sbin/restart node
deploy     ALL=NOPASSWD: /sbin/stop node
deploy     ALL=NOPASSWD: /sbin/start node
EOF
chmod 0440 /etc/sudoers.d/node

rm /etc/network/interfaces

cat <<EOF > /etc/network/interfaces
# The loopback interface
auto lo
iface lo inet loopback

# Configuration for eth0 and aliases

# This line ensures that the interface will be brought up during boot.
auto eth0 eth0:1

# eth0 - This is the main IP address that will be used for most outbound connections.
# The address, netmask and gateway are all necessary.
iface eth0 inet static
 address $PUBLIC_IP
 netmask 255.255.255.0
 gateway $DEFAULT_GATEWAY

# eth0:1 - Private IPs have no gateway (they are not publicly routable) so all you need to
# specify is the address and netmask.
iface eth0:1 inet static
 address $PRIVATE_IP
 netmask 255.255.128.0
EOF

/etc/init.d/networking restart
ping -c 5 $DEFAULT_GATEWAY   

# start the server.
start node
