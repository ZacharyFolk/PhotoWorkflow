#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  photoframe.sh  —  Export framed images for Instagram, web, and print
#
#  Requires: ImageMagick (convert, identify)
#
#  Usage:
#    photoframe.sh -p <profile> [options] <input> [input2 ...]
#    photoframe.sh -p instagram-square ./exports/*.jpg
#    photoframe.sh -p web -o ./site/photos ./exports/shoot1.tif
#    photoframe.sh -p instagram-portrait -t "yourname.com" ./exports/*.jpg
#    photoframe.sh -p web -n ./exports/some_image.jpg       # no label
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

VERSION="1.3"
SCRIPT="$(basename "$0")"

# ── Defaults ──────────────────────────────────────────────────────────────────
PROFILE="web"
OUTPUT_DIR="./framed"
TEXT_MODE="filename"    # filename | custom | none
CUSTOM_TEXT=""
OVERWRITE=false
DRY_RUN=false
VERBOSE=false

# ── Profile definitions ───────────────────────────────────────────────────────
# After calling load_profile, these globals are set:
#   CANVAS         "WxH" for fixed output, "auto" for proportional
#   CANVAS_MODE    "fit" (long-edge fit) | "width" (width-constrained for landscape-in-portrait)
#   MAX_DIM        Long-edge pixel limit for "auto" canvas (0 = unused)
#   INNER          Inner border thickness in px (thin black rule)
#   OUTER          Outer border thickness in px (wide mat)
#   INNER_COLOR    Hex color for inner border
#   OUTER_COLOR    Hex color for outer mat / background
#   QUALITY        JPEG output quality (1–100)
#   TEXT_DIV       font_size = OUTER / TEXT_DIV  (0 = no text)
#   STRIP_META     true = strip EXIF (good for social), false = keep

load_profile() {
  case "$1" in

    # ── Instagram ──────────────────────────────────────────────────────────
    # Images are fit (not cropped) into the canvas; the mat fills the sides.
    # This gives a clean framed look regardless of source aspect ratio.
    instagram-square)
      CANVAS="1080x1080";  CANVAS_MODE="fit"; MAX_DIM=0
      INNER=8;    OUTER=90;  QUALITY=92
      INNER_COLOR="#1c1c1c"; OUTER_COLOR="#f5f1eb"
      TEXT_DIV=3;  STRIP_META=true
      ;;

    instagram-portrait)   # 4:5 — highest organic reach on feed
      CANVAS="1080x1350";  CANVAS_MODE="fit"; MAX_DIM=0
      INNER=8;    OUTER=90;  QUALITY=92
      INNER_COLOR="#1c1c1c"; OUTER_COLOR="#f5f1eb"
      TEXT_DIV=3;  STRIP_META=true
      ;;

    instagram-landscape)  # 1.91:1 — wide/cinematic
      CANVAS="1080x566";   CANVAS_MODE="fit"; MAX_DIM=0
      INNER=6;    OUTER=52;  QUALITY=92
      INNER_COLOR="#1c1c1c"; OUTER_COLOR="#f5f1eb"
      TEXT_DIV=3;  STRIP_META=true
      ;;

    # ── Landscape-in-portrait (cream mat) ─────────────────────────────────
    # Full landscape image kept intact, width-fitted to 1080px.
    # Top and bottom mat pads out to 4:5 portrait canvas (1080×1350).
    # Looks like a gallery print — intentional, editorial, clean.
    instagram-lap)
      CANVAS="1080x1350";  CANVAS_MODE="width"; MAX_DIM=0
      INNER=8;    OUTER=0;   QUALITY=92
      INNER_COLOR="#1c1c1c"; OUTER_COLOR="#f5f1eb"
      TEXT_DIV=0;  STRIP_META=true
      ;;

    # ── Landscape-in-portrait (dark mat) ──────────────────────────────────
    # Same as above but dark mat — suits moody/industrial/night work.
    instagram-lap-dark)
      CANVAS="1080x1350";  CANVAS_MODE="width"; MAX_DIM=0
      INNER=8;    OUTER=0;   QUALITY=92
      INNER_COLOR="#f5f1eb"; OUTER_COLOR="#1c1c1c"
      TEXT_DIV=0;  STRIP_META=true
      ;;

    # ── Web ────────────────────────────────────────────────────────────────
    web)                  # Framed, max 2400px long edge
      CANVAS="auto";       CANVAS_MODE="fit"; MAX_DIM=2400
      INNER=6;    OUTER=70;  QUALITY=85
      INNER_COLOR="#1c1c1c"; OUTER_COLOR="#f5f1eb"
      TEXT_DIV=4;  STRIP_META=false
      ;;

    web-clean)            # No border, just resize + optimise (gallery, CMS)
      CANVAS="auto";       CANVAS_MODE="fit"; MAX_DIM=2400
      INNER=0;    OUTER=0;   QUALITY=85
      INNER_COLOR="";      OUTER_COLOR=""
      TEXT_DIV=0;  STRIP_META=false
      ;;

    # ── Print (placeholder — expand later) ────────────────────────────────
    # Tip: Print needs a fixed DPI target, not just pixel count.
    # A 12×18" print at 300 DPI = 3600×5400 px.
    # Coming soon: print-8x10, print-12x18, etc.
    print-placeholder)
      echo "Print profiles are not yet configured." >&2
      echo "Run with --help to see available profiles." >&2
      exit 1
      ;;

    *)
      echo "Error: unknown profile '$1'" >&2
      echo "Available profiles:" >&2
      echo "  instagram-square  instagram-portrait  instagram-landscape" >&2
      echo "  instagram-lap  instagram-lap-dark" >&2
      echo "  web  web-clean" >&2
      exit 1
      ;;
  esac
}

