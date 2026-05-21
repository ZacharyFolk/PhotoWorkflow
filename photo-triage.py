#!/usr/bin/env python3
"""
photo-triage.py — Scan, analyze, and organize a messy photo library

Safe by default: NEVER modifies or deletes originals.
Reads EXIF metadata, detects file source, finds duplicates,
generates a report, and optionally copies to a clean archive structure.

Requires:
  sudo apt install exiftool
  pip3 install tqdm  (optional — progress bar)

Usage:
  # Step 1: Scan and generate a report only (touches nothing)
  python3 photo-triage.py --scan /mnt/photos/inbox --report

  # Step 2: Review the report, then copy to clean archive
  python3 photo-triage.py --scan /mnt/photos/inbox --organize --dest /mnt/photos/archive

  # Find duplicates only
  python3 photo-triage.py --scan /mnt/photos/inbox --dupes

  # Full run: report + organize + flag dupes
  python3 photo-triage.py --scan /mnt/photos/inbox --report --organize --dupes --dest /mnt/photos/archive
"""

import os
import sys
import json
import hashlib
import shutil
import argparse
import subprocess
import csv
from pathlib import Path
from datetime import datetime
from collections import defaultdict

# ── Try to import tqdm for progress bar (optional) ────────────────────────────
try:
    from tqdm import tqdm
    HAS_TQDM = True
except ImportError:
    HAS_TQDM = False
    class tqdm:
        def __init__(self, iterable=None, **kwargs):
            self.iterable = iterable
        def __iter__(self):
            return iter(self.iterable)
        def __enter__(self): return self
        def __exit__(self, *a): pass
        def update(self, n=1): pass

# ── File type definitions ──────────────────────────────────────────────────────
RAW_EXTENSIONS     = {'.nef', '.dng', '.cr2', '.cr3', '.arw', '.orf', '.raf', '.rw2'}
JPEG_EXTENSIONS    = {'.jpg', '.jpeg'}
TIFF_EXTENSIONS    = {'.tif', '.tiff'}
PHONE_EXTENSIONS   = {'.heic', '.heif'}
VIDEO_EXTENSIONS   = {'.mp4', '.mov', '.avi', '.mts', '.m4v', '.mkv'}
ALL_MEDIA          = RAW_EXTENSIONS | JPEG_EXTENSIONS | TIFF_EXTENSIONS | PHONE_EXTENSIONS | VIDEO_EXTENSIONS

# Camera make → source label
CAMERA_MAKE_MAP = {
    'nikon':   'nikon',
    'ricoh':   'ricoh',
    'pentax':  'ricoh',   # Ricoh owns Pentax
    'apple':   'phone',
    'samsung': 'phone',
    'google':  'phone',
    'oneplus': 'phone',
    'huawei':  'phone',
    'xiaomi':  'phone',
    'lg':      'phone',
    'motorola':'phone',
}

# ── Detect source from EXIF data ───────────────────────────────────────────────
def detect_source(exif: dict, ext: str) -> str:
    """
    Returns one of: nikon | ricoh | phone | film-scan | video | unknown
    """
    # Video first
    if ext in VIDEO_EXTENSIONS:
        return 'video'

    make  = str(exif.get('Make') or '').lower().strip()
    model = str(exif.get('Model') or '').lower().strip()
    software = str(exif.get('Software') or '').lower()

    # SilverFast writes its name into the Software tag
    if 'silverfast' in software:
        return 'film-scan'

    # Check camera make
    for key, source in CAMERA_MAKE_MAP.items():
        if key in make:
            return source

    # NEF is always Nikon
    if ext == '.nef':
        return 'nikon'

    # DNG without make — likely Ricoh (GR series outputs DNG)
    if ext == '.dng':
        return 'ricoh'

    # HEIC without make — definitely phone
    if ext in PHONE_EXTENSIONS:
        return 'phone'

    # Large TIFF with no camera make and no SilverFast — likely a scan of some kind
    if ext in TIFF_EXTENSIONS and not make:
        return 'film-scan'

    # JPEG with no make — could be phone, processed export, or anything
    if ext in JPEG_EXTENSIONS and not make:
        return 'unknown'

    return 'unknown'

# ── Extract date from EXIF ─────────────────────────────────────────────────────
def extract_date(exif: dict, filepath: Path) -> tuple[datetime | None, str]:
    """
    Returns (datetime, source_of_date)
    source_of_date: 'exif' | 'file-mtime' | 'none'

    Priority:
      1. DateTimeOriginal  — when the shutter fired (most reliable)
      2. CreateDate        — when file was created by the camera
      3. ModifyDate        — less reliable, often when processed
      4. File mtime        — last resort, can be totally wrong
    """
    for tag in ('DateTimeOriginal', 'CreateDate', 'ModifyDate'):
        raw = str(exif.get(tag, '') or '')
        if raw and raw != '0000:00:00 00:00:00':
            try:
                # ExifTool returns format: "2023:03:18 14:22:05"
                dt = datetime.strptime(raw[:19], '%Y:%m:%d %H:%M:%S')
                if dt.year > 1990:  # sanity check
                    return dt, 'exif'
            except Exception:
                continue

    # Fall back to file modification time
    try:
        mtime = filepath.stat().st_mtime
        dt = datetime.fromtimestamp(mtime)
        if dt.year > 1990:
            return dt, 'file-mtime'
    except Exception:
        pass

    return None, 'none'

