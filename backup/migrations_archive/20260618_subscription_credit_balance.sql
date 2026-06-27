-- Ajout du solde de crédit sur les abonnements.
-- Utilisé pour reporter le crédit prorata non consommé lors d'un changement d'offre
-- (ex : passage d'un plan annuel à mensuel où le crédit > prix du mois).
-- Le solde est déduit automatiquement à chaque renouvellement jusqu'à épuisement.

ALTER TABLE subscriptions
  ADD COLUMN IF NOT EXISTS credit_balance DECIMAL(12, 2) NOT NULL DEFAULT 0;
