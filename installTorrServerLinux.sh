#!/usr/bin/env bash
username="torrserver" # system user to add || root
dirInstall="/opt/torrserver" # путь установки torrserver
serviceName="torrserver" # имя службы: systemctl status torrserver.service
scriptname=$(basename "$(test -L "$0" && readlink "$0" || echo -e "$0")")
declare -A colors=( [black]=0 [red]=1 [green]=2 [yellow]=3 [blue]=4 [magenta]=5 [cyan]=6 [white]=7 )

# Global variables for version handling
specificVersion=""

# Constants
readonly REPO_URL="https://github.com/YouROK/TorrServer"
readonly REPO_API_URL="https://api.github.com/repos/YouROK/TorrServer"
readonly VERSION_PREFIX="MatriX"
readonly BINARY_NAME_PREFIX="TorrServer-linux"
readonly MIN_GLIBC_VERSION="2.32"
readonly MIN_VERSION_REQUIRING_GLIBC=136
readonly DEFAULT_PORT="8090"

#################################
#       F U N C T I O N S       #
#################################

colorize() {
    printf "%s%s%s" "$(tput setaf "${colors[$1]:-7}")" "$2" "$(tput op)"
}

# Utility functions to reduce code duplication
function getBinaryName() {
  echo "${BINARY_NAME_PREFIX}-${architecture}"
}

function getVersionTag() {
  local version="$1"
  echo "${VERSION_PREFIX}.${version}"
}

function buildDownloadUrl() {
  local target_version="$1"
  local binary_name="$2"

  if [[ "$target_version" == "latest" ]]; then
    echo "${REPO_URL}/releases/latest/download/${binary_name}"
  else
    echo "${REPO_URL}/releases/download/${target_version}/${binary_name}"
  fi
}

function downloadBinary() {
  local url="$1"
  local destination="$2"
  local version_info="$3"

  [[ $lang == "en" ]] && echo -e " - Downloading TorrServer $version_info..." || echo -e " - Загружаем TorrServer $version_info..."
  curl -L --progress-bar -# -o "$destination" "$url"
  chmod +x "$destination"
}

function showVersionError() {
  local version="$1"
  [[ $lang == "en" ]] && {
    echo -e " - $(colorize red ERROR): Version $version not found in releases"
    echo -e " - Please check available versions at: $REPO_URL/releases"
  } || {
    echo -e " - $(colorize red ОШИБКА): Версия $version не найдена в релизах"
    echo -e " - Проверьте доступные версии по адресу: $REPO_URL/releases"
  }
}

function showGlibcError() {
  local target_version="$1"
  local current_glibc="$2"
  [[ $lang == "en" ]] && {
    echo -e " - $(colorize red ERROR): TorrServer version $target_version requires glibc >= $MIN_GLIBC_VERSION"
    echo -e " - Your system has glibc $current_glibc"
    echo -e " - Please install a version < $MIN_VERSION_REQUIRING_GLIBC or upgrade your system"
  } || {
    echo -e " - $(colorize red ОШИБКА): TorrServer версии $target_version требует glibc >= $MIN_GLIBC_VERSION"
    echo -e " - В вашей системе установлена glibc $current_glibc"
    echo -e " - Пожалуйста, установите версию < $MIN_VERSION_REQUIRING_GLIBC или обновите систему"
  }
}

function isRoot() {
  if [ $EUID -ne 0 ]; then
    return 1
  fi
}

function addUser() {
  if isRoot; then
    [[ $username == "root" ]] && return 0
    grep -E "^$username" /etc/passwd >/dev/null
    if [ $? -eq 0 ]; then
      [[ $lang == "en" ]] && echo -e " - $username user exists!" || echo -e " - пользователь $username найден!"
      return 0
    else
      useradd --home-dir "$dirInstall" --create-home --shell /bin/false -c "TorrServer" "$username"
      [ $? -eq 0 ] && {
        chmod 755 "$dirInstall"
        [[ $lang == "en" ]] && echo -e " - User $username has been added to system!" || echo -e " - пользователь $username добавлен!"
      } || {
        [[ $lang == "en" ]] && echo -e " - Failed to add $username user!" || echo -e " - не удалось добавить пользователя $username!"
      }
    fi
  fi
}