# ── Run exiftool on a batch of files ──────────────────────────────────────────
def run_exiftool(file_paths: list[Path]) -> dict:
    """
    Runs exiftool on a list of files and returns a dict of
    { filepath_str: { tag: value, ... } }
    """
    if not file_paths:
        return {}

    cmd = [
        'exiftool',
        '-json',
        '-Make', '-Model', '-Software',
        '-DateTimeOriginal', '-CreateDate', '-ModifyDate',
        '-ImageWidth', '-ImageHeight',
        '-FileSize',
        '--'
    ] + [str(p) for p in file_paths]

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
        data = json.loads(result.stdout)
        return {item.get('SourceFile', ''): item for item in data}
    except (subprocess.TimeoutExpired, json.JSONDecodeError, Exception) as e:
        print(f"  [warn] exiftool error: {e}", file=sys.stderr)
        return {}

# ── MD5 hash for duplicate detection ─────────────────────────────────────────
def file_hash(path: Path, chunk_size: int = 65536) -> str:
    h = hashlib.md5()
    try:
        with open(path, 'rb') as f:
            while chunk := f.read(chunk_size):
                h.update(chunk)
        return h.hexdigest()
    except Exception:
        return ''

# ── Build destination path for a file ─────────────────────────────────────────
def build_dest_path(dest_root: Path, source: str, dt: datetime | None,
                    date_source: str, original_name: str) -> Path:
    """
    Returns the full destination path for a file.

    Structure:
      digital/nikon/YYYY/YYYY-MM/filename
      digital/ricoh/YYYY/YYYY-MM/filename
      phone/YYYY/YYYY-MM/filename
      film-scan/scanned-YYYY-MM/filename   ← scan date, not shoot date
      video/YYYY/YYYY-MM/filename
      unknown/no-date/filename
      unknown/date-uncertain/YYYY-MM/filename   ← mtime fallback
    """
    ext = Path(original_name).suffix.lower()
    name = Path(original_name).name

    if source in ('nikon', 'ricoh'):
        if dt and date_source == 'exif':
            return dest_root / 'digital' / source / str(dt.year) / f'{dt.year}-{dt.month:02d}' / name
        elif dt:
            return dest_root / 'digital' / source / 'date-uncertain' / f'{dt.year}-{dt.month:02d}' / name
        else:
            return dest_root / 'digital' / source / 'no-date' / name

    elif source == 'phone':
        if dt:
            return dest_root / 'phone' / str(dt.year) / f'{dt.year}-{dt.month:02d}' / name
        else:
            return dest_root / 'phone' / 'no-date' / name

    elif source == 'film-scan':
        # Use scan date (what we have) not shoot date (what we don't)
        # Flag clearly so you know to rename these manually
        if dt:
            return dest_root / 'film-scan' / f'scanned-{dt.year}-{dt.month:02d}' / name
        else:
            return dest_root / 'film-scan' / 'no-date' / name

    elif source == 'video':
        if dt:
            return dest_root / 'video' / str(dt.year) / f'{dt.year}-{dt.month:02d}' / name
        else:
            return dest_root / 'video' / 'no-date' / name

    else:  # unknown
        if dt and date_source == 'exif':
            return dest_root / 'unknown' / f'{dt.year}-{dt.month:02d}' / name
        else:
            return dest_root / 'unknown' / 'no-date' / name

# ── Safe copy with collision handling ─────────────────────────────────────────
def safe_copy(src: Path, dest: Path) -> Path:
    """
    Copy src to dest. If dest exists, append _2, _3 etc. until unique.
    Returns the actual destination path used.
    """
    dest.parent.mkdir(parents=True, exist_ok=True)
    if not dest.exists():
        shutil.copy2(src, dest)
        return dest

    # Handle collision — file with same name already exists
    stem = dest.stem
    suffix = dest.suffix
    counter = 2
    while True:
        candidate = dest.parent / f'{stem}_{counter}{suffix}'
        if not candidate.exists():
            shutil.copy2(src, candidate)
            return candidate
        counter += 1

