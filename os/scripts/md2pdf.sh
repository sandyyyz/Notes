#!/usr/bin/env bash
# Convert Markdown files to PDF with Pandoc and XeLaTeX.

set -Eeuo pipefail

readonly PROGRAM_NAME="$(basename "$0")"

usage() {
    cat <<EOF
Usage:
  $PROGRAM_NAME INPUT.md [OUTPUT.pdf]
  $PROGRAM_NAME [OPTIONS] INPUT.md [OUTPUT.pdf]

Options:
  --no-toc             Do not generate a table of contents
  --no-number-sections Do not number headings
  --main-font FONT     CJK/main font (default: Noto Sans CJK SC)
  --mono-font FONT     Monospace font (default: DejaVu Sans Mono)
  --margin SIZE        Page margin (default: 2.5cm)
  --font-size SIZE     Base font size (default: 11pt)
  -h, --help           Show this help message

Examples:
  $PROGRAM_NAME vimrc.md
  $PROGRAM_NAME vimrc.md vimrc-guide.pdf
  $PROGRAM_NAME --margin 2cm --font-size 12pt notes.md
  $PROGRAM_NAME --no-toc README.md README.pdf
EOF
}

error() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || \
        error "required command '$1' was not found"
}

TOC=true
NUMBER_SECTIONS=true
MAIN_FONT="${PANDOC_MAIN_FONT:-Noto Sans CJK SC}"
MONO_FONT="${PANDOC_MONO_FONT:-DejaVu Sans Mono}"
MARGIN="${PANDOC_MARGIN:-2.5cm}"
FONT_SIZE="${PANDOC_FONT_SIZE:-11pt}"
POSITIONAL=()

while (($# > 0)); do
    case "$1" in
        --no-toc)
            TOC=false
            shift
            ;;
        --no-number-sections)
            NUMBER_SECTIONS=false
            shift
            ;;
        --main-font)
            (($# >= 2)) || error "--main-font requires a font name"
            MAIN_FONT="$2"
            shift 2
            ;;
        --mono-font)
            (($# >= 2)) || error "--mono-font requires a font name"
            MONO_FONT="$2"
            shift 2
            ;;
        --margin)
            (($# >= 2)) || error "--margin requires a value"
            MARGIN="$2"
            shift 2
            ;;
        --font-size)
            (($# >= 2)) || error "--font-size requires a value"
            FONT_SIZE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            POSITIONAL+=("$@")
            break
            ;;
        -* )
            error "unknown option: $1"
            ;;
        *)
            POSITIONAL+=("$1")
            shift
            ;;
    esac
done

((${#POSITIONAL[@]} >= 1 && ${#POSITIONAL[@]} <= 2)) || {
    usage >&2
    exit 2
}

INPUT="${POSITIONAL[0]}"
OUTPUT="${POSITIONAL[1]:-${INPUT%.*}.pdf}"

[[ -f "$INPUT" ]] || error "input file does not exist: $INPUT"
[[ "$OUTPUT" == *.pdf ]] || error "output file must use the .pdf extension: $OUTPUT"

require_command pandoc
require_command xelatex

# Resolve relative images and other resources from the Markdown file's directory.
INPUT_DIR="$(cd "$(dirname "$INPUT")" && pwd)"

PANDOC_ARGS=(
    "$INPUT"
    -o "$OUTPUT"
    --from=gfm
    --pdf-engine=xelatex
    --resource-path="$INPUT_DIR"
    -V "CJKmainfont=$MAIN_FONT"
    -V "monofont=$MONO_FONT"
    -V "geometry:margin=$MARGIN"
    -V "fontsize=$FONT_SIZE"
    -V colorlinks=true
    -V linkcolor=blue
    -V urlcolor=blue
)

$TOC && PANDOC_ARGS+=(--toc)
$NUMBER_SECTIONS && PANDOC_ARGS+=(--number-sections)

printf 'Converting: %s -> %s\n' "$INPUT" "$OUTPUT"
pandoc "${PANDOC_ARGS[@]}"
printf 'Created: %s\n' "$OUTPUT"