function delUser() {
  if isRoot; then
    [[ $username == "root" ]] && return 0
    grep -E "^$username" /etc/passwd >/dev/null
    if [ $? -eq 0 ]; then
      userdel --remove "$username" 2>/dev/null # --force
      [ $? -eq 0 ] && {
        [[ $lang == "en" ]] && echo -e " - User $username has been removed from system!" || echo -e " - Пользователь $username удален!"
      } || {
        [[ $lang == "en" ]] && echo -e " - Failed to remove $username user!" || echo -e " - не удалось удалить пользователя $username!"
      }
    else
      [[ $lang == "en" ]] && echo -e " - $username - no such user!" || echo -e " - пользователь $username не найден!"
      return 1
    fi
  fi
}

function checkRunning() {
  runningPid=$(ps -ax|grep -i torrserver|grep -v grep|grep -v "$scriptname"|awk '{print $1}')
  echo $runningPid
}

function getLang() {
  lang=$(locale | grep LANG | cut -d= -f2 | tr -d '"' | cut -d_ -f1)
  [[ $lang != "ru" ]] && lang="en"
}

function getIP() {
  if command -v dig >/dev/null 2>&1; then
    serverIP=$(dig +short myip.opendns.com @resolver1.opendns.com)
  else
    serverIP=$(host myip.opendns.com resolver1.opendns.com | tail -n1 | cut -d' ' -f4-)
  fi
  # echo $serverIP
}

function uninstall() {
  checkArch
  checkInstalled
  [[ $lang == "en" ]] && {
    echo -e ""
    echo -e " TorrServer install dir - ${dirInstall}"
    echo -e ""
    echo -e " This action will delete TorrServer including all it's torrents, settings and files on path above!"
    echo -e ""
  } || {
    echo -e ""
    echo -e " Директория c TorrServer - ${dirInstall}"
    echo -e ""
    echo -e " Это действие удалит все данные TorrServer включая базу данных торрентов и настройки по указанному выше пути!"
    echo -e ""
  }
  [[ $lang == "en" ]] && read -p " Are you shure you want to delete TorrServer? ($(colorize red Y)es/$(colorize yellow N)o) " answer_del </dev/tty || read -p " Вы уверены что хотите удалить программу? ($(colorize red Y)es/$(colorize yellow N)o) " answer_del </dev/tty
  if [ "$answer_del" != "${answer_del#[YyДд]}" ]; then
    cleanup
    cleanAll
    [[ $lang == "en" ]] && echo -e " - TorrServer uninstalled!" || echo -e " - TorrServer удален из системы!"
    echo -e ""
  else
    echo -e ""
  fi
}

function cleanup() {
  systemctl stop $serviceName 2>/dev/null
  systemctl disable $serviceName 2>/dev/null
  rm -rf /usr/local/lib/systemd/system/$serviceName.service $dirInstall 2>/dev/null
  delUser
}

function cleanAll() { # guess other installs
  systemctl stop torr torrserver 2>/dev/null
  systemctl disable torr torrserver 2>/dev/null
  rm -rf /home/torrserver 2>/dev/null
  rm -rf /usr/local/torr 2>/dev/null
  rm -rf /opt/torr{,*} 2>/dev/null
  rm -f /{,etc,usr/local/lib}/systemd/system/tor{,r,rserver}.service 2>/dev/null
}

