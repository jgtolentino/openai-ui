export {};

function rgbToHex(p:{r:number,g:number,b:number}):string{
  const to=v=>('0'+Math.round(v*255).toString(16)).slice(-2);
  return `#${to(p.r)}${to(p.g)}${to(p.b)}`.toUpperCase();
}
function solidToHex(paints:ReadonlyArray<Paint>):string|undefined{
  const solid = paints?.find(p=>p.type==='SOLID' && 'color' in p) as SolidPaint|undefined;
  return solid ? rgbToHex(solid.color) : undefined;
}
async function exportStyles(){
  const paint:Record<string,string> = {};
  const text:Record<string, any> = {};
  const effects:Record<string, any> = {};
  for(const s of figma.getLocalPaintStyles()){
    const hex = solidToHex(s.paints as any);
    if(hex) paint[s.name] = hex;
  }
  for(const s of figma.getLocalTextStyles()){
    text[s.name] = {
      fontFamily: (s.fontName as FontName).family,
      style: (s.fontName as FontName).style,
      size: s.fontSize, lineHeight: (s.lineHeight as any)?.value ?? null, letterSpacing: (s.letterSpacing as any)?.value ?? null,
      weight: (s.fontWeight as any) ?? null
    };
  }
  for(const s of figma.getLocalEffectStyles()){
    effects[s.name] = s.effects;
  }
  return { paint, text, effects };
}
async function exportVariables(){
  const out:Record<string, any> = {};
  try{
    const collections = figma.variables.getLocalVariableCollections();
    for(const c of collections){
      out[c.name] = out[c.name] || {};
      for(const vId of c.variableIds){
        const v = figma.variables.getVariableById(vId)!;
        const modeId = c.modes[0]?.modeId;
        let value:any = v.valuesByMode?.[modeId];
        if(v.resolvedType === 'COLOR' && value){ value = rgbToHex(value); }
        out[c.name][v.name] = value;
      }
    }
  }catch{}
  return out;
}
function shapeSchema(styles:any, vars:any){
  const color:any = {};
  for(const [k,v] of Object.entries(styles.paint||{})) color[k.replace(/\s+/g,'/')] = v;
  for(const [coll, items] of Object.entries(vars||{})){
    for(const [k,v] of Object.entries(items as any)){
      if(typeof v === 'string' && v.startsWith('#')) color[`${coll}/${k}`] = v;
    }
  }
  const tokens = {
    color: {
      brand: {
        primary: color['Brand/Primary'] || color['Theme/Primary'] || '#0A6EEB',
        "primary-600": color['Brand/Primary 600'] || '#095CC3',
        accent: color['Brand/Accent'] || '#2ED3B7'
      },
      ui: {
        bg: color['Surface/Background'] || '#0B0D12',
        "bg-elev": color['Surface/Elevated'] || '#12151C',
        text: color['Text/Primary'] || '#E6EAF2',
        muted: color['Text/Secondary'] || '#A6B0C3',
        border: color['Border/Default'] || '#2A2F3A'
      },
      danger: color['Semantic/Danger'] || '#EF4444',
      warn: color['Semantic/Warning'] || '#F59E0B',
      success: color['Semantic/Success'] || '#22C55E'
    },
    radius: { sm:'6px', md:'10px', lg:'14px' },
    space:  { xs:'4px', sm:'8px', md:'12px', lg:'16px', xl:'24px', '2xl':'32px' },
    shadow: { sm:'0 1px 2px rgba(0,0,0,0.2)', md:'0 4px 12px rgba(0,0,0,0.3)' },
    typography: {
      fontFamily: { base: (styles.text && Object.values(styles.text)[0] && (Object.values(styles.text)[0] as any).fontFamily) || 'Inter' },
      size: { xs:12, sm:14, md:16, lg:20, xl:24, '2xl':32 },
      weight: { regular:400, medium:500, semibold:600 }
    },
    charts: { palette: ['#0A6EEB','#2ED3B7','#F59E0B','#EF4444','#8B5CF6'] },
    meta: { source: 'figma-plugin', exportedAt: new Date().toISOString() }
  };
  return tokens;
}
figma.showUI(__html__, { width: 420, height: 220 });
figma.ui.onmessage = async (m) => {
  if(m.type !== 'export') return;
  const styles = await exportStyles();
  const vars = await exportVariables();
  const tokens = shapeSchema(styles, vars);
  await figma.clientStorage.setAsync('TOKENS_JSON', JSON.stringify(tokens, null, 2));
  figma.ui.postMessage({ log: JSON.stringify(tokens, null, 2) });
  figma.notify('Tokens exported. Copy from panel, paste into spec/design-tokens.json');
};
