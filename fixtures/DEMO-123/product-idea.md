# PRODUCT-45 — "Let me get my segment data out" (Idea)

## Problem

Customers repeatedly ask support to send them the contacts of a segment as a spreadsheet.
This is manual, slow, and error-prone.

## Intended user behavior

- The user opens a segment they own.
- The user clicks one button and gets a spreadsheet-friendly file immediately.
- For very large segments, the user understands the export will be handled another way
  (scheduled) instead of failing silently.

## Success signal

- Support tickets asking for manual segment exports drop to near zero.

## Notes

- The user must only export segments they have permission to see.
- Personally identifiable data is included, so access control is important.