function getGlibcVersion() {
    local glibc_version

    # Try ldd --version (most reliable)
    if command -v ldd >/dev/null 2>&1; then
        glibc_version=$(ldd --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+' | head -n1)
        if [[ -n "$glibc_version" ]]; then
            echo "$glibc_version"
            return 0
        fi
    fi

    # Try getconf GNU_LIBC_VERSION
    if command -v getconf >/dev/null 2>&1; then
        glibc_version=$(getconf GNU_LIBC_VERSION 2>/dev/null | grep -oE '[0-9]+\.[0-9]+')
        if [[ -n "$glibc_version" ]]; then
            echo "$glibc_version"
            return 0
        fi
    fi

    # Try rpm package manager
    if command -v rpm >/dev/null 2>&1; then
        glibc_version=$(rpm -q glibc 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -n1)
        if [[ -n "$glibc_version" ]]; then
            echo "$glibc_version"
            return 0
        fi
    fi

    # Try dpkg package manager
    if command -v dpkg >/dev/null 2>&1; then
        glibc_version=$(dpkg -l libc6 2>/dev/null | awk '/^ii/ {print $3}' | grep -oE '[0-9]+\.[0-9]+' | head -n1)
        if [[ -n "$glibc_version" ]]; then
            echo "$glibc_version"
            return 0
        fi
    fi

    # If all methods fail, return empty
    return 1
}

function compareVersions() {
  # Compare version strings using sort -V (version sort)
  # Returns 0 if $1 >= $2, 1 otherwise
  local ver1="$1"
  local ver2="$2"

  # Use sort -V for proper version comparison
  local sorted_first=$(printf '%s\n' "$ver1" "$ver2" | sort -V | head -n1)

  # If ver2 comes first in sorted order, then ver1 >= ver2
  [[ "$sorted_first" == "$ver2" ]]
}

function checkGlibcCompatibility() {
  local target_version="$1"
  local version_number

  # Extract numeric version from version string (e.g., "MatriX.136" -> "136")
  if [[ "$target_version" =~ ${VERSION_PREFIX}\.([0-9]+) ]]; then
    version_number="${BASH_REMATCH[1]}"
  elif [[ "$target_version" =~ ^[0-9]+$ ]]; then
    version_number="$target_version"
  else
    [[ $lang == "en" ]] && echo -e " - Warning: Could not parse version number from $target_version" || echo -e " - Предупреждение: Не удалось извлечь номер версии из $target_version"
    return 0  # Assume compatible if we can't parse
  fi

  # Check if version requires glibc 2.32+
  if [[ $version_number -ge $MIN_VERSION_REQUIRING_GLIBC ]]; then
    local current_glibc=$(getGlibcVersion)

    if [[ -z "$current_glibc" ]]; then
      [[ $lang == "en" ]] && {
        echo -e " - Warning: Could not detect glibc version"
        echo -e " - TorrServer version $target_version requires glibc >= $MIN_GLIBC_VERSION"
        echo -e " - Installation may fail if your system doesn't meet this requirement"
      } || {
        echo -e " - Предупреждение: Не удалось определить версию glibc"
        echo -e " - TorrServer версии $target_version требует glibc >= $MIN_GLIBC_VERSION"
        echo -e " - Установка может завершиться неудачей, если система не соответствует требованиям"
      }
      return 0  # Continue installation anyway
    fi

    [[ $lang == "en" ]] && echo -e " - Detected glibc version: $current_glibc" || echo -e " - Обнаружена версия glibc: $current_glibc"

    if ! compareVersions "$current_glibc" "$MIN_GLIBC_VERSION"; then
      showGlibcError "$target_version" "$current_glibc"
      return 1
    fi

    [[ $lang == "en" ]] && echo -e " - $(colorize green OK): glibc version meets requirements for TorrServer $target_version" || echo -e " - $(colorize green OK): версия glibc соответствует требованиям для TorrServer $target_version"
  else
    [[ $lang == "en" ]] && echo -e " - TorrServer version $target_version: no special glibc requirements" || echo -e " - TorrServer версии $target_version: нет особых требований к glibc"
  fi

  return 0
}

function helpUsage() {
  [[ $lang == "en" ]] && echo -e "$scriptname
  -i | --install | install [version] - install latest release version or specific version
                                       Example: $scriptname --install 135
  -u | --update  | update  - install latest update (if any)
  -c | --check   | check   - check update (show only version info)
  -d | --down    | down    - version downgrade, need version number as argument
  -r | --remove  | remove  - uninstall TorrServer
  -h | --help    | help    - this help screen
" || echo -e "$scriptname
  -i | --install | install [версия] - установка последней версии или указанной версии
                                      Пример: $scriptname --install 135
  -u | --update  | update  - установка последнего обновления, если имеется
  -c | --check   | check   - проверка обновления (выводит только информацию о версиях)
  -d | --down    | down    - понизить версию, после опции указывается версия для понижения
  -r | --remove  | remove  - удаление TorrServer
  -h | --help    | help    - эта справка
"
}

# Helper function to show OS version error messages
function showOSVersionError() {
  local os_name="$1"
  local supported_versions="$2"

  [[ $lang == "en" ]] && {
    echo -e " Your $os_name version is not supported."
    echo -e ""
    echo -e " Script supports only $os_name $supported_versions"
    echo -e ""
  } || {
    echo -e " Ваша версия $os_name не поддерживается."
    echo -e ""
    echo -e " Скрипт поддерживает только $os_name $supported_versions"
    echo -e ""
  }
  exit 1
}

# Helper function to detect package manager for RPM-based systems
function getRpmPackageManager() {
  local version_id="$1"

  # Check if version_id is numeric and >= 8, then prefer dnf
  if [[ "$version_id" =~ ^[0-9]+$ ]] && [[ $version_id -ge 8 ]] && command -v dnf >/dev/null 2>&1; then
    echo "dnf"
  elif command -v dnf >/dev/null 2>&1; then
    echo "dnf"
  else
    echo "yum"
  fi
}

# Helper function to validate and handle RPM-based OS versions
function handleRpmBasedOS() {
  local os_id="$1"
  local os_name="$2"
  local supported_versions="$3"
  local version_id="$4"

  # Extract major version number (e.g., "8.4" -> "8", "9.6" -> "9")
  local major_version=$(echo "$version_id" | cut -d '.' -f1)

  # Validate version
  if [[ ! $major_version =~ ^($supported_versions)$ ]]; then
    showOSVersionError "$os_name" "версии $supported_versions"
  fi

  # Get package manager and install packages
  local pkg_manager=$(getRpmPackageManager "$major_version")
  installRpmPackages "$pkg_manager"
}

# Helper function to install RPM packages
function installRpmPackages() {
  local pkg_manager="$1"
  local packages=('curl' 'iputils' 'bind-utils')

  for pkg in "${packages[@]}"; do
    [ -z "$(rpm -qa "$pkg")" ] && $pkg_manager -y install "$pkg"
  done
}

function checkOS() {
  if [[ -e /etc/debian_version ]]; then
    OS="debian"
    PKGS='curl iputils-ping dnsutils'
    source /etc/os-release

    if [[ $ID == "debian" || $ID == "raspbian" ]]; then
      if [[ $VERSION_ID -lt 6 ]]; then
        showOSVersionError "Debian" ">=6"
      fi
    elif [[ $ID == "ubuntu" ]]; then
      OS="ubuntu"
      MAJOR_UBUNTU_VERSION=$(echo -e "$VERSION_ID" | cut -d '.' -f1)
      if [[ $MAJOR_UBUNTU_VERSION -lt 10 ]]; then
        showOSVersionError "Ubuntu" ">=10"
      fi
    fi

    if ! dpkg -s $PKGS >/dev/null 2>&1; then
      [[ $lang == "en" ]] && echo -e " Installing missing packages…" || echo -e " Устанавливаем недостающие пакеты…"
      sleep 1
      apt -y install $PKGS
    fi

  elif [[ -e /etc/system-release ]]; then
    source /etc/os-release

    if [[ $ID == "fedora" || $ID_LIKE == "fedora" ]]; then
      OS="fedora"
      # Fedora doesn't need strict version validation, but we'll use consistent approach
      local pkg_manager=$(getRpmPackageManager "$(echo "$VERSION_ID" | cut -d '.' -f1)")
      installRpmPackages "$pkg_manager"

    elif [[ $ID == "centos" || $ID == "rocky" || $ID == "redhat" ]]; then
      OS="centos"
      handleRpmBasedOS "$ID" "CentOS/RockyLinux/RedHat" "6|7|8|9" "$VERSION_ID"

    elif [[ $ID == "ol" ]]; then
      OS="oracle"
      handleRpmBasedOS "$ID" "Oracle Linux" "6|7|8|9" "$VERSION_ID"

    elif [[ $ID == "amzn" ]]; then
      OS="amzn"
      if [[ $VERSION_ID != "2" ]]; then
        showOSVersionError "Amazon Linux" "2"
      fi
      # Amazon Linux 2 uses yum specifically
      installRpmPackages "yum"
    fi

  elif [[ -e /etc/arch-release ]]; then
    OS=arch
    PKGS_ARCH=('curl' 'iputils' 'bind-tools')

    for pkg in "${PKGS_ARCH[@]}"; do
      [ -z $(pacman -Qqe "$pkg" 2>/dev/null) ] && pacman -Sy --noconfirm "$pkg"
    done

  else
    [[ $lang == "en" ]] && {
      echo -e " It looks like you are running this installer on a system other than Debian, Ubuntu, Fedora, CentOS, Amazon Linux, Oracle Linux or Arch Linux."
    } || {
      echo -e " Похоже, что вы запускаете этот установщик в системе отличной от Debian, Ubuntu, Fedora, CentOS, Amazon Linux, Oracle Linux или Arch Linux."
    }
    exit 1
  fi
}

function checkArch() {
  case $(uname -m) in
    i386) architecture="386" ;;
    i686) architecture="386" ;;
    x86_64) architecture="amd64" ;;
    aarch64) architecture="arm64" ;;
    armv7|armv7l) architecture="arm7" ;;
    armv6|armv6l) architecture="arm5" ;;
    *) [[ $lang == "en" ]] && { echo -e " Unsupported Arch. Can't continue."; exit 1; } || { echo -e " Не поддерживаемая архитектура. Продолжение невозможно."; exit 1; } ;;
  esac
}

