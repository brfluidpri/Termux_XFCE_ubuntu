#!/data/data/com.termux/files/usr/bin/bash

username="$1"
BASE_RAW_URL="https://raw.githubusercontent.com/brfluidpri/Termux_XFCE_ubuntu/main"

append_once() {
	local file=$1
	local marker=$2
	local block=$3
	if ! grep -Fq "$marker" "$file" 2>/dev/null; then
		printf '\n%s\n' "$block" >> "$file"
	fi
}

pkgs=('git' 'neofetch' 'virglrenderer-android' 'papirus-icon-theme' 'xfce4' 'xfce4-goodies' 'eza' 'pavucontrol-qt' 'bat' 'jq' 'wmctrl' 'firefox' 'netcat-openbsd' 'termux-x11-nightly' 'libuv')

#Install xfce4 desktop and additional packages
pkg install "${pkgs[@]}" -y -o Dpkg::Options::="--force-confold"

#Put Firefox icon on Desktop
cp $PREFIX/share/applications/firefox.desktop $HOME/Desktop 
chmod +x $HOME/Desktop/firefox.desktop

#Set aliases
bashrc_alias_block=$(cat <<EOF
# >>> termux-xfce-proof-xfce >>>
alias ubuntu='proot-distro login ubuntu --user $username --shared-tmp'
alias hud='GALLIUM_HUD=fps '
alias ls='eza -lF --icons'
alias cat='bat '
# <<< termux-xfce-proof-xfce <<<
EOF
)
append_once "$PREFIX/etc/bash.bashrc" "# >>> termux-xfce-proof-xfce >>>" "$bashrc_alias_block"

#Download Wallpaper
wget "$BASE_RAW_URL/dark_waves.png"
wget "$BASE_RAW_URL/TheSolarSystem.jpg"
mv dark_waves.png $PREFIX/share/backgrounds/xfce/
mv TheSolarSystem.jpg $PREFIX/share/backgrounds/xfce/

#Install WhiteSur-Dark Theme
wget https://github.com/vinceliuice/WhiteSur-gtk-theme/archive/refs/tags/2024-11-18.zip
unzip 2024-11-18.zip
tar -xf WhiteSur-gtk-theme-2024-11-18/release/WhiteSur-Dark.tar.xz
mv WhiteSur-Dark/ $PREFIX/share/themes/
rm -rf WhiteSur*
rm 2024-11-18.zip

#Install Fluent Cursor Icon Theme
wget https://github.com/vinceliuice/Fluent-icon-theme/archive/refs/tags/2024-02-25.zip
unzip 2024-02-25.zip
mv Fluent-icon-theme-2024-02-25/cursors/dist $PREFIX/share/icons/ 
mv Fluent-icon-theme-2024-02-25/cursors/dist-dark $PREFIX/share/icons/
rm -rf $HOME/Fluent*
rm 2024-02-25.zip

#Setup Fonts
wget https://github.com/microsoft/cascadia-code/releases/download/v2111.01/CascadiaCode-2111.01.zip
mkdir .fonts 
unzip CascadiaCode-2111.01.zip
mv otf/static/* .fonts/ && rm -rf otf
mv ttf/* .fonts/ && rm -rf ttf/
rm -rf woff2/ && rm -rf CascadiaCode-2111.01.zip

wget https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/Meslo.zip
unzip Meslo.zip
mv *.ttf .fonts/
rm Meslo.zip
rm LICENSE.txt
rm readme.md

wget "$BASE_RAW_URL/NotoColorEmoji-Regular.ttf"
mv NotoColorEmoji-Regular.ttf .fonts

wget "$BASE_RAW_URL/font.ttf"
mv font.ttf .termux/font.ttf

#Setup Fancybash Termux
wget "$BASE_RAW_URL/fancybash.sh"
mv fancybash.sh .fancybash.sh
bashrc_fancy_block=$(cat <<'EOF'
# >>> termux-xfce-proof-fancybash >>>
source $HOME/.fancybash.sh
# <<< termux-xfce-proof-fancybash <<<
EOF
)
append_once "$PREFIX/etc/bash.bashrc" "# >>> termux-xfce-proof-fancybash >>>" "$bashrc_fancy_block"
sed -i "326s/\\\u/$username/" $HOME/.fancybash.sh
sed -i "327s/\\\h/termux/" $HOME/.fancybash.sh

#Autostart Conky and Flameshot
wget "$BASE_RAW_URL/config.tar.gz"
tar -xvzf config.tar.gz
rm config.tar.gz
chmod +x .config/autostart/conky.desktop
chmod +x .config/autostart/org.flameshot.Flameshot.desktop
