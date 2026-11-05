// PanganPutar — Edge Function: push-reminder (tahap 6)
// Kirim PFC push (FCM) untuk notifikasi yang belum dibaca.
//
// Deploy + pasang jadwal (external timer, bukan klien):
//   supabase functions deploy push-reminder
//   supabase secrets set FCM_SERVER_KEY=...   ← legacy FCM server key
//
// JUJUR & TERBATAS:
// - Proyek Firebase milik pemilik app (google-services.json) — tanpa itu
//   function ini berhenti dengan jawaban jelas "belum dikonfigurasi".
// - FCM_SERVER_KEY memakai legacy API yang sudah diumumkan penghentian
//   oleh Google; migrasi FCM HTTP v1 (OAuth service account) menyusul
//   bila akun Firebase siap. Tidak ada tumpang-tindih token.
// - Status "sudah dibaca" tidak diubah dari sini (tidak ada kolom
//   pushed_at): kirim ulang mungkin terjadi bila function dipanggil dua
//   kali dalam jendela yang sama — lembut, daripada notifikasi hilang.
//   Migrasi FCM HTTP v1 akan menambah kolom pushed_at.
// - Baca notifikasi unread (kind pengingat/pushable), kirim per token
//   perangkat di fcm_tokens, dan tandai read_at untuk yang terkirim.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS },
  });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  if (req.method !== 'POST' && req.method !== 'GET') {
    return json({ error: 'metode tidak didukung' }, 405);
  }

  const key = Deno.env.get('FCM_SERVER_KEY') ?? '';
  if (key.trim() === '') {
    return json({
      error: 'push belum dikonfigurasi (FCM_SERVER_KEY belum di-set di secrets)',
      kirim: 0,
    });
  }

  const db = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    { auth: { persistSession: false } },
  );

  // Notifikasi yang layak didengar: belum dibaca, bukan info kosong.
  const { data: notif } = await db
    .from('notifications')
    .select('id, profile_id, kind, title, body')
    .is('read_at', null)
    .in('kind', ['pesanan_dikonfirmasi', 'siap_diambil', 'pengingat_ambil'])
    .order('created_at', { ascending: false })
    .limit(200);
  if (!notif || notif.length === 0) return json({ kirim: 0 });

  const terkirim = await (async () => {
    let n = 0;
    for (const t of notif) {
      const { data: tokens } = await db
        .from('fcm_tokens')
        .select('token')
        .eq('profile_id', t.profile_id);
      if (!tokens || tokens.length === 0) continue;

      const suksesSemua = await Promise.all(
        tokens.map(async (tk: { token: string }) => {
          const r = await fetch('https://fcm.googleapis.com/fcm/send', {
            method: 'POST',
            headers: {
              Authorization: `key=${key}`,
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({
              to: tk.token,
              notification: { title: t.title, body: t.body },
              data: { kind: t.kind, notification_id: t.id },
            }),
          });
          return r.ok;
        }),
      );
      if (suksesSemua.some(Boolean)) {
        await db
          .from('notifications')
          .update({ read_at: new Date().toISOString() })
          .eq('id', t.id);
        n += 1;
      }
    }
    return n;
  })();

  return json({ kirim: terkirim });
});