function checkInternet() {
  if ! command -v ping >/dev/null 2>&1; then
    [[ $lang == "en" ]] && echo -e " Please install iputils-ping first" || echo -e " Сначала установите iputils-ping"
    exit 1
  fi
  [[ $lang == "en" ]] && echo -e " Check Internet access…" || echo -e " Проверяем соединение с Интернетом…"
  if ! ping -c 2 google.com &> /dev/null; then
    [[ $lang == "en" ]] && echo -e " - No Internet. Check your network and DNS settings." || echo -e " - Нет Интернета. Проверьте ваше соединение, а также разрешение имен DNS."
    exit 1
  fi
  [[ $lang == "en" ]] && echo -e " - Have Internet Access" || echo -e " - соединение с Интернетом успешно"
}

function initialCheck() {
  if ! isRoot; then
    [[ $lang == "en" ]] && echo -e " Script must run as root or user with sudo privileges. Example: sudo $scriptname" || echo -e " Вам нужно запустить скрипт от root или пользователя с правами sudo. Пример: sudo $scriptname"
    exit 1
  fi
  # [ -z "`which curl`" ] && echo -e " Сначала установите curl" && exit 1
  checkOS
  checkArch
  checkInternet
}

function getLatestRelease() {
  curl -s "${REPO_API_URL}/releases/latest" |
  grep -iE '"tag_name":|"version":' |
  sed -E 's/.*"([^"]+)".*/\1/'
}

