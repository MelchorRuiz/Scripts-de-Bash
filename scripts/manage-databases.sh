#!/bin/bash

YELLOW="\e[33m"
GREEN="\e[32m"
RED="\e[31m"
BLUE="\e[34m"
MAGENTA="\e[35m"
CYAN="\e[36m"
RESET="\e[0m"

declare -A START_COMMANDS=(
    ["mysql"]="docker run --name mysql -d -e MYSQL_ROOT_PASSWORD=root -p 3306:3306 -v mysql_data:/var/lib/mysql mysql"
    ["mongo"]="docker run --name mongo -d -p 27017:27017 -v mongodb_data:/data/db mongo"
)

declare -A SHELL_COMMANDS=(
    ["mysql"]="docker exec -it mysql mysql -u root -proot"
    ["mongo"]="docker exec -it mongo mongosh"
)

function ctrl_c() {
    echo -e "\n\n${YELLOW}[*]${RESET} Saliendo..."
    exit 1
}

trap ctrl_c INT

if [ "$1" == "" ]; then
    echo -e "\n${RED}[!]${RESET} Debes especificar una opción."
    echo -e "${RED}[!]${RESET} Ejecuta $0 --help para más información.\n"
    exit 1
fi


function help() {
    echo -e "${YELLOW}[*]${RESET} ${MAGENTA}Gestión de bases de datos${RESET} - Herramienta para gestionar bases de datos."
    echo -e "${YELLOW}[*]${RESET} Uso: $0 [${MAGENTA}opciones${RESET}]"
    echo -e "\n${YELLOW}[*]${RESET} ${MAGENTA}Opciones:${RESET}"
    echo -e " --start => Iniciar servicio de base de datos."
    echo -e " --stop => Detener servicio de base de datos."
    echo -e " --restart => Reiniciar servicio de base de datos."
    echo -e " --status => Verificar estado del servicio de base de datos."
    echo -e " --shell => Acceder a la consola de la base de datos."
    echo -e " --help => Mostrar este mensaje de ayuda."
    echo -e "\n${YELLOW}[*]${RESET} ${MAGENTA}Ejemplos:${RESET}"
    echo -e " $0 --start mysql"
    echo -e " $0 --start mongo --shell mongo\n"
}

function start_db() {
    local DB_NAME="$1"

    if [ "$DB_NAME" == "" ]; then
        echo -e "${RED}[!]${RESET} Debes especificar una base de datos."
        echo -e "${RED}[!]${RESET} Ejecuta $0 --help para más información.\n"
        exit 1
    fi

    echo -e "${YELLOW}[*]${RESET} Iniciando base de datos: ${BLUE}$DB_NAME${RESET}"
    if [ "$(docker ps -aq -f name=$DB_NAME)" ]; then
        docker start $DB_NAME > /dev/null
    else
        start_command="${START_COMMANDS[$DB_NAME]}"
        if [ "$start_command" == "" ]; then
            echo -e "${RED}[!]${RESET} Base de datos no soportada: $DB_NAME\n"
            exit 1
        else
            eval $start_command > /dev/null
        fi
    fi
}

function stop_db() {
    local DB_NAME="$1"

    if [ "$DB_NAME" == "" ]; then
        echo -e "${RED}[!]${RESET} Debes especificar una base de datos."
        echo -e "${RED}[!]${RESET} Ejecuta $0 --help para más información.\n"
        exit 1
    fi

    echo -e "${YELLOW}[*]${RESET} Deteniendo base de datos: ${BLUE}$DB_NAME${RESET}"
    if [ "$(docker ps -q -f name=$DB_NAME)" ]; then
        docker stop $DB_NAME > /dev/null
    else
        echo -e "${RED}[!]${RESET} Base de datos no encontrada: $DB_NAME\n"
        exit 1
    fi
}

function restart_db() {
    local DB_NAME="$1"

    if [ "$DB_NAME" == "" ]; then
        echo -e "${RED}[!]${RESET} Debes especificar una base de datos."
        echo -e "${RED}[!]${RESET} Ejecuta $0 --help para más información.\n"
        exit 1
    fi

    echo -e "${YELLOW}[*]${RESET} Reiniciando base de datos: ${BLUE}$DB_NAME${RESET}"
    if [ "$(docker ps -q -f name=$DB_NAME)" ]; then
        docker restart $DB_NAME > /dev/null
    else
        echo -e "${RED}[!]${RESET} Base de datos no encontrada: $DB_NAME\n"
        exit 1
    fi
}

function status_db() {
    local DB_NAME="$1"

    if [ "$DB_NAME" == "" ]; then
        echo -e "${RED}[!]${RESET} Debes especificar una base de datos."
        echo -e "${RED}[!]${RESET} Ejecuta $0 --help para más información.\n"
        exit 1
    fi

    echo -e "\n${YELLOW}[*]${RESET} Verificando estado de la base de datos: ${BLUE}$DB_NAME${RESET}"
    if [ "$(docker ps -q -f name=$DB_NAME)" ]; then
        echo -e "${YELLOW}[*]${RESET} ${GREEN}Base de datos en linea.${RESET}"
    else
        echo -e "${YELLOW}[!]${RESET} ${RED}Base de datos fuera de linea.${RESET}"
    fi
}

function shell_db() {
    local DB_NAME="$1"

    if [ "$DB_NAME" == "" ]; then
        echo -e "${RED}[!]${RESET} Debes especificar una base de datos."
        echo -e "${RED}[!]${RESET} Ejecuta $0 --help para más información.\n"
        exit 1
    fi

    echo -e "\n${YELLOW}[*]${RESET} Accediendo a la consola de la base de datos: ${BLUE}$DB_NAME${RESET}"
    if [ "$(docker ps -q -f name=$DB_NAME)" ]; then
        shell_command="${SHELL_COMMANDS[$DB_NAME]}"
        if [ "$shell_command" == "" ]; then
            echo -e "${RED}[!]${RESET} Base de datos no soportada: $DB_NAME\n"
            exit 1
        else
            eval $shell_command
        fi
    else
        echo -e "${RED}[!]${RESET} Base de datos no encontrada: $DB_NAME\n"
        exit 1
    fi
}

echo ""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --start) 
            start_db $2
            shift 2
            ;;
        --stop)
            stop_db $2
            shift 2
            ;;
        --restart)
            restart_db $2
            shift 2
            ;;
        --status)
            status_db $2
            shift 2
            ;;
        --shell)
            shell_db $2
            shift 2
            ;;
        --help)
            help
            exit 0
            ;;
        *)
            echo -e "\n${RED}[!]${RESET} Opción no válida: $1"
            echo -e "${RED}[!]${RESET} Ejecuta $0 --help para más información.\n"
            exit 1
            ;;
    esac
done

echo ""