# ── Help ───────────────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
$SCRIPT v$VERSION  —  Frame and export photos for different output targets

Usage:
  $SCRIPT -p <profile> [options] <input> [input2 ...]

Profiles:
  instagram-square      1080×1080  — fits any ratio, pads sides with mat
  instagram-portrait    1080×1350  — 4:5, best feed reach
  instagram-landscape   1080×566   — cinematic 1.91:1
  instagram-lap         1080×1350  — landscape image in portrait canvas, cream mat
  instagram-lap-dark    1080×1350  — landscape image in portrait canvas, dark mat
  web                   ≤2400px    — framed, keeps EXIF
  web-clean             ≤2400px    — no borders, optimised (CMS/gallery use)

Options:
  -p, --profile <name>    Output profile  (default: web)
  -o, --output  <dir>     Output directory  (default: ./framed)
  -t, --text    <text>    Custom label instead of filename
  -n, --no-text           Suppress text label entirely
      --overwrite         Overwrite existing output files
      --dry-run           Print commands without executing
  -v, --verbose           Show full ImageMagick command per file
  -h, --help              Show this message

Text label:
  By default, the filename (without extension) is placed as a small subtle
  label centred in the bottom mat.  Use -t to override with your own text
  (e.g. a website URL or your name).  Use -n to suppress it completely.

  The label is intentionally unobtrusive — it deters casual reuse without
  visually stamping over the image like a traditional watermark.

