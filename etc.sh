#!/data/data/com.termux/files/usr/bin/bash

export GREEN='\033[0;32m'
export TURQ='\033[0;36m'
export URED='\033[4;31m'
export UYELLOW='\033[4;33m'
export WHITE='\033[0;37m'
export SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
export PROOT_ROOT=$PREFIX/var/lib/proot-distro/installed-rootfs/ubuntu/root

export TERMUX_WIDGET_LINK='https://github.com/termux/termux-widget/releases/download/v0.13.0/termux-widget_v0.13.0+github-debug.apk'

append_once() {
    local file=$1
    local marker=$2
    local block=$3
    if ! grep -Fq "$marker" "$file" 2>/dev/null; then
        printf '\n%s\n' "$block" >> "$file"
    fi
}

# termux 셋업
termux_base_setup()
{
    set -e
    sleep 1
    echo -e "${GREEN}termux 업데이트 && 업그레이드${WHITE}"
	pkg update -y && pkg upgrade -y
    sleep 1
    #echo -e "${GREEN}termux 외부앱 허용, 진동-> 무음으로 변경.${WHITE}"
    # 기본세팅 외부앱 사용가능
    #sleep 1
    #sed -i 's/# allow-external-apps = true/allow-external-apps = true/g' /data/data/com.termux/files/home/.termux/termux.properties
    echo -e "${GREEN}진동-> 무음으로 변경.${WHITE}"
    sleep 1
    sed -i 's/# bell-character = ignore/bell-character = ignore/g' /data/data/com.termux/files/home/.termux/termux.properties

    sleep 1
    echo -e "${GREEN} alias 설정.${WHITE}"
    bashrc_termux_block=$(cat <<'EOF'
# >>> termux-xfce-proof-etc >>>
alias ll='ls -alhF'
alias zink='MESA_LOADER_DRIVER_OVERRIDE=zink TU_DEBUG=noconform '
alias shutdown='kill -9 -1'

export LANG=ko_KR.UTF-8
export LC_MONETARY="ko_KR.UTF-8"
export LC_PAPER="ko_KR.UTF-8"
export LC_NAME="ko_KR.UTF-8"
export LC_ADDRESS="ko_KR.UTF-8"
export LC_TELEPHONE="ko_KR.UTF-8"
export LC_MEASUREMENT="ko_KR.UTF-8"
export LC_IDENTIFICATION="ko_KR.UTF-8"
export LC_ALL=
export XDG_CONFIG_HOME=/data/data/com.termux/files/home/.config
export XMODIFIERS=@im=fcitx5
export GTK_IM_MODULE=fcitx5
export QT_IM_MODULE=fcitx5
# <<< termux-xfce-proof-etc <<<
EOF
)
    append_once "$PREFIX/etc/bash.bashrc" "# >>> termux-xfce-proof-etc >>>" "$bashrc_termux_block"

    source $PREFIX/etc/bash.bashrc

    sleep 1
	echo -e "${GREEN}unzip설치.${WHITE}"
	pkg install -y unzip

    sleep 1
    echo -e "${GREEN}which 설치${WHITE}"
    pkg install -y which

    sleep 1
	echo -e "${GREEN}qt5 설치.${WHITE}"
	pkg install -y qt5*

    sleep 1
	echo -e "${GREEN}qt6 설치.${WHITE}"
	pkg install -y qt6*

    echo -e "${GREEN}tur-repo추가${WHITE}"
    pkg install -y tur-repo
    if ! grep -q "tur-multilib tur-hacking" ~/../usr/etc/apt/sources.list.d/tur.list; then
        sed -i 's/$/ tur-multilib tur-hacking/' ~/../usr/etc/apt/sources.list.d/tur.list
    fi

    sleep 1
    echo -e "${GREEN}x11-repo, root-repo 설치${WHITE}"
    pkg install x11-repo -y
	pkg install root-repo -y
	pkg update -y && pkg upgrade -y


    sleep 1
    echo -e "${GREEN}한글 설치 ${WHITE}"
    pkg install fcitx5* -y
    pkg install libhangul libhangul-static -y


    sleep 1
    apt autoclean -y
    apt autoremove -y


    sleep 1
    echo -e "${GREEN}Termux-widget 설치.${WHITE}"
    wget $TERMUX_WIDGET_LINK -O termux-widget_v0.13.0+github-debug.apk
	termux-open termux-widget_v0.13.0+github-debug.apk

	echo -e "${GREEN}termux widget 설치파일 삭제.${WHITE}"
    rm termux-widget*.apk

    echo -e "${GREEN}shortcuts 생성.${WHITE}"
    mkdir ~/.shortcuts

    cat <<'EOF' > ~/.shortcuts/startXFCE
#!/data/data/com.termux/files/usr/bin/bash
DISPLAY_NUM="${DISPLAY:-:0}"

killall -9 termux-x11 Xwayland pulseaudio virgl_test_server_android virgl_test_server

termux-wake-lock; XDG_RUNTIME_DIR=${TMPDIR} termux-x11 "$DISPLAY_NUM" &
sleep 1

am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity
sleep 1

LD_PRELOAD=/system/lib64/libskcodec.so pulseaudio --start --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" --exit-idle-time=-1
LD_PRELOAD=/system/lib64/libskcodec.so pacmd load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1

env DISPLAY="$DISPLAY_NUM" MESA_LOADER_DRIVER_OVERRIDE=kgsl TU_DEBUG=noconform dbus-launch --exit-with-session xfce4-session &
#env DISPLAY="$DISPLAY_NUM" MESA_LOADER_DRIVER_OVERRIDE=zink TU_DEBUG=noconform dbus-launch --exit-with-session xfce4-session &
#env DISPLAY="$DISPLAY_NUM" dbus-launch --exit-with-session xfce4-session &
EOF

    chmod +x ~/.shortcuts/startXFCE

    sleep 1
    cat <<'EOF' > $PREFIX/bin/startXFCE
#!/data/data/com.termux/files/usr/bin/bash
exec "$HOME/.shortcuts/startXFCE" "$@"
EOF
    chmod +x $PREFIX/bin/startXFCE
}


