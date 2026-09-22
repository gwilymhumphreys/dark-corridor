---
name: items
description: Rebuild the item browser page (every item with its in-game tooltip text and icons, filterable by character, type, rarity and keyword) and open it. Use when the user says "/items", "show me the items", "open the item browser", "browse the items", or wants to look over a character's items. Can also update the private online copy.
---

# Item browser

Rebuilds the page from the current item code and opens it. The tool is described in
`docs/systems/item_browser.md`.

## Steps

1. Rebuild the page:

   ```
   tools/item_browser.sh
   ```

   It prints the number of items written. If it prints errors, fix them before going on (a
   broken item or tooltip change is the usual cause) and tell the user what was wrong.

2. Open it in the user's browser:

   ```
   start "" "_temp/item_browser.html"
   ```

   (PowerShell: `Start-Process _temp/item_browser.html`.)

3. Only if the user asks for the online copy (to view on another device, or says "publish",
   "update the link"): republish `_temp/item_browser.html` with the Artifact tool to
   `https://claude.ai/artifact/Fmpa4dypEymFQHnyWGAjF2`, passing that URL as `url` and no `icon`.
   The generated file replaces the whole page, so nothing from the live version needs merging.

4. Reply in one or two lines: how many items were written, and that the page is open (plus the
   link if it was republished).

Do not commit `_temp/item_browser.html`; `_temp/` is gitignored. Changes to the page's layout or
filters go in `tools/item_browser.html`, and new data fields in `tools/item_browser.gd`.
