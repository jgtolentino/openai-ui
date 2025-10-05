# Figma Integration (Tokens ↔ Wireframes)

## Export tokens (plugin)
1. Figma → Plugins → Development → **Import manifest** → `tools/figma-export-tokens/manifest.json`
2. Open Finebank / iOS kit in Dev Mode.
3. Run **Export Design Tokens → JSON** → click **Export** → copy JSON → paste into `spec/design-tokens.json`.
4. `pnpm spec:tokens` to regenerate `styles/tokens.css`.

## Render wireframes in Figma (plugin)
1. Figma → Plugins → Development → **Import manifest** → `tools/figma-plugin/manifest.json`
2. Run **JSON → Figma (Wireframes + Tokens)** → paste your `design-tokens.json` + `wireframes.json` on first run.
3. Enter screen id (e.g. `web.dashboard`) → **Render**.

## REST exporter (optional)
```bash
FIGMA_TOKEN=... FILE_KEY=... pnpm figma:rest:export
```
Writes `spec/design-tokens.json` if the file publishes variables/styles.