termux_gpu_accel_install()
{
    set -e
    sleep 1
    echo -e "${GREEN}mesa ${WHITE}"
	pkg install -y mesa mesa-demos mesa-dev osmesa osmesa-demos 

    sleep 1
    echo -e "${GREEN}mesa-vulkan-icd-freedreno-dri3 설치-Adreno GPU가 장착된 장치에서 Vulkan API를 사용하기 위한 환경을 제공합니다. ${WHITE}"
    pkg install -y mesa-vulkan-icd-freedreno-dri3

}
termux_gpu_accel_dev_install(){
    sleep 1
    echo -e "${GREEN}clvk 설치 - OpenCL을 Vulkan으로 매핑하는 계층(library)입니다.${WHITE}"
	pkg install -y clvk

    sleep 1
    echo -e "${GREEN}clinfo 설치 - 설치된 OpenCL 플랫폼과 디바이스의 정보를 확인하여 디버깅 및 설정 확인에 사용됩니다. ${WHITE}"
	pkg install -y clinfo

    sleep 1
    echo -e "${GREEN}gtkmm4 설치- GUI 애플리케이션을 C++로 개발할 때 GTK+ 4의 기능을 객체 지향적으로 사용할 수 있도록 지원합니다.${WHITE}"
	pkg install -y gtkmm4

    sleep 1
    echo -e "${GREEN}libsigc++-3.0 설치 - GTKmm 등에서 콜백 함수 구현 시 사용됩니다.${WHITE}"
	pkg install -y libsigc++-3.0

    sleep 1
    echo -e "${GREEN} libcairomm-1.16 설치 - 2D 그래픽 렌더링을 더 쉽게 구현할 수 있도록 지원합니다.${WHITE}"
	pkg install -y libcairomm-1.16

    sleep 1
    echo -e "${GREEN} libglibmm-2.68 설치 - GLib의 데이터 구조와 이벤트 루프 기능을 C++에서 사용할 수 있게 합니다.${WHITE}"
	pkg install -y libglibmm-2.68

    sleep 1
    echo -e "${GREEN} libpangomm-2.48 설치 - 텍스트 렌더링 및 레이아웃 관련 작업을 C++에서 지원합니다. ${WHITE}"
	pkg install -y libpangomm-2.48

    sleep 1
    echo -e "${GREEN} swig 설치 - C/C++ 라이브러리를 Python, Java, Ruby 같은 언어에서 사용할 수 있도록 인터페이스를 생성합니다. ${WHITE}"
	pkg install -y swig

    sleep 1
    echo -e "${GREEN} libpeas 설치 - GTK 기반 애플리케이션에서 플러그인 기능을 쉽게 추가 및 관리할 수 있도록 지원합니다.${WHITE}"
	pkg install -y libpeas
}

termux_hangover_wine_install()
{
    set -e
    sleep 1
    echo -e "${GREEN}tur-multilib, tur-hacking 저장소 추가${WHITE}"

    if !grep -q "tur-multilib tur-hacking" ~/../usr/etc/apt/sources.list.d/tur.list; then
        sed -i 's/$/ tur-multilib tur-hacking/' ~/../usr/etc/apt/sources.list.d/tur.list
    fi
    sleep 1

    echo -e "${GREEN}의존프로그램 설치${WHITE}"
	pkg install -y cabextract clang 7zip freetype gnutls libandroid-shmem-static libx11 xorgproto mesa-demos libdrm libpixman libxfixes libjpeg-turbo xtrans libxxf86vm xorg-xrandr xorg-font-util xorg-util-macros libxfont2 libxkbfile libpciaccess xcb-util-renderutil xcb-util-image xcb-util-keysyms xcb-util-wm xorg-xkbcomp xkeyboard-config libxdamage libxinerama libxshmfence

    sleep 1
    echo -e "${GREEN}hangover-wine 설치${WHITE}"
    pkg install -y hangover-wine
    sleep 1
    echo -e "${GREEN}winetricks 설치${WHITE}"
    pkg install -y winetricks

}

termux_base_setup

echo -e "${UYELLOW}gpu 가속(mesa-zink, mesa-vulkan-icd-freedreno-dri3)을 설치하겠습니까?(y/n)${WHITE}"  
read yn
	case $yn in 
		y ) echo -e "${GREEN}gpu 가속을 설치합니다.${WHITE}"
            termux_gpu_accel_install
            ;;
		* ) echo -e "${GREEN}설치를 하지 않습니다.${WHITE}"
            ;;
	esac

echo -e "${UYELLOW}gpu 가속 dev 관련(clvk 등)을 설치하겠습니까?(y/n)${WHITE}"  
read yn
	case $yn in 
		y ) echo -e "${GREEN}gpu 가속을 설치합니다.${WHITE}"
            termux_gpu_accel_dev_install
            ;;
		* ) echo -e "${GREEN}설치를 하지 않습니다.${WHITE}"
            ;;
	esac
#termux_hangover_wine_install
