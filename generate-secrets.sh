#!/bin/bash

# Configuration
EXAMPLE_FILE=".env.example"
OUTPUT_FILE=".env"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Dokploy Templates Secrets Generator ===${NC}"

if [ ! -f "$EXAMPLE_FILE" ]; then
    echo "Error: $EXAMPLE_FILE not found!"
    exit 1
fi

if [ -f "$OUTPUT_FILE" ]; then
    echo -e "${YELLOW}Warning: $OUTPUT_FILE already exists. Overwrite? (y/n)${NC}"
    read -r choice
    if [ "$choice" != "y" ]; then
        echo "Aborted."
        exit 0
    fi
fi

# Function to generate a random secret
generate_secret() {
    openssl rand -base64 32 | tr -d /=+ | cut -c1-32
}

echo -e "Generating ${GREEN}$OUTPUT_FILE${NC} from ${GREEN}$EXAMPLE_FILE${NC}..."

# Create/Clear the output file
cp "$EXAMPLE_FILE" "$OUTPUT_FILE"

# List of keys to automatically randomize
SECRET_KEYS=("POSTGRES_PASSWORD" "ANON_KEY" "SERVICE_ROLE_KEY" "JWT_SECRET" "GLEAN_SECRET_KEY" "SURF_SECRET_KEY" "SECRET_KEY_BASE" "ADMIN_PASSWORD" "MAUTIC_DB_PASSWORD")

for key in "${SECRET_KEYS[@]}"; do
    SECRET=$(generate_secret)
    echo -e "Generating secret for ${BLUE}$key${NC}..."
    # Use sed to replace the value after '='
    # This matches the key and replaces everything after the '=' with the secret
    sed -i "s|^$key=.*|$key=$SECRET|" "$OUTPUT_FILE"
done

echo -e "\n${GREEN}Done!${NC}"
echo -e "Secrets have been generated in ${BLUE}$OUTPUT_FILE${NC}."
echo -e "${YELLOW}Note: Please review $OUTPUT_FILE to fill in your personal configuration (URLs, API keys, etc.)${NC}"
