// ─────────────────────────────────────────────────────────────────────────────
// Edge Function : delete-account
//
// Supprime un compte côté SERVEUR via l'API admin. Symétrique de
// `create-account` : la clé `service_role` ne vit QUE dans cette fonction.
//
// `public.users` (la fiche métier) et `auth.users` (l'identité de connexion)
// sont découplés dans ce schéma — reliés par `users.auth_uid`, pas par le même
// id (une fiche peut exister sans login, mode "link" de `create-account`).
// Un simple `delete from users` ne retire donc PAS l'accès de connexion :
// cette fonction supprime les deux, dans le bon ordre :
//   1. `public.users` via le RPC `delete_user_account` (transporte le motif
//      jusqu'au trigger d'audit des notes, cf. migration 20260749) ;
//   2. `auth.users` via l'API admin, si la fiche avait un `auth_uid`.
//
// Sécurité : l'appelant doit être admin/staff de l'école ; la fiche ciblée
// doit appartenir à SON école (jamais vérifié côté client).
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
    const targetId = (body.userId ?? "").toString();
    const reason = body.reason ? body.reason.toString() : null;
    if (!targetId) return json({ error: "userId manquant." }, 400);

    // La fiche doit appartenir à l'école de l'appelant.
    const { data: target } = await admin
      .from("users")
      .select("id, auth_uid, school_id")
      .eq("id", targetId)
      .maybeSingle();
    if (!target || target.school_id !== schoolId) {
      return json({ error: "Fiche introuvable dans votre école." }, 404);
    }

    // 4. Supprimer la fiche via le RPC (motif transporté jusqu'à l'audit ;
    //    la policy `users_delete` s'applique normalement, security invoker).
    const { error: rpcError } = await caller.rpc("delete_user_account", {
      p_id: targetId,
      p_reason: reason,
    });
    if (rpcError) return json({ error: rpcError.message }, 400);

    // 5. Supprimer le compte de connexion, s'il en avait un.
    if (target.auth_uid) {
      const { error: authError } = await admin.auth.admin.deleteUser(
        target.auth_uid,
      );
      if (authError) {
        // La fiche est déjà partie ; on le signale mais ce n'est pas fatal
        // pour l'appelant — un compte auth orphelin peut être nettoyé après.
        return json({
          ok: true,
          warning: `Fiche supprimée, mais le compte de connexion n'a pas pu l'être : ${authError.message}`,
        });
      }
    }

    return json({ ok: true });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