function getSpecificRelease() {
  local version="$1"
  # Check if the version exists in releases
  local tag_name=$(getVersionTag "$version")
  local response=$(curl -s "${REPO_API_URL}/releases/tags/$tag_name")

  if echo "$response" | grep -q '"tag_name"'; then
    echo "$tag_name"
  else
    echo ""
  fi
}

function getTargetVersion() {
  if [[ -n "$specificVersion" ]]; then
    local target_release=$(getSpecificRelease "$specificVersion")
    if [[ -z "$target_release" ]]; then
      showVersionError "$specificVersion"
      exit 1
    fi
    echo "$target_release"
  else
    getLatestRelease
  fi
}

function installTorrServer() {
  [[ $lang == "en" ]] && echo -e " Install and configure TorrServer…" || echo -e " Устанавливаем и настраиваем TorrServer…"

  # Get target version and check glibc compatibility
  local target_version=$(getTargetVersion)
  [[ $lang == "en" ]] && echo -e " - Target version: $target_version" || echo -e " - Целевая версия: $target_version"

  if ! checkGlibcCompatibility "$target_version"; then
    exit 1
  fi

  if checkInstalled; then
    if ! checkInstalledVersion; then
      [[ $lang == "en" ]] && read -p " Want to update TorrServer? ($(colorize green Y)es/$(colorize yellow N)o) " answer_up </dev/tty || read -p " Хотите обновить TorrServer? ($(colorize green Y)es/$(colorize yellow N)o) " answer_up </dev/tty
      if [ "$answer_up" != "${answer_up#[YyДд]}" ]; then
        UpdateVersion
      fi
    fi
  fi

  binName=$(getBinaryName)
  [[ ! -d "$dirInstall" ]] && mkdir -p ${dirInstall}
  [[ ! -d "/usr/local/lib/systemd/system" ]] && mkdir -p "/usr/local/lib/systemd/system"

  # Build URL and download binary
  local urlBin
  if [[ -n "$specificVersion" ]]; then
    urlBin=$(buildDownloadUrl "$target_version" "$binName")
  else
    urlBin=$(buildDownloadUrl "latest" "$binName")
  fi

  if [[ ! -f "$dirInstall/$binName" ]] | [[ ! -x "$dirInstall/$binName" ]] || [[ $(stat -c%s "$dirInstall/$binName" 2>/dev/null) -eq 0 ]]; then
    downloadBinary "$urlBin" "$dirInstall/$binName" "$target_version"
  fi
  cat << EOF > $dirInstall/$serviceName.service
    [Unit]
    Description = TorrServer - stream torrent to http
    Wants = network-online.target
    After = network.target

    [Service]
    User = $username
    Group = $username
    Type = simple
    NonBlocking = true
    EnvironmentFile = $dirInstall/$serviceName.config
    ExecStart = ${dirInstall}/${binName} \$DAEMON_OPTIONS
    ExecReload = /bin/kill -HUP \${MAINPID}
    ExecStop = /bin/kill -INT \${MAINPID}
    TimeoutSec = 30
    #WorkingDirectory = ${dirInstall}
    Restart = on-failure
    RestartSec = 5s
    #LimitNOFILE = 4096

    [Install]
    WantedBy = multi-user.target
EOF
  [ -z $servicePort ] && {
    [[ $lang == "en" ]] && read -p " Change TorrServer web-port? ($(colorize yellow Y)es/$(colorize green N)o) " answer_cp </dev/tty || read -p " Хотите изменить порт для TorrServer? ($(colorize yellow Y)es/$(colorize green N)o) " answer_cp </dev/tty
    if [ "$answer_cp" != "${answer_cp#[YyДд]}" ]; then
      [[ $lang == "en" ]] && read -p " Enter port number: " answer_port </dev/tty || read -p " Введите номер порта: " answer_port </dev/tty
      servicePort=$answer_port
    else
      servicePort="$DEFAULT_PORT"
    fi
  }
  [ -z $isAuth ] && {
    [[ $lang == "en" ]] && read -p " Enable server authorization? ($(colorize green Y)es/$(colorize yellow N)o) " answer_auth </dev/tty || read -p " Включить авторизацию на сервере? ($(colorize green Y)es/$(colorize yellow N)o) " answer_auth </dev/tty
    if [ "$answer_auth" != "${answer_auth#[YyДд]}" ]; then
      isAuth=1
    else
      isAuth=0
    fi
  }
  if [ $isAuth -eq 1 ]; then
    [[ ! -f "$dirInstall/accs.db" ]] && {
      [[ $lang == "en" ]] && read -p " User: " answer_user </dev/tty || read -p " Пользователь: " answer_user </dev/tty
      isAuthUser=$answer_user
      [[ $lang == "en" ]] && read -p " Password: " answer_pass </dev/tty || read -p " Пароль: " answer_pass </dev/tty
      isAuthPass=$answer_pass
      [[ $lang == "en" ]] && echo -e " Store $isAuthUser:$isAuthPass to ${dirInstall}/accs.db" || echo -e " Сохраняем $isAuthUser:$isAuthPass в ${dirInstall}/accs.db"
      echo -e "{\n  \"$isAuthUser\": \"$isAuthPass\"\n}" > $dirInstall/accs.db
    } || {
    	auth=$(cat "$dirInstall/accs.db"|head -2|tail -1|tr -d '[:space:]'|tr -d '"')
      [[ $lang == "en" ]] && echo -e " - Use existing auth from ${dirInstall}/accs.db - $auth" || echo -e " - Используйте реквизиты из ${dirInstall}/accs.db для авторизации - $auth"
    }
    cat << EOF > $dirInstall/$serviceName.config
    DAEMON_OPTIONS="--port $servicePort --path $dirInstall --httpauth"
EOF
  else
    cat << EOF > $dirInstall/$serviceName.config
    DAEMON_OPTIONS="--port $servicePort --path $dirInstall"
EOF
  fi
  [ -z $isRdb ] && {
    [[ $lang == "en" ]] && read -p " Start TorrServer in public read-only mode? ($(colorize yellow Y)es/$(colorize green N)o) " answer_rdb </dev/tty || read -p " Запускать TorrServer в публичном режиме без возможности изменения настроек через веб сервера? ($(colorize yellow Y)es/$(colorize green N)o) " answer_rdb </dev/tty
    if [ "$answer_rdb" != "${answer_rdb#[YyДд]}" ]; then
      isRdb=1
    else
      isRdb=0
    fi
  }
  if [ $isRdb -eq 1 ]; then
    [[ $lang == "en" ]] && {
      echo -e " Set database to read-only mode…"
      echo -e " To change remove --rdb option from $dirInstall/$serviceName.config"
      echo -e " or rerun install script without parameters"
    } || {
      echo -e " База данных устанавливается в режим «только для чтения»…"
      echo -e " Для изменения отредактируйте $dirInstall/$serviceName.config, убрав опцию --rdb"
      echo -e " или запустите интерактивную установку без параметров повторно"
    }
    sed -i 's|DAEMON_OPTIONS="--port|DAEMON_OPTIONS="--rdb --port|' $dirInstall/$serviceName.config
  fi
  [ -z $isLog ] && {
    [[ $lang == "en" ]] && read -p " Enable TorrServer log output to file? ($(colorize yellow Y)es/$(colorize green N)o) " answer_log </dev/tty || read -p " Включить запись журнала работы TorrServer в файл? ($(colorize yellow Y)es/$(colorize green N)o) " answer_log </dev/tty
    if [ "$answer_log" != "${answer_log#[YyДд]}" ]; then
      sed -i "s|--path|--logpath $dirInstall/$serviceName.log --path|" "$dirInstall/$serviceName.config"
      [[ $lang == "en" ]] && echo -e " - TorrServer log stored at $dirInstall/$serviceName.log" || echo -e " - лог TorrServer располагается по пути $dirInstall/$serviceName.log"
    fi
  }

  ln -sf $dirInstall/$serviceName.service /usr/local/lib/systemd/system/
  sed -i 's/^[ \t]*//' $dirInstall/$serviceName.service
  sed -i 's/^[ \t]*//' $dirInstall/$serviceName.config

  [[ $lang == "en" ]] && echo -e " Starting TorrServer…" || echo -e " Запускаем службу TorrServer…"
  systemctl daemon-reload 2>/dev/null
  systemctl enable $serviceName.service 2>/dev/null # enable --now
  systemctl restart $serviceName.service 2>/dev/null
  getIP
  local installed_version=$(getTargetVersion)
  [[ $lang == "en" ]] && {
    echo -e ""
    echo -e " TorrServer $installed_version installed to ${dirInstall}"
    echo -e ""
    echo -e " You can now open your browser at http://${serverIP}:${servicePort} to access TorrServer web GUI."
    echo -e ""
  } || {
    echo -e ""
    echo -e " TorrServer $installed_version установлен в директории ${dirInstall}"
    echo -e ""
    echo -e " Теперь вы можете открыть браузер по адресу http://${serverIP}:${servicePort} для доступа к вебу TorrServer"
    echo -e ""
  }
  if [[ $isAuth -eq 1 && $isAuthUser > 0 ]]; then
    [[ $lang == "en" ]] && echo -e " Use user \"$isAuthUser\" with password \"$isAuthPass\" for authentication" || echo -e " Для авторизации используйте пользователя «$isAuthUser» с паролем «$isAuthPass»"
  echo -e ""
  fi
}

