#!/bin/bash

dbuser=$1
dbpass=$2
environment=$3
clustername=$4

# Configure SELinux for permissive domains
semanage permissive -a init_t
semanage permissive -a cloud_init_t

host=$(GET http://169.254.169.254/latest/meta-data/instance-id | cut -d'-' -f 2) 
region=$(GET http://169.254.169.254/latest/meta-data/placement/availability-zone | rev | cut -c 2- | rev)

# Set host information
nmcli general hostname  "$clustername-$host" 
systemctl restart systemd-hostnamed 
echo "preserve_hostname: true" >> /etc/cloud/cloud.cfg 
sed -i -e "s/localhost4.localdomain4/localhost4.localdomain4 $clustername-$host/g" /etc/hosts

# Export proxies here
export NO_PROXY=169.254.169.254,127.0.0.1,localhost,/var/run/docker.sock
export no_proxy=169.254.169.254,127.0.0.1,localhost,/var/run/docker.sock

# Set proxies
cat <<EOF>> /etc/environment
NO_PROXY=$NO_PROXY
no_proxy=$NO_PROXY
EOF

# Enable additional repos
yum-config-manager --enable rhui-REGION-rhel-server-rhscl 
yum-config-manager --enable rhui-REGION-rhel-server-optional 
yum-config-manager --enable rhui-REGION-rhel-server-extras 

# Create config for awslogs agent with a generic stream
cat <<EOF> /etc/awslogs/awslogs.conf
[general]
state_file = /var/log/awslogs-state.log
[logstream1]
log_group_name = $clustername-$environment
log_stream_name = cloudinit
datetime_format = %Y-%m-%dT%H:%M:%SZ
time_zone = UTC
file = /var/log/cloud-init.log
EOF

# Install awslogs agent
curl -Lo awslogs-agent-setup.py "https://s3.amazonaws.com/aws-cloudwatch/downloads/latest/awslogs-agent-setup.py"
python ./awslogs-agent-setup.py -n -r "$region" -c /etc/awslogs/awslogs.conf

# Copy proxies in /etc/environment to awslogs proxies
cat /etc/environment > /var/awslogs/etc/proxy.conf

systemctl restart awslogs

# Install docker from RHUI extras repo
yum install -y unzip docker

# Install AWSCLI (optional)
curl -Lo awscli-bundle.zip "https://s3.amazonaws.com/aws-cli/awscli-bundle.zip"
unzip awscli-bundle.zip
./awscli-bundle/install -i /usr/local/aws -b /usr/bin/aws

# Configure docker with proxies
cat <<EOF>> /etc/sysconfig/docker 
NO_PROXY=$NO_PROXY
EOF

cat <<EOF>> /usr/lib/systemd/system/docker.service
[Service]
Environment=NO_PROXY=$NO_PROXY
EOF

# Create ECS Log directories
mkdir -p /var/lib/ecs/data /var/log/ecs

# Configure ECS agent systemd services
cat <<EOF> /etc/systemd/system/ecs-agent.service
[Unit]
Description=ecs-agent
Requires=docker.service
After=docker.service
[Service]
Restart=on-failure
TimeoutStartSec=0
ExecStartPre=-/usr/bin/docker kill ecs-agent
ExecStartPre=-/usr/bin/docker rm ecs-agent
ExecStartPre=/usr/bin/docker pull amazon/amazon-ecs-agent:latest
ExecStart=/usr/bin/docker run --name ecs-agent --volume=/var/run/docker.sock:/var/run/docker.sock --volume=/var/log/ecs/:/log:z --volume=/var/lib/ecs/data:/data:z --volume=/sys/fs/cgroup:/sys/fs/cgroup:ro --volume=/var/run/docker/execdriver/native:/var/lib/docker/execdriver/native:ro --publish=127.0.0.1:51678:51678 --env=ECS_LOGFILE=/log/ecs-agent.log --env=ECS_LOGLEVEL=info --env=ECS_DATADIR=/data --env=ECS_CLUSTER=$clustername --env=NO_PROXY=$NO_PROXY --privileged amazon/amazon-ecs-agent:latest
ExecStop=/usr/bin/docker stop ecs-agent
[Install]
WantedBy=multi-user.target
EOF

cat <<EOF> /etc/systemd/system/ecs-agent.timer 
[Unit] 
[Timer] 
OnStartupSec=2min 
[Install] 
WantedBy=multi-user.target 
EOF

# Configure app configs here
# Below is an example, you want to change this
{
  echo "dbuser: $dbuser"
  echo "dbpass: $dbpass"
} > /"$clustername".yml
if [[ $environment = "dev" ]]; then
{
  echo "debug: true"
} >> /"$clustername".yml
fi

# Ensure systemd services enabled and start
systemctl --system daemon-reload
systemctl start ntpd
systemctl enable docker.service
systemctl enable ecs-agent.service
systemctl enable ecs-agent.timer
systemctl start ecs-agent.timer