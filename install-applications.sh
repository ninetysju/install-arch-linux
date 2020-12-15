#!/bin/bash -i

# Initialize
read -p 'Name: ' NAME
read -p 'Email: ' EMAIL
read -p 'Device: ' DEVICE

# Enable multilib support
sudo sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf

sudo pacman -Syu --noconfirm

install_yay() {
  sudo pacman -S --needed --noconfirm git base-devel
  git clone https://aur.archlinux.org/yay.git
  cd yay
  makepkg -si
}

install_web() {
  sudo pacman -S --noconfirm firefox
  yay -S --noconfirm google-chrome
}

install_multimedia() {
  # Spotify https://aur.archlinux.org/packages/spotify/
  curl -sS https://download.spotify.com/debian/pubkey_0D811D58.gpg | gpg --import -
  yay -S --noconfirm spotify
}

isntall_games() {
  sudo pacman -S --noconfirm steam lutris mumble discord
}

install_development() {
  sudo pacman -S --noconfirm git base-devel
  yay -S --noconfirm sublime-text-3 postman-bin

  echo "Install node and npm"
  sudo pacman -S --noconfirm nodejs npm

  echo "Install nvm"
  yay -S --noconfirm nvm
  echo 'source /usr/share/nvm/init-nvm.sh' >> ~/.bashrc

  echo "Install docker and docker-compose"
  sudo pacman -S --noconfirm docker docker-compose
  sudo systemctl enable docker.service
  sudo systemctl start docker.service
  sudo usermod -aG docker ${USER}

  echo "Configure Git"
  git config --global user.name $NAME
  git config --global user.email $EMAIL

  echo "Create SSH Key"
  sudo pacman -S --noconfirm openssh
  ssh-keygen -t rsa -b 4096 -C "$NAME ($DEVICE) <$EMAIL>"
}

install_work() {
  yay -S --noconfirm slack-desktop
  # Pulse secure https://wiki.archlinux.org/index.php/Pulse_Connect_Secure
  yay -S --noconfirm pulse-secure webkitgtk-bin icu64
  sudo systemctl enable sshd.service
  sudo systemctl start sshd.service
}

install_yay
install_web
install_multimedia
isntall_games
install_development
install_work

echo "Remove orphans"
sudo pacman -Rs $(pacman -Qdtq) --noconfirm
