# pdfrenamer

Rename PDFs based on a QR code on the first page. The QR code must start with `doc-id:`; the file is renamed to `<id>.pdf`.

## Requirements
- macOS 15+
- Swift 6.2+

## Install
```sh
swift build -c release
```

## Usage
```sh
swift run pdfrenamer /path/to/file1.pdf /path/to/file2.pdf
```

Notes:
- Only PDFs are processed.
- If any page has multiple `doc-id:` QR codes, the file is skipped.
- If a QR code appears on a page after page 1, the file is skipped.
- If the target filename already exists, the file is skipped.

## Run With [Mint](https://github.com/yonaskolb/Mint)

```sh
mint run Lutzifer/pdfrenamer /path/to/file1.pdf
```

## Label Sheet (TeX)
The `labels.tex` file generates a sheet of QR-code labels. Each label prints an ID like `A-2026-001` and a QR code that encodes `doc-id:<id>`.

To regenerate the label list:
```sh
ruby labels.rb > labels.tex
```

To build the PDF:
```sh
pdflatex labels.tex
```
