-- AUDIT SGBR - PHASE 2 : TESTS SQL
USE clinique_sgbr;

-- C01 Cohérence des montants
SELECT id_facture, numero_facture, montant_total, montant_assurance, montant_patient
FROM FACTURE
WHERE ROUND(montant_total,2) <> ROUND(montant_assurance + montant_patient,2);

-- C02 Rapprochement facture/paiement
SELECT f.id_facture, f.numero_facture, f.statut, f.montant_patient,
       COALESCE(SUM(p.montant),0) AS montant_paye,
       ROUND(f.montant_patient-COALESCE(SUM(p.montant),0),2) AS solde
FROM FACTURE f LEFT JOIN PAIEMENT p ON p.id_facture=f.id_facture
GROUP BY f.id_facture,f.numero_facture,f.statut,f.montant_patient
ORDER BY solde DESC;

-- C03 Incohérence du statut
WITH x AS (
 SELECT f.id_facture,f.numero_facture,f.statut AS statut_enregistre,f.montant_patient,
        COALESCE(SUM(p.montant),0) montant_paye
 FROM FACTURE f LEFT JOIN PAIEMENT p ON p.id_facture=f.id_facture
 GROUP BY f.id_facture,f.numero_facture,f.statut,f.montant_patient
)
SELECT *, CASE
 WHEN montant_paye=0 THEN 'IMPAYEE'
 WHEN montant_paye<montant_patient THEN 'PARTIELLEMENT_PAYEE'
 WHEN montant_paye=montant_patient THEN 'PAYEE'
 ELSE 'SURPAYEE' END statut_calcule
FROM x
WHERE statut_enregistre <> CASE
 WHEN montant_paye=0 THEN 'IMPAYEE'
 WHEN montant_paye<montant_patient THEN 'PARTIELLEMENT_PAYEE'
 WHEN montant_paye=montant_patient THEN 'PAYEE'
 ELSE 'SURPAYEE' END;

-- C04 PAYEE mais non soldée
WITH x AS (
 SELECT f.id_facture,f.numero_facture,f.montant_patient,COALESCE(SUM(p.montant),0) montant_paye
 FROM FACTURE f LEFT JOIN PAIEMENT p ON p.id_facture=f.id_facture
 WHERE f.statut='PAYEE'
 GROUP BY f.id_facture,f.numero_facture,f.montant_patient
)
SELECT *, ROUND(montant_patient-montant_paye,2) reste
FROM x WHERE montant_paye < montant_patient;

-- C05 IMPAYEE avec paiement
WITH x AS (
 SELECT f.id_facture,f.numero_facture,f.montant_patient,COALESCE(SUM(p.montant),0) montant_paye
 FROM FACTURE f LEFT JOIN PAIEMENT p ON p.id_facture=f.id_facture
 WHERE f.statut='IMPAYEE'
 GROUP BY f.id_facture,f.numero_facture,f.montant_patient
)
SELECT * FROM x WHERE montant_paye > 0;

-- C06 Surpaiements
WITH x AS (
 SELECT f.id_facture,f.numero_facture,f.montant_patient,COALESCE(SUM(p.montant),0) montant_paye
 FROM FACTURE f LEFT JOIN PAIEMENT p ON p.id_facture=f.id_facture
 GROUP BY f.id_facture,f.numero_facture,f.montant_patient
)
SELECT *, ROUND(montant_paye-montant_patient,2) surpaiement
FROM x WHERE montant_paye > montant_patient;

-- C07 Examens réalisés sans résultat
SELECT e.id_examen,e.type_examen,e.libelle,e.date_prescription
FROM EXAMEN_MEDICAL e
LEFT JOIN RESULTAT_EXAMEN r ON r.id_examen=e.id_examen
WHERE e.statut='REALISE' AND r.id_resultat IS NULL;

-- C08 Taux d'absence
SELECT COUNT(*) total_rdv,
       SUM(CASE WHEN statut='ABSENT' THEN 1 ELSE 0 END) absents,
       ROUND(100*SUM(CASE WHEN statut='ABSENT' THEN 1 ELSE 0 END)/COUNT(*),2) taux_absence
FROM RENDEZ_VOUS;