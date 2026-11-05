// PanganPutar — Edge Function: payments-status (tahap 6)
// polling status pembayaran milik pembeli (JWT wajib).
// Deploy: supabase functions deploy payments-status
// Env: MIDTRANS_SERVER_KEY, MIDTRANS_IS_PRODUCTION,
//      SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY (otomatis), SUPABASE_ANON_KEY.
import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';

const midtransBase = (Deno.env.get('MIDTRANS_IS_PRODUCTION') || '').toLowerCase() === 'true'
  ? 'https://api.midtrans.com'
  : 'https://api.sandbox.midtrans.com';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type, apikey',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS },
  });
}

function admin(): SupabaseClient {
  return createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    { auth: { persistSession: false } },
  );
}

// Peta Midtrans → status payments (DB check constraint aman).
type Peta = Record<string, string>;
const PETA: Peta = {
  capture: 'dibayar',
  settlement: 'dibayar',
  pending: 'menunggu',
  deny: 'gagal',
  cancel: 'gagal',
  expire: 'kedaluwarsa',
  failure: 'gagal',
  refund: 'dikembalikan',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  if (req.method !== 'GET') return json({ error: 'metode tidak didukung' }, 405);

  const bearer = (req.headers.get('Authorization') || '').replace(/^Bearer /i, '');
  if (!bearer) return json({ error: 'wajib JWT pembeli' }, 401);

  const userClient = createClient(
    Deno.env.get('SUPABASE_URL')!,
    (req.headers.get('apikey') || bearer),
    { global: { headers: { Authorization: `Bearer ${bearer}` } } },
  );
  const { data: auth } = await userClient.auth.getUser(bearer);
  const uid = auth?.user?.id;
  if (!uid) return json({ error: 'JWT tidak sah' }, 401);

  const orderId = new URL(req.url).pathname.split('/').pop() || '';
  if (!orderId) return json({ error: 'orderId wajib di path' }, 400);

  const db = admin();
  const { data: order } = await db
    .from('orders')
    .select('id, recipient_id, total_rupiah, payment_status')
    .eq('id', orderId)
    .maybeSingle();
  if (!order || order.recipient_id !== uid) {
    return json({ error: 'pesanan tidak ditemukan / bukan milik Anda' }, 403);
  }

  const r = await fetch(`${midtransBase}/v2/${orderId}/status`, {
    headers: {
      Authorization: `Basic ${btoa(`${Deno.env.get('MIDTRANS_SERVER_KEY')!}:`)}`,
      Accept: 'application/json',
    },
  });
  if (!r.ok) {
    return json({ error: `Midtrans ${r.status}` }, 502);
  }
  const m = await r.json() as {
    transaction_status: string;
    gross_amount: string;
    payment_type: string;
    transaction_id: string;
    transaction_time: string;
  };

  return json({
    data: {
      status: PETA[m.transaction_status] || 'menunggu',
      grossAmount: Number(m.gross_amount),
      metode: m.payment_type,
      transactionId: m.transaction_id,
      paidAt: m.transaction_time,
    },
  });
});
