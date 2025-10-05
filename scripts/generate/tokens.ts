import fs from 'node:fs';
const tokens = JSON.parse(fs.readFileSync('spec/design-tokens.json','utf8'));
const css = `:root{
  --color-brand-primary:${tokens.color.brand["primary"]};
  --color-brand-primary-600:${tokens.color.brand["primary-600"]};
  --color-brand-accent:${tokens.color.brand["accent"]};
  --color-ui-bg:${tokens.color.ui["bg"]};
  --color-ui-bg-elev:${tokens.color.ui["bg-elev"]};
  --color-ui-text:${tokens.color.ui["text"]};
  --color-ui-muted:${tokens.color.ui["muted"]};
  --color-ui-border:${tokens.color.ui["border"]};
  --color-danger:${tokens.color["danger"]};
  --color-warn:${tokens.color["warn"]};
  --color-success:${tokens.color["success"]};
  --radius-sm:${tokens.radius.sm}; --radius-md:${tokens.radius.md}; --radius-lg:${tokens.radius.lg};
  --space-xs:${tokens.space.xs}; --space-sm:${tokens.space.sm}; --space-md:${tokens.space.md}; --space-lg:${tokens.space.lg}; --space-xl:${tokens.space.xl}; --space-2xl:${tokens.space["2xl"]};
  --shadow-sm:${tokens.shadow.sm}; --shadow-md:${tokens.shadow.md};
  --font-base:${tokens.typography.fontFamily.base};
  --fs-xs:${tokens.typography.size.xs}; --fs-sm:${tokens.typography.size.sm}; --fs-md:${tokens.typography.size.md}; --fs-lg:${tokens.typography.size.lg}; --fs-xl:${tokens.typography.size.xl}; --fs-2xl:${tokens.typography.size["2xl"]};
}
*{font-family:var(--font-base)}
html,body{background:var(--color-ui-bg);color:var(--color-ui-text)}
*,*::before,*::after{transition:none!important;animation:none!important}
`;
fs.mkdirSync('styles',{recursive:true});
fs.writeFileSync('styles/tokens.css', css);
console.log('✓ styles/tokens.css emitted');
