# ZJU3DV-ServerConfiguration
This is a guidance for new server configuration 

## MENU  
**线下部分**  
1.系统安装  
2.配置网络  
3.更新浙大源  
4.配置个人账号

**远程部分**  
5.配置remote nfs盘  
6.安装nvidia驱动和cuda  
7.配置proxy  
8.常用软件安装
9.使用systemd创建自启动服务

### 1. 装系统：ubuntu最新lts系统

机器命名：[https://www.notion.so/haotong/d4fb021589ce4838829b13079d797de3?v=8d5ec6fede6245a8a66a02361c6176a1&pvs=4](https://www.notion.so/d4fb021589ce4838829b13079d797de3?pvs=21)  
安装完成后将配置与ip填入notion表格中  
```
机器名：zjuvxx  
用户名：zju3dv  
密码：
```

### 2. 配置网络

在ubuntu有线网络设置界面，将ipv4的`DHCP`选项改为`Manual `   
尝试ping`10.76.5.`选择一个ping不通的ip  
`Netmask`设置为255.255.255.248，`Gateway`设置为10.76.0.10  
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

首先查询uid和gid，然后添加账号
```
sudo groupadd linhaotong -g 20191000
sudo useradd linhaotong -u 20191000 -g 20191000 -s /usr/bin/zsh -m -p $(perl -e 'print crypt($ARGV[0], "password")' 'linhaotong@zju3dv')
sudo usermod -aG sudo linhaotong
```
建议将上面的内容和`public key`写在一个sh内，这个sh存在已配好的服务器上，方便使用

接下来**建议关闭系统自动更新**，防止因为内核更新导致的显卡/网卡掉了的问题  


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
D001 -fstype=nfs4 10.76.2.98:/mnt/data
D002 -fstype=nfs4 10.76.5.252:/mnt/data
D003 -fstype=nfs4 10.76.2.112:/mnt/data
D004 -fstype=nfs4 10.76.5.255:/mnt/data
D005 -fstype=nfs4 10.76.5.241:/mnt/data
D006 -fstype=nfs4 10.76.5.248:/mnt/data

sudo service autofs restart
```

### 6. 安装nvidia驱动和cuda

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