Examples:
  $SCRIPT -p instagram-square ./exports/*.jpg
  $SCRIPT -p web -o ~/site/assets/photos ./exports/session01/*.tif
  $SCRIPT -p instagram-portrait -t "yoursite.com" ./exports/*.jpg
  $SCRIPT -p instagram-lap ./exports/landscape_shot.jpg
  $SCRIPT -p instagram-lap-dark -n ./exports/night_shoot/*.jpg
  $SCRIPT -p web-clean -n ./exports/press_kit/*.jpg

EOF
}

# ── Argument parsing ───────────────────────────────────────────────────────────
INPUTS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--profile)   PROFILE="$2";               shift 2 ;;
    -o|--output)    OUTPUT_DIR="$2";             shift 2 ;;
    -t|--text)      CUSTOM_TEXT="$2"; TEXT_MODE="custom"; shift 2 ;;
    -n|--no-text)   TEXT_MODE="none";            shift ;;
    --overwrite)    OVERWRITE=true;              shift ;;
    --dry-run)      DRY_RUN=true;                shift ;;
    -v|--verbose)   VERBOSE=true;                shift ;;
    -h|--help)      usage; exit 0 ;;
    --)             shift; INPUTS+=("$@"); break ;;
    -*)             echo "Unknown option: $1" >&2; usage; exit 1 ;;
    *)              INPUTS+=("$1");              shift ;;
  esac
done

if [[ ${#INPUTS[@]} -eq 0 ]]; then
  echo "Error: no input files specified." >&2; usage; exit 1
fi

# ── Load profile and set up output dir ────────────────────────────────────────
load_profile "$PROFILE"
mkdir -p "$OUTPUT_DIR"

# ── Check ImageMagick ──────────────────────────────────────────────────────────
if ! command -v convert &>/dev/null; then
  echo "Error: ImageMagick 'convert' not found. Install with: sudo apt install imagemagick" >&2
  exit 1
fi

# ── Process a single file ──────────────────────────────────────────────────────
process_file() {
  local input="$1"
  local stem ext outfile label

  stem="$(basename "${input%.*}")"
  ext="${input##*.}"
  ext_lower="${ext,,}"

  # Always export as JPEG for social/web profiles
  case "$PROFILE" in
    instagram-*|web*) outfile="$OUTPUT_DIR/${stem}.jpg" ;;
    *)                outfile="$OUTPUT_DIR/${stem}_framed.${ext_lower}" ;;
  esac

  # Skip if exists and not overwriting
  if [[ -f "$outfile" && "$OVERWRITE" == false ]]; then
    echo "  skip (exists): $(basename "$outfile")  — use --overwrite to replace"
    return
  fi

  # ── Resolve label ────────────────────────────────────────────────────────
  case "$TEXT_MODE" in
    filename) label="$stem" ;;
    custom)   label="$CUSTOM_TEXT" ;;
    none)     label="" ;;
  esac

  # ── Build ImageMagick command ─────────────────────────────────────────────
  local cmd=("convert" "$input")

  # Convert to sRGB (critical for Instagram/web colour accuracy)
  cmd+=(-colorspace sRGB)

  # Strip metadata for social exports
  [[ "$STRIP_META" == true ]] && cmd+=(-strip)

  if [[ "$CANVAS" == "auto" ]]; then
    # ── Web / auto canvas ────────────────────────────────────────────────
    # Shrink only (no upscale), maintain aspect ratio
    cmd+=(-resize "${MAX_DIM}x${MAX_DIM}>")

    [[ $INNER -gt 0 ]] && cmd+=(-bordercolor "$INNER_COLOR" -border "$INNER")
    [[ $OUTER -gt 0 ]] && cmd+=(-bordercolor "$OUTER_COLOR" -border "$OUTER")

  elif [[ "$CANVAS_MODE" == "width" ]]; then
    # ── Landscape-in-portrait ────────────────────────────────────────────
    # Width-constrained fit: image fills the full canvas width, top and
    # bottom mat pads vertically to the portrait canvas height.
    # The inner rule goes tight around the image before any padding.
    local cw ch image_w
    cw="${CANVAS%%x*}"
    ch="${CANVAS##*x}"

    # Image fits within canvas width minus inner border on each side
    image_w=$(( cw - 2 * INNER ))

    # Step 1: Resize to fit within image_w wide (height unconstrained — preserve ratio)
    cmd+=(-resize "${image_w}x>")

    # Step 2: Add tight inner border around the image
    [[ $INNER -gt 0 ]] && cmd+=(-bordercolor "$INNER_COLOR" -border "${INNER}")

    # Step 3: Pad vertically to full canvas height with mat colour
    cmd+=(
      -gravity center
      -background "$OUTER_COLOR"
      -extent "${cw}x${ch}"
    )

  else
    # ── Fixed canvas fit (standard Instagram) ────────────────────────────
    # The image gets a tight inner border first, THEN is padded out to the
    # canvas size with mat colour. This keeps the black rule tight around
    # the image regardless of aspect ratio — no uneven borders.
    local cw ch content_w content_h image_w image_h
    cw="${CANVAS%%x*}"
    ch="${CANVAS##*x}"
    # Full content area (inside the outer mat)
    content_w=$(( cw - 2 * OUTER ))
    content_h=$(( ch - 2 * OUTER ))
    # Image area (inside the inner border)
    image_w=$(( content_w - 2 * INNER ))
    image_h=$(( content_h - 2 * INNER ))

    # Step 1: Resize image to fit within image area (preserves aspect ratio)
    cmd+=(
      -resize "${image_w}x${image_h}"
    )

    # Step 2: Add tight inner border around just the image
    [[ $INNER -gt 0 ]] && cmd+=(-bordercolor "$INNER_COLOR" -border "${INNER}")

    # Step 3: Pad out to full content area with mat colour (centres the framed image)
    cmd+=(
      -gravity center
      -background "$OUTER_COLOR"
      -extent "${content_w}x${content_h}"
    )

    # Step 4: Add outer mat border to hit final canvas size
    cmd+=(-bordercolor "$OUTER_COLOR" -border "$OUTER")
  fi

  # ── Text label ───────────────────────────────────────────────────────────
  # Sits centred in the bottom mat — subtle enough to deter casual theft,
  # unobtrusive enough to not distract from the image.
  if [[ -n "$label" && $OUTER -gt 0 && $TEXT_DIV -gt 0 ]]; then
    local font_size y_offset
    font_size=$(( OUTER / TEXT_DIV ))
    [[ $font_size -lt 8  ]] && font_size=8    # floor
    [[ $font_size -gt 36 ]] && font_size=36   # cap for sanity

    # Centre baseline in the bottom mat
    y_offset=$(( OUTER * 2 / 5 ))

    cmd+=(
      -font    "DejaVu-Sans"
      -pointsize "$font_size"
      -fill    "#9a9082"          # warm mid-grey — readable on cream mat
      -gravity South
      -annotate "+0+${y_offset}" "$label"
    )
  fi

  # ── Output ───────────────────────────────────────────────────────────────
  cmd+=(-quality "$QUALITY" "$outfile")

  if [[ "$DRY_RUN" == true ]]; then
    echo "[dry-run] ${cmd[*]}"
  else
    [[ "$VERBOSE" == true ]] && echo "  cmd: ${cmd[*]}"
    "${cmd[@]}" && echo "  ✓  $(basename "$outfile")"
  fi
}

# ── Main ───────────────────────────────────────────────────────────────────────
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  photoframe.sh  |  profile: $PROFILE  |  out: $OUTPUT_DIR"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

count=0; skipped=0; errors=0

for input in "${INPUTS[@]}"; do
  if [[ ! -f "$input" ]]; then
    echo "  warn: not found — $input"
    (( errors++ )); continue
  fi
  # Check it's an image type we expect
  case "${input,,}" in
    *.jpg|*.jpeg|*.png|*.tif|*.tiff|*.webp) ;;
    *) echo "  warn: skipping non-image file — $input"; (( skipped++ )); continue ;;
  esac

  if process_file "$input"; then
    count=$(( count + 1 ))
  else
    errors=$(( errors + 1 ))
  fi
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  done: $count processed | $skipped skipped | $errors errors"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"