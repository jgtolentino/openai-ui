import React from 'react';
import type { GetServerSideProps } from 'next';
import wireframes from '../../spec/wireframes.json';
import { RenderScreen } from '../../components/__fixtures__/Renderer';

export const getServerSideProps: GetServerSideProps = async (ctx) => {
  const id = ctx.params?.id as string;
  const screen = (wireframes as any).screens.find((s:any)=>s.id===id) || null;
  return { props: { screen } };
};

export default function FixturePage({screen}:{screen:any}){
  if(!screen){ return <main style={{padding:24}}>Unknown screen id</main> }
  return <main style={{padding:24}}><RenderScreen screen={screen}/></main>;
}
