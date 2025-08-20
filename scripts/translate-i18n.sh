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
    echo -e "${RED}[!]${RESET} Proceso terminado por el usuario\n"
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

translate_batch() {
    local -n texts_ref=$1
    local -n keys_ref=$2
    local batch_size=${#texts_ref[@]}
    
    if [ $batch_size -eq 0 ]; then
        return 0
    fi

    # Protect interpolations and escape quotes for each text
    local protected_texts=()
    for text in "${texts_ref[@]}"; do
        local protected_text=$(echo "$text" | sed 's/{{[^}]*}}/<x>&<\/x>/g')
        local escaped_text=$(echo "$protected_text" | sed 's/"/\\"/g')
        protected_texts+=("$escaped_text")
    done

    # Build JSON array of protected texts
    local json_array="["
    for i in "${!protected_texts[@]}"; do
        if [ $i -gt 0 ]; then
            json_array+=","
        fi
        json_array+="\"${protected_texts[$i]}\""
    done
    json_array+="]"
    
    # Make API request
    local response=$(curl -s -X POST "https://api-free.deepl.com/v2/translate" \
        --header "Content-Type: application/json" \
        --header "Authorization: DeepL-Auth-Key ${API_KEY}" \
        --data "{
            \"text\": $json_array,
            \"source_lang\": \"${SOURCE_LANG}\",
            \"target_lang\": \"${TARGET_LANG}\",
            \"tag_handling\": \"xml\",
            \"ignore_tags\": [\"x\"]
        }")

    # Check if the response is valid
    if ! echo "$response" | jq -e '.translations' > /dev/null 2>&1; then
        echo -e "${RED}[!]${RESET} Error en la respuesta de la API para el lote actual."
        return 1
    fi

    # Extract translations and apply them
    local translations_count=$(echo "$response" | jq '.translations | length')
    
    for ((i=0; i<translations_count; i++)); do
        local translated=$(echo "$response" | jq -r ".translations[$i].text")
        local final_translation=$(echo "$translated" | sed 's/<x>\({{[^}]*}}\)<\/x>/\1/g')
        local key="${keys_ref[$i]}"
        
        local key_path=$(echo "$key" | jq -R 'split(".")')
        jq --argjson path "$key_path" --arg value "$final_translation" 'setpath($path; $value)' $TARGET_LANG.json > tmp.json && mv tmp.json $TARGET_LANG.json
    done
    
    return 0
}

# Copy input file as base
cat $INPUT_FILE > $TARGET_LANG.json

# Create temporary file for entries
temp_entries=$(mktemp)
jq -r 'paths(scalars) as $p | getpath($p) as $value | [$p | join("."), $value] | @tsv' $INPUT_FILE | grep -v $'\t$' > "$temp_entries"

BATCH_SIZE=50
total_lines=$(wc -l < "$temp_entries")
total_batches=$(( (total_lines + BATCH_SIZE - 1) / BATCH_SIZE ))
echo -e "${CYAN}[i]${RESET} Procesando ${YELLOW}$total_lines${RESET} entradas en ${YELLOW}$total_batches${RESET} lote(s) de maximo ${YELLOW}$BATCH_SIZE${RESET} entradas c/u..."

batch_count=0
current_batch=0

# Process file entries in batches
while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ -z "$line" ]]; then
        continue
    fi
    
    ((batch_count++))

    # Make batch file
    if [ $batch_count -eq 1 ]; then
        batch_file=$(mktemp)
        echo "$line" > "$batch_file"
    else
        echo "$line" >> "$batch_file"
    fi
    
    # Process batch when it is full or is the last line
    if [ $batch_count -eq $BATCH_SIZE ] || [ $(($current_batch * $BATCH_SIZE + $batch_count)) -eq $total_lines ]; then
        ((current_batch++))
        
        # Prepare arrays for the batch
        batch_texts=()
        batch_keys=()
        
        while IFS=$'\t' read -r key value; do
            batch_texts+=("$value")
            batch_keys+=("$key")
        done < "$batch_file"
        
        if translate_batch batch_texts batch_keys; then
            echo -e "${GREEN}[✓]${RESET} Lote ${YELLOW}$current_batch${RESET}/${YELLOW}$total_batches${RESET} traducido exitosamente."
        else
            echo -e "${RED}[!]${RESET} Error al traducir el lote ${YELLOW}$current_batch${RESET}/${YELLOW}$total_batches${RESET}. Continuando..."
        fi

        # Clean up and reset
        rm -f "$batch_file"
        batch_count=0
        
        # Sleep to avoid hitting API limits
        sleep 1
    fi
done < "$temp_entries"

# Clean up temporary files
rm -f "$temp_entries"

# End of script

echo ""
echo -e "${GREEN}[+]${RESET} Traducción completada exitosamente."
echo -e "${GREEN}[+]${RESET} Archivo generado: ${MAGENTA}$TARGET_LANG.json${RESET}"
echo -e "${GREEN}[+]${RESET} Traducido de ${YELLOW}$SOURCE_LANG${RESET} a ${YELLOW}$TARGET_LANG${RESET}\n"
