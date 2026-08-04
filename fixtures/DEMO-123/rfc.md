# RFC — Segment CSV Export (Confluence DEV space)

## Summary

Adds a synchronous CSV export endpoint for a single segment, plus a front-end button on the
segment detail page.

## Data model

- Endpoint: `GET /api/segments/{id}/export.csv`
- Auth: requires the `segment.export` permission on the segment's workspace.
- Response: `text/csv`, UTF-8, RFC 4180 quoting.

## CSV format

- Header row always present.
- Columns in order: `email`, `first_name`, `last_name`, `created_at`.
- `created_at` is ISO 8601 UTC (e.g. `2026-07-01T12:00:00Z`).

## Limits

- Synchronous export is capped at **5,000** contacts. Above this cap the endpoint returns
  HTTP 413 and the UI shows a "too large" message. Larger segments use the scheduled
  export flow (DEMO-124).

  > NOTE: This 5,000 cap is the value agreed in engineering. It differs from the 10,000
  > figure in the DEMO-123 acceptance criteria. This mismatch must be resolved before test.

## States

- `idle` → `generating` → `ready` (file downloads) — for segments within the cap.
- `idle` → `blocked` (413 + message) — for segments over the cap.

## Permissions

- `segment.export` — required to see the button and call the endpoint.
- Users without it get HTTP 403 if they call the endpoint directly.

## Related

- Rate limiting is defined in the "Export Throttling Policy" page. (See that page for the
  per-user request limits.)
