// ─────────────────────────────────────────────────────────────────────────────
// Edge Function : platform-create-school
//
// Création d'une NOUVELLE école depuis la console super-admin. Différent de
// `create-account` : celle-là exige que l'appelant appartienne déjà à une
// école (elle rattache le nouveau compte à SON school_id) — ici il n'y a pas
// encore d'école du tout. La clé `service_role` ne vit QUE dans cette
// fonction (jamais dans l'app).
//
// Étapes :
//  1. Vérifier que l'appelant est un admin PLATEFORME (table `platform_admins`
//     via `is_platform_admin`), pas juste admin d'une école.
//  2. Créer la ligne `schools` (service_role, bypass RLS).
//  3. Créer le compte auth du responsable via l'API admin (email confirmé,
//     PAS de `auth.signUp` — ça remplacerait la session du super-admin côté
//     client par celle du nouveau compte). Le trigger `handle_new_user` crée
//     la ligne `public.users` à partir des métadonnées (role: admin,
//     school_id: <nouvelle école>).
//  4. Créer la ligne `subscriptions` (essai 30 jours, offre choisie dans le
//     formulaire) — PAS de trigger DB fiable à ce jour pour ça (un commentaire
//     dans school_registration_screen.dart en mentionne un, introuvable dans
//     les migrations archivées ; on ne s'y fie donc pas et on l'écrit nous-mêmes).
//
// Rollback best-effort si une étape échoue après la création de l'école.
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

function slugify(name: string, suffix: string): string {
  const base = name.trim().toLowerCase().replace(/[^a-z0-9]+/g, "-");
  return `${base}-${suffix}`;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    const url = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;

    // 1. Identifier l'appelant et vérifier qu'il est admin PLATEFORME.
    const authHeader = req.headers.get("Authorization") ?? "";
    const caller = createClient(url, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user } } = await caller.auth.getUser();
    if (!user) return json({ error: "Non authentifié." }, 401);

    const admin = createClient(url, serviceKey);
    const { data: isAdmin } = await admin.rpc("is_platform_admin", {
      p_auth_uid: user.id,
    });
    if (!isAdmin) {
      return json({ error: "Réservé aux administrateurs de la plateforme." }, 403);
    }

    // 2. Lire la requête.
    const body = await req.json().catch(() => ({}));
    const name = (body.name ?? "").toString().trim();
    const city = (body.city ?? "").toString().trim();
    const country = (body.country ?? "").toString().trim();
    const types = Array.isArray(body.types) && body.types.length > 0
      ? body.types.map((t: unknown) => String(t))
      : ["primaire"];
    const planCode = ["simple", "pro", "max"].includes(body.planCode)
      ? body.planCode
      : "simple";
    const directorName = (body.directorName ?? "").toString().trim();
    const email = (body.email ?? "").toString().trim();
    const phone = (body.phone ?? "").toString().trim();
    const password = (body.password ?? "").toString();

    if (!name || !city || !directorName || !email || password.length < 6) {
      return json({ error: "Champs manquants ou mot de passe trop court (min. 6)." }, 400);
    }

    // 3. Créer l'école.
    const schoolId = crypto.randomUUID();
    const slug = slugify(name, schoolId.slice(0, 8));
    const { error: schoolErr } = await admin.from("schools").insert({
      id: schoolId,
      name,
      code: slug,
      slug,
      country: country || "CG",
      city,
      contact_email: email || null,
      contact_phone: phone || null,
      is_active: true,
      plan_type: "free", // legacy, non utilisé (cf. subscriptions.plan_code)
      db_mode: "central",
      metadata: { types },
    });
    if (schoolErr) return json({ error: schoolErr.message }, 400);

    // 4. Créer le compte du responsable (admin de l'école).
    const { data: created, error: userErr } = await admin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { full_name: directorName, role: "admin", school_id: schoolId },
    });
    if (userErr) {
      await admin.from("schools").delete().eq("id", schoolId);
      return json({ error: userErr.message }, 400);
    }

    // 5. Créer l'abonnement d'essai (30 jours, offre choisie).
    const now = new Date();
    const trialEnd = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000);
    const { error: subErr } = await admin.from("subscriptions").upsert({
      school_id: schoolId,
      plan_code: planCode,
      status: "trial",
      trial_end: trialEnd.toISOString(),
      current_period_start: now.toISOString(),
      current_period_end: trialEnd.toISOString(),
    }, { onConflict: "school_id" });
    if (subErr) {
      // Best-effort seulement : l'école et le compte admin existent déjà et
      // restent utilisables même sans ligne d'abonnement (le repository
      // retombe sur un essai par défaut côté lecture).
      console.error("subscriptions upsert failed:", subErr.message);
    }

    return json({ ok: true, schoolId, authUid: created.user.id });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
