export type Ok<T> = { ok: true; data: T; meta?: Record<string, any> };
export type Err = { ok: false; error: { code: string; message: string } };

export const ok = <T>(data: T, meta?: Record<string, any>): Ok<T> => ({ ok: true, data, meta });

export const fail = (code: string, message: string, status = 400) => {
  const e = new Error(message) as Error & { status: number; code: string };
  e.status = status;
  (e as any).code = code;
  throw e;
};

export const toRes = (res: any, body: Ok<any> | Err, status = 200) => {
  if ('ok' in body && body.ok === false) {
    return res.status((body as any).status ?? status).json(body);
  }
  return res.status(status).json(body);
};
