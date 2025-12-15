#!/bin/bash
# Generate PDF from Mermaid diagrams in MESSAGES_LIVE_EVENT_FLOWS.md
#
# Prerequisites:
#   - npm install -g @mermaid-js/mermaid-cli
#   - Or: docker run -it --rm -v "$PWD:/data" minlag/mermaid-cli
#
# Usage:
#   bash scripts/generate_mermaid_pdf.sh
#   bash scripts/generate_mermaid_pdf.sh --output docs/diagrams/messages_flows.pdf

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DOCS_DIR="$PROJECT_ROOT/apps/ui_web/docs"
OUTPUT_DIR="${OUTPUT_DIR:-$DOCS_DIR/diagrams}"
OUTPUT_FILE="${1:-$OUTPUT_DIR/messages_live_event_flows.pdf}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Generating PDF from Mermaid diagrams...${NC}"

# Lint diagrams first
echo -e "${YELLOW}Validating Mermaid syntax...${NC}"
if ! bash "$SCRIPT_DIR/../lint_mermaid.sh" "$SOURCE_FILE" 2>/dev/null; then
  echo -e "${RED}Error: Mermaid syntax validation failed. Fix errors before generating PDF.${NC}"
  exit 1
fi

# Check if mermaid-cli is available
if command -v mmdc &> /dev/null; then
  MMDC_CMD="mmdc"
elif command -v docker &> /dev/null; then
  echo -e "${YELLOW}Using Docker for mermaid-cli${NC}"
  MMDC_CMD="docker run -it --rm -v \"$PROJECT_ROOT:/data\" minlag/mermaid-cli"
else
  echo -e "${RED}Error: mermaid-cli not found. Install with: npm install -g @mermaid-js/mermaid-cli${NC}"
  echo -e "${YELLOW}Or use Docker: docker pull minlag/mermaid-cli${NC}"
  exit 1
fi

# Create output directory
mkdir -p "$(dirname "$OUTPUT_FILE")"
mkdir -p "$OUTPUT_DIR/temp"

# Extract Mermaid diagrams from markdown file
SOURCE_FILE="$DOCS_DIR/MESSAGES_LIVE_EVENT_FLOWS.md"

if [ ! -f "$SOURCE_FILE" ]; then
  echo -e "${RED}Error: Source file not found: $SOURCE_FILE${NC}"
  exit 1
fi

echo -e "${GREEN}Extracting Mermaid diagrams from $SOURCE_FILE...${NC}"

# Extract each mermaid code block and convert to PDF
DIAGRAM_COUNT=0
DIAGRAM_INDEX=0

# Function to extract and convert a mermaid diagram
extract_and_convert() {
  local diagram_name="$1"
  local mermaid_content="$2"
  local output_pdf="$OUTPUT_DIR/temp/${diagram_name}.pdf"
  
  # Write mermaid content to temp file
  local temp_mmd="$OUTPUT_DIR/temp/${diagram_name}.mmd"
  echo "$mermaid_content" > "$temp_mmd"
  
  # Convert to PDF
  if [[ "$MMDC_CMD" == "mmdc" ]]; then
    mmdc -i "$temp_mmd" -o "$output_pdf" -b transparent -w 1920 -H 1080 2>&1 | grep -v "Warning" || true
  else
    docker run -it --rm -v "$PROJECT_ROOT:/data" minlag/mermaid-cli \
      -i "/data/apps/ui_web/docs/diagrams/temp/${diagram_name}.mmd" \
      -o "/data/apps/ui_web/docs/diagrams/temp/${diagram_name}.pdf" \
      -b transparent -w 1920 -H 1080 2>&1 | grep -v "Warning" || true
  fi
  
  if [ -f "$output_pdf" ]; then
    echo -e "${GREEN}  ✓ Generated: $output_pdf${NC}"
    DIAGRAM_COUNT=$((DIAGRAM_COUNT + 1))
  else
    echo -e "${RED}  ✗ Failed to generate: $output_pdf${NC}"
  fi
}

# Parse markdown file and extract mermaid blocks
IN_MERMAID=false
MERMAID_CONTENT=""
CURRENT_DIAGRAM=""

while IFS= read -r line || [ -n "$line" ]; do
  # Check for mermaid code block start
  if [[ "$line" =~ ^\`\`\`mermaid ]]; then
    IN_MERMAID=true
    MERMAID_CONTENT=""
    DIAGRAM_INDEX=$((DIAGRAM_INDEX + 1))
    CURRENT_DIAGRAM="diagram_${DIAGRAM_INDEX}"
    continue
  fi
  
  # Check for code block end
  if [[ "$line" =~ ^\`\`\`$ ]] && [ "$IN_MERMAID" = true ]; then
    IN_MERMAID=false
    if [ -n "$MERMAID_CONTENT" ]; then
      # Try to extract diagram name from previous heading
      DIAGRAM_NAME=$(echo "$CURRENT_DIAGRAM" | tr ' ' '_' | tr -cd '[:alnum:]_')
      extract_and_convert "$DIAGRAM_NAME" "$MERMAID_CONTENT"
    fi
    MERMAID_CONTENT=""
    continue
  fi
  
  # Collect mermaid content
  if [ "$IN_MERMAID" = true ]; then
    MERMAID_CONTENT="${MERMAID_CONTENT}${line}"$'\n'
  fi
  
  # Try to extract diagram name from headings (## or ###)
  if [[ "$line" =~ ^##+\ +(.+)$ ]] && [ "$IN_MERMAID" = false ]; then
    CURRENT_DIAGRAM=$(echo "${BASH_REMATCH[1]}" | tr ' ' '_' | tr -cd '[:alnum:]_')
  fi
done < "$SOURCE_FILE"

# Merge all PDFs into one
if [ $DIAGRAM_COUNT -gt 0 ]; then
  echo -e "${GREEN}Merging $DIAGRAM_COUNT diagrams into single PDF...${NC}"
  
  # Check if pdftk or gs (ghostscript) is available
  if command -v pdftk &> /dev/null; then
    pdftk "$OUTPUT_DIR"/temp/*.pdf cat output "$OUTPUT_FILE"
    echo -e "${GREEN}✓ Merged PDF created: $OUTPUT_FILE${NC}"
  elif command -v gs &> /dev/null; then
    gs -dBATCH -dNOPAUSE -q -sDEVICE=pdfwrite -sOutputFile="$OUTPUT_FILE" "$OUTPUT_DIR"/temp/*.pdf
    echo -e "${GREEN}✓ Merged PDF created: $OUTPUT_FILE${NC}"
  else
    echo -e "${YELLOW}Warning: pdftk or ghostscript not found. Individual PDFs are in: $OUTPUT_DIR/temp/${NC}"
    echo -e "${YELLOW}Install pdftk: sudo apt-get install pdftk${NC}"
    echo -e "${YELLOW}Or install ghostscript: sudo apt-get install ghostscript${NC}"
    echo -e "${YELLOW}Individual PDFs:${NC}"
    ls -lh "$OUTPUT_DIR"/temp/*.pdf
  fi
else
  echo -e "${RED}Error: No diagrams found or converted${NC}"
  exit 1
fi

# Cleanup temp files
rm -rf "$OUTPUT_DIR/temp"

echo -e "${GREEN}Done! PDF generated: $OUTPUT_FILE${NC}"
echo -e "${GREEN}Total diagrams processed: $DIAGRAM_COUNT${NC}"

