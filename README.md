# dynamic-motd
Dynamic MOTD for short information when logging into your linux server

1.  Debian -> apt-get update && apt-get install figlet lsb-release bc needrestart wget -y
    CentOS -> yum update && yum install figlet redhat-lsb-core bc needrestart wget
2. wget -O /usr/local/bin/dynmotd https://raw.githubusercontent.com/theonlybrand/dynamic-motd/master/dynmotd.sh
3. chmod +x /usr/local/bin/dynmotd
4. rm -f /etc/motd
5. mkdir /usr/local/bin/dynmotd
6. touch /etc/profile
7. echo /usr/local/bin/dynmotd >> /etc/profile
8. touch /etc/zsh/zprofile
9. echo /usr/local/bin/dynmotd >> /etc/zsh/zprofile


Upcoming changes
- initial customizing of MOTD
