#!/bin/bash

YELLOW="\e[33m"
GREEN="\e[32m"
RED="\e[31m"
BLUE="\e[34m"
MAGENTA="\e[35m"
CYAN="\e[36m"
RESET="\e[0m"

echo ""

if [ -z "$1" ]; then
    echo -e "${YELLOW}[!]${RESET} ${RED}Error:${RESET} Debes proporcionar el nombre del proyecto.\n"
    exit 1
fi

PROJECT_NAME=$1
PROJECT_PATH=${2:-.}

mkdir -p "$PROJECT_PATH"
FULL_PATH=$(realpath "$PROJECT_PATH/$PROJECT_NAME")

if [ -d "$FULL_PATH" ]; then
    echo -e "${YELLOW}[!]${RESET} ${RED}Error:${RESET} El directorio ya existe.\n"
    exit 1
fi
echo -e "${YELLOW}[*]${RESET} Creando proyecto Rust: ${BLUE}$PROJECT_NAME${RESET} en ${BLUE}$FULL_PATH${RESET}"
mkdir -p "$FULL_PATH"

echo ""
docker run --rm -it -w "/$PROJECT_NAME" -v "$FULL_PATH:/$PROJECT_NAME/" --user $(id -u):$(id -g) rust bash -c "cargo init && cargo build"
if [ $? -ne 0 ]; then
    echo -e "${YELLOW}[!]${RESET} ${RED}Error:${RESET} No se pudo crear el proyecto.\n"
    rm -rf "$FULL_PATH"
    exit 1
fi
echo ""

INTERACTIVE_SCRIPT="$FULL_PATH/dev.sh"
cat > "$INTERACTIVE_SCRIPT" <<EOF
#!/bin/bash

docker run --rm -it -w /$PROJECT_NAME -v "\$(pwd):/$PROJECT_NAME/" --name rust-dev rust bash
EOF

chmod +x "$INTERACTIVE_SCRIPT"

echo -e "${YELLOW}[*]${RESET} Proyecto creado en ${BLUE}$FULL_PATH${RESET}"
echo -e "${YELLOW}[*]${RESET} Para iniciar el entorno interactivo ejecuta: ${BLUE}$INTERACTIVE_SCRIPT${RESET}"

echo ""