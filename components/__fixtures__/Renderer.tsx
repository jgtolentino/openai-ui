import React from 'react';
type Bounds={x:number;y:number;w:number;h:number};
const box=(b:Bounds, extra:React.CSSProperties={}):React.CSSProperties=>({position:'absolute' as const, left:b.x, top:b.y, width:b.w, height:b.h, ...extra});
export function RenderComponent(c:any){
  const b:Bounds=c.bounds;
  const common={border:'1px solid var(--color-ui-border)', borderRadius:'var(--radius-md)'};
  if(c.type==='Heading'){ return <div style={{...box(b)}}><h1 style={{fontSize:'var(--fs-xl)',margin:0}}>{c.props?.text}</h1></div>; }
  if(c.type==='StatTile'){ return <div style={{...box(b,common),padding:16,background:'var(--color-ui-bg-elev)'}}><div style={{opacity:.7,fontSize:'var(--fs-sm)'}}>{c.props?.label}</div><div style={{fontSize:'var(--fs-2xl)'}}>{c.props?.value}</div></div>; }
  if(c.type==='Card'){ return <div style={{...box(b,common),padding:16,background:'var(--color-ui-bg-elev)'}}><div style={{opacity:.8}}>{c.props?.title||'Card'}</div></div>; }
  if(c.type==='Chart'){ return <div style={{...box(b,common),background:'var(--color-ui-bg-elev)',display:'grid',placeItems:'center'}}><div style={{opacity:.6}}>Chart: {c.props?.type}</div></div>; }
  if(c.type==='DataTable'){ return <div style={{...box(b,common),background:'var(--color-ui-bg-elev)',overflow:'hidden'}}>
    <table style={{width:'100%',borderCollapse:'collapse',fontSize:'var(--fs-sm)'}}>
      <thead><tr>{(c.props?.columns||[]).map((h:string)=><th key={h} style={{textAlign:'left',padding:8,borderBottom:'1px solid var(--color-ui-border)'}}>{h}</th>)}</tr></thead>
      <tbody><tr><td style={{padding:8,opacity:.6}} colSpan={(c.props?.columns||[]).length}>placeholder</td></tr></tbody>
    </table></div>;
  }
  if(c.type==='Button'){ return <button style={{...box(b,{display:'grid',placeItems:'center',background:'var(--color-brand-primary)',color:'#fff',borderRadius:'var(--radius-md)'})}}>{c.props?.label||'Button'}</button>; }
  return <div style={box(b,{border:'1px dashed #555'})}></div>;
}
export function RenderScreen({screen}:{screen:any}){
  const w = screen.platform==='mobile' ? 375 : 1280;
  const h = 900;
  return <div style={{position:'relative' as const, width:w, height:h, margin:'24px auto'}} aria-label={screen.id}>
    {screen.components.map((c:any,i:number)=><RenderComponent key={i} {...c}/>)}
  </div>;
}
