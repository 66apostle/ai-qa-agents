# DEMO-123 — Export an audience segment to CSV

**Type:** Story
**Parent Epic:** DEMO-100
**Links:** relates to PRODUCT-45 (idea), spec in RFC "Segment CSV Export" (Confluence DEV)
**Status:** Ready for Test

## Description

Users on the Segments page need to export the contacts of a single segment to a CSV file.
The export runs from the segment detail view. The file downloads in the browser. Large
segments must not block the UI.

## Acceptance Criteria

- **AC1:** A user with the `segment.export` permission sees an "Export CSV" button on the
  segment detail page.
- **AC2:** A user without the `segment.export` permission does not see the button.
- **AC3:** Clicking "Export CSV" generates a file that contains one header row and one row
  per contact in the segment.
- **AC4:** The CSV columns are, in order: `email`, `first_name`, `last_name`, `created_at`.
- **AC5:** A segment with more than **10,000** contacts cannot be exported synchronously.
  The system shows the message "Segment too large for direct export. Use scheduled export."
- **AC6:** An empty segment (0 contacts) exports a file with only the header row.

## Comments

- **PM (2026-07-30):** Please confirm the exact wording of the "too large" message with
  design. See the rate-limiting rules in the "Export Throttling Policy" doc.
- **Dev (2026-07-31):** Note the row limit — see the RFC. There may be a mismatch with AC5.
