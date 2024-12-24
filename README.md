# ZJU3DV-ServerConfiguration
This is a guidance for new server configuration 

## MENU  
**线下部分**  
[1.系统安装](#1-装系统ubuntu最新lts系统--1)  
[2.配置网络](#2-配置网络)  
[3.更新浙大源](#3-更新浙大源)  
[4.配置个人账号](#4-配置sudo个人账号)

**远程部分**  
[5.配置remote nfs盘](#5-配置remote-nfs盘)  
[6.安装nvidia驱动和cuda](#6-安装nvidia驱动和cuda)  
[7.配置proxy](#7-配置proxy)  
[8.常用软件安装](#8-常用软件安装)  
[9.使用systemd创建自启动服务](#9-使用systemd创建自启动服务)

### 1. 装系统：ubuntu最新lts系统  

机器命名：询问admin获得notion表格  
安装完成后将配置与ip填入notion表格中  
```
机器名：zjuvxx  
用户名：zju3dv  
密码：
```

### 2. 配置网络

在ubuntu有线网络设置界面，将ipv4的`DHCP`选项改为`Manual `   
尝试ping`10.76.5.`选择一个ping不通的ip  
`Netmask`设置为255.255.248.0，`Gateway`设置为10.76.0.10  
`DNS`为10.10.0.21

### 3. 更新浙大源

首先备份默认源  
```
sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak
```
访问 mirrors.zju.edu.cn，选择系统版本后得到类似如下指令, 替换源文件内容
```
deb https://mirrors.zju.edu.cn/ubuntu/ jammy main restricted universe multiverse
deb https://mirrors.zju.edu.cn/ubuntu/ jammy-updates main restricted universe multiverse
deb https://mirrors.zju.edu.cn/ubuntu/ jammy-backports main restricted universe multiverse
deb https://mirrors.zju.edu.cn/ubuntu/ jammy-security main restricted universe multiverse
```  
更新源，下载ssh和zsh
```
sudo apt update
sudo apt upgrade
sudo apt install openssh-server zsh
```

### 4. 配置sudo/个人账号

首先查询uid和gid，然后添加账号(访问10.76.5.248:12243，服务器zjuv06)
```
sudo groupadd $username -g $uid
sudo useradd $username -u $uid -g $uid -s /usr/bin/zsh -m -p $(perl -e 'print crypt($ARGV[0], "password")' '{yourpasswd}')
sudo usermod -aG sudo username
```
建议将上面的内容和`public key`写在一个sh内，这个sh存在已配好的服务器上，方便使用  
**！！IMPORTANT！！**: 关闭密码登录，防止服务器被攻击  
```
vim /etc/ssh/sshd_config
# 添加
PasswordAuthentication no
```

接下来**建议关闭系统自动更新**，防止因为内核更新导致的显卡/网卡掉了的问题  
```
# all switch to 0
sudo vim /etc/apt/apt.conf.d/20auto-upgrades
```

***

*下面开始可以从远程配置*

下载一些常用的工具
```
sudo apt install autofs zsh net-tools vim git tmux nfs-server nfs-kernel-server gcc g++  make cmake sshfs shadowsocks-libev privoxy htop
```

### 5. 配置remote nfs盘

#### 5.1 硬盘分区与挂载

找到数据盘的位置，这里演示的是`/dev/sda`
```
sudo fdisk -l
```
使用`GNU parted`工具对硬盘进行分区，并使用`mount`命令进行挂载
```
sudo parted /dev/sda

GNU Parted 3.2
Using /dev/sda
Welcome to GNU Parted! Type 'help' to view a list of commands.

(parted) help                           

  align-check TYPE N                        check partition N for TYPE(min|opt) alignment
  help [COMMAND]                           print general help, or help on COMMAND
  mklabel,mktable LABEL-TYPE               create a new disklabel (partition table)
  mkpart PART-TYPE [FS-TYPE] START END     make a partition
  name NUMBER NAME                         name partition NUMBER as NAME
  print [devices|free|list,all|NUMBER]     display the partition table, available devices, free space, all found partitions, or a particular partition
  quit                                     exit program
  rescue START END                         rescue a lost partition near START and END
  resizepart NUMBER END                    resize partition NUMBER
  rm NUMBER                                delete partition NUMBER
  select DEVICE                            choose the device to edit
  disk_set FLAG STATE                      change the FLAG on selected device
  disk_toggle [FLAG]                       toggle the state of FLAG on selected device
  set NUMBER FLAG STATE                    change the FLAG on partition NUMBER
  toggle [NUMBER [FLAG]]                   toggle the state of FLAG on partition NUMBER
  unit UNIT                                set the default unit to UNIT
  version                                  display the version number and copyright information of GNU Parted

(parted) mklabel gpt            

Warning: The existing disk label on /dev/sda will be destroyed and all data on this disk will be lost. Do you want to continue?
Yes/No? Yes     

(parted) mkpart         

Partition name?  []?                                                      
File system type?  [ext2]? ext4                                           
Start? 0%                                                                 
End? 100%         

(parted) print                

Model: ATA Samsung SSD 870 (scsi)
Disk /dev/sda: 4001GB
Sector size (logical/physical): 512B/512B
Partition Table: gpt
Disk Flags: 

Number  Start   End     Size    File system  Name  Flags
 1      1049kB  4001GB  4001GB  ext4

(parted) quit        

Information: You may need to update /etc/fstab.

# 格式化分区并挂载
sudo mkfs.ext4 /dev/sda1
sudo mount /dev/sda1 /mnt/data
```  
还需要配置开机自启动
```
#根据uuid查找硬盘
ls -l /dev/disk/by-uuid

total 0
lrwxrwxrwx 1 root root 15  7月 23 22:48 54024c64-2d2a-47fd-8632-5e30a3d33935 -> ../../nvme0n1p2
lrwxrwxrwx 1 root root 15  7月 23 22:48 8BDB-4912 -> ../../nvme0n1p1
lrwxrwxrwx 1 root root 10  7月 23 22:48 de4d9430-0fb5-4608-84de-4827e40b5ce0 -> ../../sda1

#开机自动挂载
sudo vim /etc/fstab
添加
UUID=de4d9430-0fb5-4608-84de-4827e40b5ce0 /mnt/data ext4 defaults 0 0

#挂载并查看是否成功
sudo mount -a
lsblk
```

#### 5.2 nfs映射硬盘

```
sudo vim /etc/exports
添加
/mnt/data 10.76.0.0/16(rw,sync,no_subtree_check)
```

#### 5.3 autofs挂载硬盘

autofs挂载后只需访问就会自动挂载目标盘
```
sudo vim /etc/auto.master
添加
/mnt/remote /etc/auto.nfs 
```
注意，在加入新服务器后，其他服务器的`/etc/auto.nfs`文件也需更新
```
sudo vim /etc/auto.nfs
添加
ip地址与硬盘名称（询问管理员）

sudo service autofs restart
```

### 6. 安装nvidia驱动和cuda
见`install_cuda.sh`
```
#nvidia-drivers
sudo apt-get remove --purge nvidia*
sudo vim /etc/modprobe.d/blacklist-nouveau.conf
### 添加 
### blacklist nouveau
### options nouveau modeset=0

sudo update-initramfs -u
sudo reboot
lsmod | grep nouveau

cd /mnt/remote/D005/Softwares

sudo service gdm3 stop
sudo chmod a+x NVIDIA-Linux-x86_64-550.100.run
sudo ./NVIDIA-Linux-x86_64-550.100.run --no-opengl-lib
sudo service gdm3 restart

nvidia-smi

#cuda
sudo wget https://developer.download.nvidia.com/compute/cuda/12.1.1/local_installers/cuda_12.1.1_530
.30.02_linux.run
sudo sh cuda_12.1.1_530.30.02_linux.run

export PATH="/usr/local/cuda-{version}/bin:$PATH"
export LD_LIBRARY_PATH="/usr/local/cuda-{version}/lib64/:$LD_LIBRARY_PATH"

#cudnn
sudo dpkg -i cuda-keyring_1.1-1_all.deb
sudo apt-get update
sudo apt-get -y install cudnn9-cuda-12
```

### 7. 配置proxy

```
sudo mv /etc/privoxy/config /etc/privoxy/config.bak
sudo touch /etc/privoxy/config
echo 'forward-socks5 / localhost:1080 .' | sudo tee -a  /etc/privoxy/config
echo 'listen-address localhost:8118' | sudo tee -a  /etc/privoxy/config
sudo service privoxy restart
sudo touch /usr/local/bin/proxy
echo '#!/bin/bash' | sudo tee -a  /usr/local/bin/proxy
echo 'export http_proxy=http://localhost:8118' | sudo tee -a  /usr/local/bin/proxy
echo 'export https_proxy=http://localhost:8118' | sudo tee -a  /usr/local/bin/proxy
echo '$*' | sudo tee -a  /usr/local/bin/proxy
sudo chmod 777 /usr/local/bin/proxy
```
```
 nohup ss-local -s 10.76.7.216 -p 9050 -k AYMk77B:PhX\|=n\>~ -m aes-256-cfb -l 1080 >/dev/null &
```
寻找代理进程的方法
```
ps aux | grep 'ss-local'
```

### 8. 常用软件安装

#### 8.1 安装docker

```
proxy curl https://get.docker.com | proxy sh \
  && sudo systemctl --now enable docker
```
```
distribution=$(. /etc/os-release;echo $ID$VERSION_ID) \
      && proxy curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
      && proxy curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | \
            sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
            sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
```
```
sudo apt-get update
sudo apt-get install -y nvidia-docker2
sudo systemctl restart docker
```
```
sudo groupadd docker
sudo usermod -aG docker $USER
```
配置代理
```
sudo mkdir -p /etc/systemd/system/docker.service.d
sudo vim /etc/systemd/system/docker.service.d/http_proxy.conf 
[Service] 
Environment="HTTP_PROXY=http://localhost:8118" 
Environment="HTTPS_PROXY=http://localhost:8118"
sudo systemctl daemon-reload
sudo systemctl restart docker
docker info
```

#### 8.2 安装blender

```
proxy wget https://mirror.clarkson.edu/blender/release/Blender4.0/blender-4.0.2-linux-x64.tar.xz
```

### 9. 使用systemd创建自启动服务

1.创建一个新的systemd服务文件，例如`/etc/systemd/system/mycustomservice.service`
```
[Unit]
Description=My Custom Startup Script

[Service]
ExecStart=/home/linhaotong/frp_0.34.3_linux_amd64/frpc_new -c /home/linhaotong/frp_0.34.3_linux_amd64/frpc_hz.ini

[Install]
WantedBy=multi-user.target
```

2.使该服务可用
```
sudo systemctl enable mycustomservice.service
```

3.可以选择现在启动服务，测试它是否正常工作
```
sudo systemctl start mycustomservice.service
```

创建一个ss-local service
```
sudo touch /etc/systemd/system/mysslocal.service
echo '[Unit]\nDescription=My Custom Startup Script to load sslocal\n' | sudo tee -a  /etc/systemd/system/mysslocal.service
echo '[Service]\nExecStart=ss-local -s 10.76.2.225 -p 9050 -k AYMk77B:PhX|=n>~ -l 1080 -m aes-256-cfb\n' | sudo tee -a /etc/systemd/system/mysslocal.service
echo '[Install]\nWantedBy=multi-user.target' | sudo tee -a /etc/systemd/system/mysslocal.service
sudo systemctl enable mysslocal.service
sudo systemctl start mysslocal.service
```
