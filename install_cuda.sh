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
