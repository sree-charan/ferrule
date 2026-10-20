# Changelog

What changed in each version of Recast.

## 1.12.0

First release of Recast, by Sree Charan.

- **Fully offline.** No update check, no in-app updater, no sponsor links. Recast never connects to the internet on
  its own. The only network access left is the Download button on the Engines page, which you press yourself.
- **Documents can't phone home.** Pictures and media that point at the internet are left out when Pandoc converts a
  document, so a remote image in a Markdown or HTML file is never fetched.
- No download prompt on first start.
