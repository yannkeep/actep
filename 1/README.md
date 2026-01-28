# 🔥 CELLULES CITOYENNES

Plateforme de maillage territorial pour l'éducation populaire et l'intelligence collective citoyenne en Fédération Wallonie-Bruxelles.

## 🎯 Concept

- Chaque citoyen·ne peut **créer une cellule de veille** (territoriale et/ou thématique)
- **Recruter 5-9 participants** via publication et partage
- **Lancer un atelier distanciel asynchrone** de 14 jours
- **48h de débrief live** pour synthétiser et décider
- **Matching territorial** : connexion avec cellules voisines pour ateliers présentiels

## 📁 Fichiers

```
cellules-citoyennes/
├── ARCHITECTURE.md    # Documentation technique complète
├── schema.sql         # Script PostgreSQL + PostGIS
├── index.html         # Application frontend
└── README.md          # Ce fichier
```

## 🚀 Déploiement rapide (Mode local)

**Sans serveur, juste le navigateur :**

1. Ouvrez `index.html` dans votre navigateur
2. Les données sont stockées dans localStorage
3. Parfait pour tester et démontrer

## 🏗️ Déploiement production (Supabase)

### Étape 1 : Créer un projet Supabase

1. Allez sur https://supabase.com
2. Créez un compte gratuit
3. "New Project" → choisissez un nom et région (eu-central-1 recommandé)
4. Notez l'URL et la clé anon (Settings → API)

### Étape 2 : Configurer la base de données

1. Dans Supabase Dashboard → SQL Editor
2. Collez le contenu de `schema.sql`
3. Exécutez (Run)
4. Vérifiez que les tables sont créées dans Table Editor

### Étape 3 : Activer PostGIS

```sql
CREATE EXTENSION IF NOT EXISTS postgis;
```

### Étape 4 : Configurer l'application

Dans `index.html`, modifiez les lignes :

```javascript
const CONFIG = {
    SUPABASE_URL: 'https://VOTRE_PROJECT.supabase.co',
    SUPABASE_ANON_KEY: 'VOTRE_ANON_KEY',
    LOCAL_MODE: false, // Passez à false
};
```

### Étape 5 : Déployer le frontend

**Option A : Netlify (gratuit)**
1. Créez un repo GitHub avec les fichiers
2. Connectez Netlify à votre repo
3. Deploy automatique

**Option B : Vercel (gratuit)**
1. `npm i -g vercel`
2. `vercel` dans le dossier

**Option C : GitHub Pages (gratuit)**
1. Push sur GitHub
2. Settings → Pages → Deploy from branch

### Étape 6 : Configurer l'authentification

1. Supabase Dashboard → Authentication → Settings
2. Activez "Email" provider
3. Configurez les URLs de redirection (votre domaine)
4. Optionnel : activez Google/Facebook OAuth

## 🔧 Configuration avancée

### Row Level Security

Le fichier `schema.sql` inclut des policies RLS. Vérifiez qu'elles sont actives :

```sql
-- Dans SQL Editor
SELECT tablename, policyname FROM pg_policies WHERE schemaname = 'public';
```

### Realtime

Pour les mises à jour en temps réel :

```sql
ALTER PUBLICATION supabase_realtime ADD TABLE cellules;
ALTER PUBLICATION supabase_realtime ADD TABLE participants;
```

### Backup

Supabase fait des backups automatiques. Pour exporter manuellement :

```bash
pg_dump -h db.xxx.supabase.co -U postgres -d postgres > backup.sql
```

## 📊 Fonctionnalités

### Carte interactive
- ~8000 nœuds couvrant toute la FWB
- Bruxelles : grille dense (600m)
- Wallonie : grille complète (2.5km) + villes densifiées (800m)

### Cellules
- Création sur n'importe quel nœud
- Périmètre d'influence personnalisable (dessin polygone)
- 10 thématiques prédéfinies
- Lien trace pour publication externe

### Participants
- Rejoindre via lien direct ou recherche
- Rôles : créateur, membre, observateur
- Quorum configurable (défaut 5-9)

### Ateliers
- Phase async : 14 jours de contributions
- Phase live : 48h de débrief
- Multi-plateforme (liens externes)
- Outcomes enregistrés

### Matching
- Algorithme de score (distance + thèmes + taille)
- Suggestions automatiques
- Planification de rencontres

### Graph
- Visualisation du maillage
- Liens entre cellules actives à <15km
- Taille des nœuds = participants

## 🔒 Sécurité

- Authentification email/password ou magic link
- Row Level Security sur toutes les tables
- Pas de données sensibles exposées
- HTTPS obligatoire en production

## 📈 Scalabilité

- Supabase gratuit : jusqu'à 50k utilisateurs
- PostgreSQL : millions de lignes
- Frontend statique : CDN mondial

## 🤝 Contribution

Projet open source sous licence AGPL-3.0.

1. Fork le repo
2. Créez une branche feature
3. Pull request

## 📝 Licence

GNU Affero General Public License v3.0

Libre d'utiliser, modifier, distribuer.
Toute modification doit rester libre et open source.

## 🙏 Crédits

- Leaflet.js : cartographie
- Supabase : backend
- PostGIS : géospatial
- Orbitron/Share Tech Mono : typographie

---

**Fait avec ❤️ pour l'éducation populaire et l'intelligence collective citoyenne.**
