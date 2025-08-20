#!/bin/bash

YELLOW="\e[33m"
GREEN="\e[32m"
RED="\e[31m"
BLUE="\e[34m"
MAGENTA="\e[35m"
CYAN="\e[36m"
RESET="\e[0m"

function ctrl_c() {
    echo -e "\n\n${YELLOW}[*]${RESET} Saliendo..."
    exit 1
}

trap ctrl_c INT

if [ -z "$COINGECKO_API_KEY" ]; then
    echo -e "\n${RED}[!]${RESET} Debes definir la variable de entorno COINGECKO_API_KEY con tu clave de API de CoinGecko."
    echo -e "${RED}[!]${RESET} Ejecuta ${MAGENTA}export COINGECKO_API_KEY=tu_clave_de_api${RESET} para definirla."
    exit 1
fi

API_URL="https://api.coingecko.com/api/v3"
API_KEY="$COINGECKO_API_KEY"

currency="mxn"

function help() {
    echo -e "\n${YELLOW}[*]${RESET} ${MAGENTA}Cripto Busqueda${RESET} - Herramienta para consultar precios de criptomonedas."
    echo -e "${YELLOW}[*]${RESET} Uso: $0 [${MAGENTA}opciones${RESET}]"
    echo -e "\n${YELLOW}[*]${RESET} ${MAGENTA}Opciones:${RESET}"
    echo -e " -s => Verificar estado del servidor."
    echo -e " -p => Consultar precio de una criptomoneda."
    echo -e " -l => Listar criptomonedas."
    echo -e " -c => Definir moneda de consulta."
    echo -e " -h => Mostrar este mensaje de ayuda."
    echo -e "\n${YELLOW}[*]${RESET} ${MAGENTA}Ejemplos:${RESET}"
    echo -e " $0 -l bitcoin"
    echo -e " $0 -p bitcoin"
    echo -e " $0 -c usd -p bitcoin"
}

function server_status() {
    echo -e "\n${YELLOW}[*]${RESET} Verificando estado del servidor..."
    error="$(curl -s $API_URL/ping --header "x-cg-demo-api-key:$API_KEY" | jq '.error')"
    if [ "$error" == "null" ]; then
        echo -e "${YELLOW}[*]${RESET} ${GREEN}Servidor en linea.${RESET}"
    else
        echo -e "${YELLOW}[!]${RESET} ${RED}Servidor fuera de linea.${RESET}"
    fi
}

function show_coins() {
    local COIN="$1"
    echo -e "\n${YELLOW}[*]${RESET} Buscando criptomoneda: ${BLUE}$COIN${RESET}\n"
    curl -s "$API_URL/coins/list" --header 'x-cg-demo-api-key:$API_KEY' | jq '.[].name' | grep -i "$1" | head -n 20 | tr -d '"' | column
}

function coin_price() {
    local COIN="$1"
    echo -e "\n${YELLOW}[*]${RESET} Buscando precio de la criptomoneda: ${BLUE}$COIN${RESET}"
    price="$(curl -s "$API_URL/simple/price?ids=$COIN&vs_currencies=$currency" --header 'x-cg-demo-api-key:$API_KEY' | jq ".$COIN.$currency")"
    if [ "$price" == "null" ]; then
        echo -e "${YELLOW}[!]${RESET} Criptomoneda no encontrada."
    else
        echo -e "${YELLOW}[*]${RESET} Precio de ${BLUE}$COIN${RESET}: ${CYAN}$price${RESET} $currency"
    fi
}

while getopts "sp:l:c:h" opt; do
    case $opt in
        s) server_status;;
        p) coin_price $OPTARG;;
        l) show_coins $OPTARG;;
        c) currency=$OPTARG;;
        h) help;;
        *) echo -e "\n${YELLOW}[!]${RESET} Opcion no valida. Ejecuta $0 -h para ayuda.";;
    esac
done

echo ""