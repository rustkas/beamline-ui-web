# Mermaid Diagrams and PDF Generation

This directory contains generated PDF diagrams from Mermaid source files.

## Source Files

- `../MESSAGES_LIVE_EVENT_FLOWS.md` - Source markdown with Mermaid diagrams

## Generating PDFs

### Prerequisites

**Option 1: Install mermaid-cli globally**
```bash
npm install -g @mermaid-js/mermaid-cli
```

**Option 2: Use Docker**
```bash
docker pull minlag/mermaid-cli
```

**For PDF merging (optional):**
```bash
# Ubuntu/Debian
sudo apt-get install pdftk
# Or
sudo apt-get install ghostscript
```

### Generate PDF

```bash
cd apps/ui_web
bash scripts/generate_mermaid_pdf.sh
```

This will:
1. Extract all Mermaid diagrams from `docs/MESSAGES_LIVE_EVENT_FLOWS.md`
2. Convert each diagram to PDF
3. Merge all PDFs into `docs/diagrams/messages_live_event_flows.pdf`

### Custom Output Location

```bash
bash scripts/generate_mermaid_pdf.sh --output docs/diagrams/custom_output.pdf
```

## Generated Files

- `messages_live_event_flows.pdf` - Combined PDF with all event flow diagrams

## Diagram Types

The PDF includes:
- Filter Flow diagrams (status, type)
- Bulk Actions Flow diagrams (selection, delete, export)
- Pagination Flow diagrams (next, prev, state machine)
- Combined Flow diagrams (filter + pagination)
- Error Handling Flow diagrams
- State Transitions Summary

## CI Integration

PDF generation can be integrated into CI/CD:

```yaml
- name: Generate Mermaid PDFs
  run: |
    npm install -g @mermaid-js/mermaid-cli
    bash apps/ui_web/scripts/generate_mermaid_pdf.sh
```

## Troubleshooting

### mermaid-cli not found
```bash
npm install -g @mermaid-js/mermaid-cli
```

### PDF merging fails
Install `pdftk` or `ghostscript`:
```bash
sudo apt-get install pdftk
# Or
sudo apt-get install ghostscript
```

### Docker permission issues
Ensure Docker has access to the project directory:
```bash
docker run -it --rm -v "$(pwd):/data" minlag/mermaid-cli --version
```