function checkInstalled() {
  if ! addUser; then
    username="root"
  fi
  local binName=$(getBinaryName)
  if [[ -f "$dirInstall/$binName" ]] || [[ $(stat -c%s "$dirInstall/$binName" 2>/dev/null) -ne 0 ]]; then
    [[ $lang == "en" ]] && echo -e " - TorrServer found in $dirInstall" || echo -e " - TorrServer найден в директории $dirInstall"
  else
    [[ $lang == "en" ]] && echo -e " - TorrServer not found. It's not installed or have zero size." || echo -e " - TorrServer не найден, возможно он не установлен или размер бинарника равен 0."
    return 1
  fi
}

function checkInstalledVersion() {
  local binName=$(getBinaryName)
  local target_version=$(getTargetVersion)
  local installed_version="$($dirInstall/$binName --version 2>/dev/null | awk '{print $2}')"

  if [[ -z "$target_version" ]]; then
    [[ $lang == "en" ]] && echo -e " - No version information available. Can be server issue." || echo -e " - Информация о версии недоступна. Возможно сервер не доступен."
    exit 1
  fi

  if [[ "$target_version" == "$installed_version" ]]; then
    if [[ -n "$specificVersion" ]]; then
      [[ $lang == "en" ]] && echo -e " - You already have TorrServer $target_version installed" || echo -e " - TorrServer $target_version уже установлен"
    else
      [[ $lang == "en" ]] && echo -e " - You have latest TorrServer $target_version" || echo -e " - Установлен TorrServer последней версии $target_version"
    fi
  else
    [[ $lang == "en" ]] && {
      if [[ -n "$specificVersion" ]]; then
        echo -e " - Will install TorrServer version $target_version"
      else
        echo -e " - TorrServer update found!"
      fi
      echo -e "   installed: \"$installed_version\""
      echo -e "   target: \"$target_version\""
    } || {
      if [[ -n "$specificVersion" ]]; then
        echo -e " - Будет установлена версия TorrServer $target_version"
      else
        echo -e " - Доступно обновление сервера"
      fi
      echo -e "   установлен: \"$installed_version\""
      echo -e "   целевая: \"$target_version\""
    }
    return 1
  fi
}

