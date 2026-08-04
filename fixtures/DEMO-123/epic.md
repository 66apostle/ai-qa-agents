# DEMO-100 — Segment data portability (Epic)

## Goal

Let customers move segment data out of the platform for their own analytics and compliance
needs. Export must be self-service and require no support ticket.

## Scope limits

- This epic covers **export only**. Import is out of scope and tracked separately.
- CSV is the only format in this epic. JSON/Parquet are a later epic.

## Sibling stories

- DEMO-123 — Export a segment to CSV (this story).
- DEMO-124 — Scheduled export for large segments (separate story, not in test scope here).
- DEMO-125 — Export audit log entry when a user exports data.
