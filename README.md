# dynamic-motd
Dynamic MOTD for short information when logging into your linux server

1. apt-get update && apt-get install figlet lsb-release bc needrestart wget -y
2. wget -O /usr/local/bin/dynmotd https://raw.githubusercontent.com/theonlybrand/dynamic-motd/master/dynmotd.sh
3. chmod +x /usr/local/bin/dynmotd
4. rm -f /etc/motd
5. echo /usr/local/bin/dynmotd >> /etc/profile
6. echo /usr/local/bin/dynmotd >> /etc/zsh/zprofile
