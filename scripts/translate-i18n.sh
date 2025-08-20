#!/bin/bash

# Color codes
YELLOW="\e[33m"
GREEN="\e[32m"
RED="\e[31m"
BLUE="\e[34m"
MAGENTA="\e[35m"
CYAN="\e[36m"
RESET="\e[0m"

# Control-C handler
function ctrl_c() {
    echo -e "\n${RED}[!]${RESET} Cancelando traducción..."
    echo -e "${CYAN}[i]${RESET} Proceso terminado por el usuario\n"
    exit 1
}
trap ctrl_c INT

if [ "$1" == "--help" ]; then
    echo -e "\n${YELLOW}Uso:${RESET} $0 <archivo_entrada> <idioma_origen> <idioma_destino>"
    echo -e "${YELLOW}Ejemplo:${RESET} $0 i18n.json es en"
    echo -e "${YELLOW}Descripción:${RESET} Este script traduce un archivo JSON de i18n usando la API de DeepL.\n"
    exit 0
fi

API_KEY="$DEEPL_API_KEY"
INPUT_FILE="$1"
SOURCE_LANG="$2"
TARGET_LANG="$3"

# Parameter validation

if [ -z "$DEEPL_API_KEY" ]; then
    echo -e "\n${RED}[!]${RESET} Debes definir la variable de entorno DEEPL_API_KEY con tu clave de API de DeepL."
    echo -e "${RED}[!]${RESET} Ejecuta ${MAGENTA}export DEEPL_API_KEY=tu_clave_de_api${RESET} para definirla."
    exit 1
fi

if [ "$INPUT_FILE" == "" ]; then
    echo -e "\n${RED}[!]${RESET} Debes especificar un archivo de entrada."
    echo -e "${RED}[!]${RESET} Ejecuta $0 --help para más información.\n"
    exit 1
fi

if [ "$SOURCE_LANG" == "" ]; then
    echo -e "\n${RED}[!]${RESET} Debes especificar un idioma de origen."
    echo -e "${RED}[!]${RESET} Ejecuta $0 --help para más información.\n"
    exit 1
fi

if [ "$TARGET_LANG" == "" ]; then
    echo -e "\n${RED}[!]${RESET} Debes especificar un idioma de destino."
    echo -e "${RED}[!]${RESET} Ejecuta $0 --help para más información.\n"
    exit 1
fi

if [[ ! -f "$INPUT_FILE" ]]; then
    echo -e "\n${RED}[x]${RESET} El archivo de entrada no existe."
    echo -e "${RED}[!]${RESET} Ejecuta $0 --help para más información.\n"
    exit 1
fi

translate() {
    local text="$1"
    
    local protected_text=$(echo "$text" | sed 's/{{[^}]*}}/<x>&<\/x>/g')
    local escaped_text=$(echo "$protected_text" | sed 's/"/\\"/g')
    
    local translated=$(curl -s -X POST "https://api-free.deepl.com/v2/translate" \
        --header "Content-Type: application/json" \
        --header "Authorization: DeepL-Auth-Key ${API_KEY}" \
        --data "{
            \"text\": [\"$escaped_text\"],
            \"source_lang\": \"${SOURCE_LANG}\",
            \"target_lang\": \"${TARGET_LANG}\",
            \"tag_handling\": \"xml\",
            \"ignore_tags\": [\"x\"]
        }" | jq -r '.translations[0].text')
    
    echo "$translated" | sed 's/<x>\({{[^}]*}}\)<\/x>/\1/g'
}

cat $INPUT_FILE > $TARGET_LANG.json

jq -r 'paths(scalars) as $p | getpath($p) as $value | [$p | join("."), $value] | @tsv' $INPUT_FILE | while IFS=$'\t' read -r key value; do
    if [[ "$value" == "" ]]; then
        continue
    fi

    echo -e "${BLUE}[+]${RESET} Traduciendo clave ${MAGENTA}$key${RESET}..."

    translated_value=$(translate "$value")
    
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}[!]${RESET} Error al traducir la clave ${MAGENTA}$key${RESET}. Verifica tu conexión a Internet o la clave de API."
        continue
    fi

    key_path=$(echo "$key" | jq -R 'split(".")')
    jq --argjson path "$key_path" --arg value "$translated_value" 'setpath($path; $value)' $TARGET_LANG.json > tmp.json && mv tmp.json $TARGET_LANG.json
done

# End of script

echo ""
echo -e "${GREEN}[+]${RESET} Traducción completada exitosamente."
echo -e "${GREEN}[+]${RESET} Archivo generado: ${MAGENTA}$TARGET_LANG.json${RESET}"
echo -e "${GREEN}[+]${RESET} Traducido de ${YELLOW}$SOURCE_LANG${RESET} a ${YELLOW}$TARGET_LANG${RESET}\n"
