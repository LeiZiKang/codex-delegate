# UI review on a token budget

Looking at many screenshots costs Claude a lot. Push the render → inspect → fix loop to
Codex, and only look at the final result.

## Brief section to paste

```markdown
## Render previews and self-check
1. Make the views previewable: views take plain value types (no live services); add fixtures
   covering normal, long text (truncation), empty/loading/error states, light and dark.
2. Render images (prefer A):
   - A. Xcode MCP: `xcrun mcpbridge` (configured as an MCP server in Codex). Open the project
     and use its preview-rendering tool to render each `#Preview`.
   - B. Fallback: a DEBUG-only `--render-previews <outdir>` launch argument or script using
     SwiftUI `ImageRenderer` (scale 2). Materials like `.ultraThinMaterial` may render flat
     off-screen; put a gradient behind them and say so in the report.
   - Web: Playwright `page.screenshot()` at fixed viewport sizes, light and dark.
3. Check every image against this list; fix and re-render if an item fails (max 3 rounds):
   1. <alignment rule>
   2. <typography rule>
   3. <spacing / truncation rule>
   4. <contrast in light and dark>
4. Keep ONLY the final images in `<notes>/ui/` (≤ 800 px wide), named `<view>-<light|dark>.png`.
   Delete intermediate rounds. Nothing goes into the repo.
5. Report (`<notes>/ui/report.md`, ≤ 25 lines): each checklist item as pass /
   pass-after-fix / fail (reason), files changed, method A or B.
```

## Claude's side
- Read the report first. Open only the images for items marked fail or pass-after-fix,
  and at most one light + one dark overview.
- If the Codex MCP setup is missing, Codex falls back to B; that is fine.
- For setting up the Xcode MCP in Codex: add an MCP server entry running `xcrun mcpbridge`
  in `~/.codex/config.toml` (requires Xcode with MCP support).
