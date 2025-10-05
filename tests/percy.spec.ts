import { test } from '@playwright/test';
import wireframes from '../spec/wireframes.json';
const screens: {id:string, platform:'web'|'mobile'}[] = (wireframes as any).screens;

test.describe('Percy baselines', () => {
  for (const s of screens) {
    test(s.id, async ({ page }) => {
      const url = `http://localhost:3001/__fixtures__/${s.id}`;
      await page.setViewportSize({ width: s.platform==='mobile' ? 375 : 1280, height: 900 });
      await page.goto(url, { waitUntil: 'networkidle' });
      await page.waitForTimeout(50);
      // @ts-ignore percy injected by percy exec
      await (global as any).percySnapshot?.(s.id, { widths: [s.platform==='mobile'?375:1280], minHeight: 900 });
    });
  }
});
