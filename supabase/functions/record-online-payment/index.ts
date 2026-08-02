// ─────────────────────────────────────────────────────────────────────────────
// Edge Function : record-online-payment
//
// Enregistre un paiement en ligne (Mobile Money) DEMANDÉ par une famille
// (élève ou parent). Les familles sont en LECTURE SEULE sur `payments`
// (policy `family_readonly_ins`) — un parent ne doit pas pouvoir se déclarer
// « payé » depuis l'app. L'écriture passe donc par ici, côté serveur, avec la
// clé `service_role` (jamais dans l'app), APRÈS vérification que l'appelant a
// bien le droit de payer pour cet élève.
//
// Sécurité (vérifiée ici) :
//   • L'appelant est authentifié.
//   • Il est SOIT l'élève lui-même, SOIT un parent lié via `parent_student`.
//   • Le montant ne dépasse pas le reste dû de la facture.
//
// ⚠️ PAS D'AGRÉGATEUR BRANCHÉ : la famille envoie l'argent elle-même (USSD,
// hors app) vers le numéro marchand Mobile Money de l'école, puis saisit ici
// la référence reçue par SMS. Le versement est inséré en statut `pending` —
// il NE compte PAS dans le solde de la facture tant que l'admin ne l'a pas
// vérifié sur son propre relevé marchand et confirmé (cf. confirmPayment
// dans supabase_db_source.dart). Le jour où un agrégateur est branché, cette
// fonction peut confirmer directement sur webhook au lieu de laisser `pending`.
// L'offre « simple » ne propose pas le paiement en ligne : la famille règle à la
// caisse et l'admin encaisse (côté staff, l'écriture directe est autorisée).
// ─────────────────────────────────────────────────────────────────────────────
import { createClient } from "jsr:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    const url = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;

    // 1. Identifier l'appelant via son JWT.
    const authHeader = req.headers.get("Authorization") ?? "";
    const caller = createClient(url, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user } } = await caller.auth.getUser();
    if (!user) return json({ error: "Non authentifié." }, 401);

    // 2. Lire la requête.
    const body = await req.json().catch(() => ({}));
    const invoiceId = (body.invoiceId ?? "").toString();
    const amount = Number(body.amount ?? 0);
    const method = (body.method ?? "mobile_money").toString();
    const reference = (body.reference ?? "").toString();
    if (!invoiceId) return json({ error: "invoiceId manquant." }, 400);
    if (!(amount > 0)) return json({ error: "Montant invalide." }, 400);

    const admin = createClient(url, serviceKey);

    // 3. Retrouver l'appelant dans public.users (son id = parent_id éventuel).
    const { data: profile } = await admin
      .from("users")
      .select("id")
      .eq("auth_uid", user.id)
      .maybeSingle();
    if (!profile) return json({ error: "Profil introuvable." }, 403);
    const callerId = profile.id as string;

    // 4. La facture + l'élève concerné.
    const { data: invoice } = await admin
      .from("invoices")
      .select("id, student_id, amount, status")
      .eq("id", invoiceId)
      .maybeSingle();
    if (!invoice) return json({ error: "Facture introuvable." }, 404);
    const studentId = invoice.student_id as string;

    // 5. Autorisation : l'appelant est l'élève, ou un parent lié à l'élève.
    let allowed = callerId === studentId;
    if (!allowed) {
      const { data: link } = await admin
        .from("parent_student")
        .select("parent_id")
        .eq("parent_id", callerId)
        .eq("student_id", studentId)
        .maybeSingle();
      allowed = !!link;
    }
    if (!allowed) {
      return json({ error: "Vous ne pouvez pas payer pour cet élève." }, 403);
    }

    // 6. Le versement ne peut pas dépasser le reste dû.
    const due = Number(invoice.amount ?? 0);
    const { data: existing } = await admin
      .from("payments")
      .select("amount")
      .eq("invoice_id", invoiceId);
    const alreadyPaid = (existing ?? []).reduce(
      (a: number, p: { amount: number | null }) => a + Number(p.amount ?? 0),
      0,
    );
    const balance = due - alreadyPaid;
    if (amount > balance + 0.01) {
      return json({
        error: `Dépasse le reste dû (${balance}).`,
      }, 400);
    }

    if (!reference) {
      return json({ error: "Référence de transaction manquante." }, 400);
    }

    // 7. Enregistrer le versement en ATTENTE de vérification (service_role →
    // bypass RLS famille) — pas d'agrégateur pour confirmer automatiquement.
    const { error: insErr } = await admin.from("payments").insert({
      invoice_id: invoiceId,
      student_id: studentId,
      amount,
      payment_date: new Date().toISOString().split("T")[0],
      payment_method: method,
      reference,
      status: "pending",
    });
    if (insErr) return json({ error: insErr.message }, 400);

    // Le solde de la facture ne bouge pas tant que l'admin n'a pas confirmé.
    return json({ ok: true, pending: true, balance });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
