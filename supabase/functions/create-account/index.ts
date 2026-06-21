// ─────────────────────────────────────────────────────────────────────────────
// Edge Function : create-account  (Phase A2)
//
// Création de comptes côté SERVEUR via l'API admin. La clé `service_role` ne vit
// QUE dans cette fonction (jamais dans l'app). Deux modes :
//
//  • mode "create" : nouveau compte (prof / staff / élève avec login dès le
//    départ). On passe school_id+role dans les métadonnées → le trigger
//    `handle_new_user` crée la ligne `public.users`. Compte déjà confirmé
//    (email_confirm), donc connexion immédiate, sans email, tout domaine.
//
//  • mode "link" : donner un login à une FICHE existante (ex. élève). On crée le
//    compte auth SANS school_id (le trigger ne fait rien → pas de doublon) puis
//    on pose `auth_uid` sur la fiche existante. L'app/RLS résolvent l'utilisateur
//    par `users.auth_uid = auth.uid()`.
//
// Sécurité : l'appelant doit être admin/staff de l'école ; la nouvelle ligne est
// forcément rattachée à SON école (school_id pris du profil appelant, jamais du
// corps de requête).
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

    // 2. Vérifier son rôle + récupérer son école (service_role = bypass RLS).
    const admin = createClient(url, serviceKey);
    const { data: profile } = await admin
      .from("users")
      .select("role, school_id")
      .eq("auth_uid", user.id)
      .maybeSingle();

    if (!profile || !["admin", "staff_custom"].includes(profile.role)) {
      return json({ error: "Réservé à l'administration de l'école." }, 403);
    }
    const schoolId = profile.school_id as string;

    // 3. Lire la requête.
    const body = await req.json().catch(() => ({}));
    const mode = body.mode === "link" ? "link" : "create";
    const email = (body.email ?? "").toString().trim();
    const password = (body.password ?? "").toString();
    const fullName = (body.fullName ?? "").toString().trim();
    if (!email || password.length < 6) {
      return json({ error: "Email ou mot de passe invalide (min. 6)." }, 400);
    }

    if (mode === "link") {
      // Donner un login à une fiche existante.
      const linkUserId = (body.linkUserId ?? "").toString();
      if (!linkUserId) return json({ error: "linkUserId manquant." }, 400);

      // La fiche doit appartenir à l'école de l'appelant et ne pas déjà avoir un login.
      const { data: target } = await admin
        .from("users")
        .select("id, auth_uid, school_id")
        .eq("id", linkUserId)
        .maybeSingle();
      if (!target || target.school_id !== schoolId) {
        return json({ error: "Fiche introuvable dans votre école." }, 404);
      }
      if (target.auth_uid) {
        return json({ error: "Cette personne a déjà un accès." }, 409);
      }

      // Pas de school_id dans les métadonnées → le trigger NE crée PAS de ligne.
      const { data: created, error } = await admin.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: { full_name: fullName },
      });
      if (error) return json({ error: error.message }, 400);

      const newAuthId = created.user.id;
      const { error: upErr } = await admin
        .from("users")
        .update({ auth_uid: newAuthId, email })
        .eq("id", linkUserId)
        .eq("school_id", schoolId);
      if (upErr) {
        // rollback du compte auth si le lien échoue
        await admin.auth.admin.deleteUser(newAuthId);
        return json({ error: upErr.message }, 400);
      }
      return json({ ok: true, userId: linkUserId, authUid: newAuthId });
    }

    // mode "create" : nouveau compte ; le trigger crée la ligne public.users.
    const role = (body.role ?? "teacher").toString();
    const { data: created, error } = await admin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { full_name: fullName, role, school_id: schoolId },
    });
    if (error) return json({ error: error.message }, 400);
    return json({ ok: true, userId: created.user.id });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