# ── Main ───────────────────────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(
        description='Photo triage: scan, report, organize. Safe by default.'
    )
    parser.add_argument('--scan',    required=True,  help='Directory to scan (your messy inbox)')
    parser.add_argument('--dest',    default=None,   help='Destination for organized archive (required with --organize)')
    parser.add_argument('--report',  action='store_true', help='Generate CSV report of all files')
    parser.add_argument('--organize',action='store_true', help='Organize files into clean structure')
    parser.add_argument('--move',    action='store_true', help='MOVE files instead of copy (use after culling, when space is tight). Requires --organize.')
    parser.add_argument('--dupes',   action='store_true', help='Find and report duplicate files')
    parser.add_argument('--batch',   type=int, default=50, help='Files per exiftool batch (default 50)')
    args = parser.parse_args()

    scan_root = Path(args.scan).resolve()
    dest_root = Path(args.dest).resolve() if args.dest else None

    if args.organize and not dest_root:
        print("Error: --organize requires --dest <path>", file=sys.stderr)
        sys.exit(1)

    if getattr(args, 'move', False) and not args.organize:
        print("Error: --move requires --organize", file=sys.stderr)
        sys.exit(1)

    if getattr(args, 'move', False):
        print("\n  WARNING: MOVE MODE — files will be relocated, not copied.")
        print("  Make sure you have culled and are happy with what remains.")
        response = input("  Type YES to continue: ").strip()
        if response != 'YES':
            print("  Aborted.")
            sys.exit(0)

    if dest_root and dest_root.is_relative_to(scan_root):
        print("Error: --dest must not be inside --scan directory", file=sys.stderr)
        sys.exit(1)

    # ── Check exiftool is available ──────────────────────────────────────────
    if shutil.which('exiftool') is None:
        print("Error: exiftool not found. Install with: sudo apt install exiftool", file=sys.stderr)
        sys.exit(1)

    print(f"\n{'━'*60}")
    print(f"  photo-triage.py")
    print(f"  Scanning: {scan_root}")
    if dest_root:
        print(f"  Archive:  {dest_root}")
    print(f"{'━'*60}\n")

    # ── Discover all media files ─────────────────────────────────────────────
    print("Discovering files...")
    all_files = []
    for root, dirs, files in os.walk(scan_root):
        # Skip hidden directories and the dest root if nested
        dirs[:] = [d for d in dirs if not d.startswith('.')]
        for fname in files:
            if Path(fname).suffix.lower() in ALL_MEDIA:
                all_files.append(Path(root) / fname)

    print(f"Found {len(all_files):,} media files\n")

    if not all_files:
        print("No media files found. Check your --scan path.")
        sys.exit(0)

    # ── Process files in batches via exiftool ────────────────────────────────
    print("Reading EXIF metadata (this may take a few minutes)...")
    results = []
    hash_map = defaultdict(list)  # hash → [filepath, ...]

    batches = [all_files[i:i+args.batch] for i in range(0, len(all_files), args.batch)]

    with tqdm(total=len(all_files), unit='file', disable=not HAS_TQDM) as pbar:
        for batch in batches:
            exif_data = run_exiftool(batch)

            for filepath in batch:
                exif = exif_data.get(str(filepath), {})
                ext = filepath.suffix.lower()
                source = detect_source(exif, ext)
                dt, date_source = extract_date(exif, filepath)

                file_size = filepath.stat().st_size if filepath.exists() else 0

                entry = {
                    'original_path': str(filepath),
                    'filename':      filepath.name,
                    'extension':     ext,
                    'source':        source,
                    'date':          dt.strftime('%Y-%m-%d') if dt else '',
                    'date_source':   date_source,
                    'year':          dt.year if dt else '',
                    'month':         f'{dt.month:02d}' if dt else '',
                    'make':          exif.get('Make', ''),
                    'model':         exif.get('Model', ''),
                    'software':      exif.get('Software', ''),
                    'size_bytes':    file_size,
                    'size_mb':       round(file_size / 1_048_576, 2),
                    'hash':          '',   # filled in if --dupes
                    'is_duplicate':  False,
                    'dest_path':     '',
                }

                if dest_root:
                    dest_path = build_dest_path(dest_root, source, dt, date_source, filepath.name)
                    entry['dest_path'] = str(dest_path)

                results.append(entry)
                pbar.update(1)

    # ── Duplicate detection ──────────────────────────────────────────────────
    if args.dupes:
        print("\nHashing files for duplicate detection...")
        hash_map = defaultdict(list)

        with tqdm(total=len(results), unit='file', disable=not HAS_TQDM) as pbar:
            for entry in results:
                h = file_hash(Path(entry['original_path']))
                entry['hash'] = h
                if h:
                    hash_map[h].append(entry['original_path'])
                pbar.update(1)

        # Mark duplicates
        dupe_count = 0
        for h, paths in hash_map.items():
            if len(paths) > 1:
                for entry in results:
                    if entry['hash'] == h:
                        entry['is_duplicate'] = True
                        dupe_count += 1

        print(f"  Found {dupe_count:,} files that are duplicates of at least one other file")

    # ── Generate report ──────────────────────────────────────────────────────
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    report_path = Path('.') / f'triage_report_{timestamp}.csv'

    if args.report or True:   # always write report
        with open(report_path, 'w', newline='', encoding='utf-8') as f:
            writer = csv.DictWriter(f, fieldnames=list(results[0].keys()))
            writer.writeheader()
            writer.writerows(results)
        print(f"\nReport written: {report_path}")

    # ── Print summary ────────────────────────────────────────────────────────
    print(f"\n{'━'*60}")
    print(f"  SUMMARY")
    print(f"{'━'*60}")

    by_source = defaultdict(int)
    by_year   = defaultdict(int)
    no_date   = 0
    mtime_only= 0
    dupes     = 0
    total_mb  = 0

    for e in results:
        by_source[e['source']] += 1
        if e['year']:
            by_year[e['year']] += 1
        if not e['date']:
            no_date += 1
        if e['date_source'] == 'file-mtime':
            mtime_only += 1
        if e['is_duplicate']:
            dupes += 1
        total_mb += e['size_mb']

    print(f"\n  Total files: {len(results):,}")
    print(f"  Total size:  {total_mb/1024:.1f} GB")
    print(f"\n  By source:")
    for source, count in sorted(by_source.items(), key=lambda x: -x[1]):
        print(f"    {source:<16} {count:>5,}")

    print(f"\n  By year:")
    for year, count in sorted(by_year.items()):
        print(f"    {year}  {count:>5,}")

    if no_date:
        print(f"\n  ⚠  {no_date:,} files have no usable date — will land in no-date/")
    if mtime_only:
        print(f"  ⚠  {mtime_only:,} files dated from file mtime only (unreliable) — marked date-uncertain/")
    if dupes:
        print(f"  ⚠  {dupes:,} duplicate files detected — review before organizing")

    print(f"\n  Film scans note:")
    film_count = by_source.get('film-scan', 0)
    if film_count:
        print(f"    {film_count:,} film scan files found.")
        print(f"    These will be organized by SCAN DATE (not shoot date) under film-scan/")
        print(f"    You will need to manually rename/reorganize these by film roll.")
    else:
        print(f"    No film scan files detected in this pass.")

    # ── Organize files (copy or move) ────────────────────────────────────────
    if args.organize and dest_root:
        use_move = getattr(args, 'move', False)
        mode_label = "MOVING" if use_move else "COPYING"
        print(f"\n{'━'*60}")
        print(f"  ORGANIZING — {mode_label} to {dest_root}")
        if not use_move:
            print(f"  Originals are NOT touched.")
        print(f"{'━'*60}\n")

        copied = 0
        skipped_dupes = 0
        errors = 0

        with tqdm(total=len(results), unit='file', disable=not HAS_TQDM) as pbar:
            for entry in results:
                src = Path(entry['original_path'])
                dest = Path(entry['dest_path']) if entry['dest_path'] else None

                if not dest:
                    pbar.update(1)
                    continue

                # Skip duplicates — only take the first instance
                if entry['is_duplicate'] and args.dupes:
                    if dest.exists():
                        skipped_dupes += 1
                        pbar.update(1)
                        continue

                try:
                    if use_move:
                        dest.parent.mkdir(parents=True, exist_ok=True)
                        if dest.exists():
                            # collision — rename with counter
                            stem, suffix = dest.stem, dest.suffix
                            counter = 2
                            while dest.exists():
                                dest = dest.parent / f"{stem}_{counter}{suffix}"
                                counter += 1
                        shutil.move(str(src), dest)
                        actual_dest = dest
                    else:
                        actual_dest = safe_copy(src, dest)
                    entry['dest_path'] = str(actual_dest)
                    copied += 1
                except Exception as ex:
                    print(f"\n  [error] {src.name}: {ex}", file=sys.stderr)
                    errors += 1

                pbar.update(1)

        verb = "Moved" if use_move else "Copied"
        print(f"\n  {verb}:           {copied:,}")
        print(f"  Dupes skipped:   {skipped_dupes:,}")
        print(f"  Errors:          {errors:,}")
        if not use_move:
            print(f"\n  Originals remain at: {scan_root}")
        print(f"  Archive at:          {dest_root}")

        # Update report with final dest paths
        with open(report_path, 'w', newline='', encoding='utf-8') as f:
            writer = csv.DictWriter(f, fieldnames=list(results[0].keys()))
            writer.writeheader()
            writer.writerows(results)
        print(f"  Report updated:      {report_path}")

    print(f"\n{'━'*60}")
    print(f"  Done. Review {report_path} to see exactly what was found.")
    print(f"{'━'*60}\n")

if __name__ == '__main__':
    main()