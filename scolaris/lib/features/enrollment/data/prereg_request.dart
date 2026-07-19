// Pré-inscriptions — la source de vérité est la table Supabase
// `enrollment_requests` (cf. 20260714_public_enrollment.sql). Ce fichier ne
// garde qu'un alias léger côté UI ; les vraies lectures/écritures passent par
// `SupabaseDbSource.getEnrollmentRequests` / `acceptEnrollmentRequest` /
// `rejectEnrollmentRequest`.

import '../../../data/sources/remote/supabase_db_source.dart';

typedef PreRegRequest = SbEnrollmentRequest;

enum PreRegStatus { pending, accepted, rejected }

PreRegStatus preRegStatusOf(PreRegRequest r) => switch (r.status) {
      'accepted' => PreRegStatus.accepted,
      'rejected' => PreRegStatus.rejected,
      _ => PreRegStatus.pending,
    };