function UpdateVersion() {
  local target_version=$(getTargetVersion)

  if ! checkGlibcCompatibility "$target_version"; then
    [[ $lang == "en" ]] && echo -e " - Update cancelled due to glibc incompatibility" || echo -e " - Обновление отменено из-за несовместимости glibc"
    return 1
  fi

  systemctl stop $serviceName.service
  local binName=$(getBinaryName)

  local urlBin
  if [[ -n "$specificVersion" ]]; then
    urlBin=$(buildDownloadUrl "$target_version" "$binName")
  else
    urlBin=$(buildDownloadUrl "latest" "$binName")
  fi

  downloadBinary "$urlBin" "$dirInstall/$binName" "$target_version"
  systemctl start $serviceName.service
}

function DowngradeVersion() {
  local target_version=$(getVersionTag "$downgradeRelease")

  if ! checkGlibcCompatibility "$target_version"; then
    [[ $lang == "en" ]] && echo -e " - Downgrade cancelled due to glibc incompatibility" || echo -e " - Понижение версии отменено из-за несовместимости glibc"
    return 1
  fi

  systemctl stop $serviceName.service
  local binName=$(getBinaryName)
  local urlBin=$(buildDownloadUrl "$target_version" "$binName")
  downloadBinary "$urlBin" "$dirInstall/$binName" "$target_version"
  systemctl start $serviceName.service
}
#####################################
#     E N D   F U N C T I O N S     #
#####################################
getLang
case $1 in
  -i|--install|install)
    # Check if a version number is provided as second argument
    if [[ -n "$2" && "$2" =~ ^[0-9]+$ ]]; then
      specificVersion="$2"
      [[ $lang == "en" ]] && echo -e " - Installing specific version: $specificVersion" || echo -e " - Установка конкретной версии: $specificVersion"
    fi

    initialCheck
    if ! checkInstalled; then
      servicePort="$DEFAULT_PORT"
      isAuth=0
      isRdb=0
      isLog=0
      installTorrServer
    else
      systemctl stop $serviceName.service
      systemctl start $serviceName.service
    fi
    exit
    ;;
  -u|--update|update)
    initialCheck
    if checkInstalled; then
      if ! checkInstalledVersion; then
        UpdateVersion
      fi
    fi
    exit
    ;;
  -c|--check|check)
    initialCheck
    if checkInstalled; then
      checkInstalledVersion
    fi
    exit
    ;;
  -d|--down|down)
    initialCheck
    downgradeRelease="$2"
    [ -z "$downgradeRelease" ] &&
      echo -e " Вы не указали номер версии" &&
      echo -e " Наберите $scriptname -d|-down|down <версия>, например $scriptname -d 101" &&
      exit 1
    if checkInstalled; then
      DowngradeVersion
    fi
    exit
    ;;
  -r|--remove|remove)
    uninstall
    exit
    ;;
  -h|--help|help)
    helpUsage
    exit
    ;;
  *)
    echo -e ""
    echo -e " Choose Language:"
    echo -e " [$(colorize green 1)] English"
    echo -e " [$(colorize yellow 2)] Русский"
    read -p " Your language (Ваш язык): " answer_lang </dev/tty
    if [ "$answer_lang" != "${answer_lang#[2]}" ]; then
      lang="ru"
    fi
    echo -e ""
    echo -e "============================================================="
    [[ $lang == "en" ]] && echo -e " TorrServer install and configuration script for Linux " || echo -e " Скрипт установки, удаления и настройки TorrServer для Linux "
    echo -e "============================================================="
    echo -e ""
    [[ $lang == "en" ]] && echo -e " Enter $scriptname -h or --help or help for all available commands" || echo -e " Наберите $scriptname -h или --help или help для вызова справки всех доступных команд"
    ;;
esac

while true; do
  echo -e ""
  [[ $lang == "en" ]] && read -p " Want to install or configure TorrServer? ($(colorize green Y)es|$(colorize yellow N)o) Type $(colorize red D)elete to uninstall. " ydn </dev/tty || read -p " Хотите установить, обновить или настроить TorrServer? ($(colorize green Y)es|$(colorize yellow N)o) Для удаления введите «$(colorize red D)elete» " ydn </dev/tty
  case $ydn in
    [YyДд]*)
      initialCheck
      installTorrServer
      break
      ;;
    [DdУу]*)
      uninstall
      break
      ;;
    [NnНн]*)
      break
      ;;
    *) [[ $lang == "en" ]] && echo -e " Enter $(colorize green Y)es, $(colorize yellow N)o or $(colorize red D)elete" || echo -e " Ввведите $(colorize green Y)es, $(colorize yellow N)o или $(colorize red D)elete"
    	;;
  esac
done

echo -e " Have Fun!"
echo -e ""
sleep 3
