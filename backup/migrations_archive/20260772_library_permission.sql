-- Nouveau module RBAC « bibliotheque » : un membre du staff avec l'action
-- « ajouter » peut soumettre un livre/annale/support au catalogue partagé
-- (reste en attente de modération plateforme avant publication universelle).
insert into permission_catalog (key, label, order_num)
values ('bibliotheque', 'Bibliothèque', 14)
on conflict (key) do nothing;

insert into sub_permission_catalog (permission_key, key, label, order_num)
values ('bibliotheque', 'ajouter', 'Ajouter au catalogue', 1)
on conflict (permission_key, key) do nothing;
