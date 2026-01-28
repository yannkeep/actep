# CELLULES CITOYENNES — Architecture Plateforme

## Vision

Plateforme de maillage territorial citoyen pour l'éducation populaire et l'intelligence collective.
Chaque citoyen·ne peut créer une cellule de veille (territoriale et/ou thématique), recruter des participant·e·s, et déclencher des ateliers asynchrones de 14 jours + 48h de débrief live.

## Principes

1. **Inclusif** — Toute la Fédération Wallonie-Bruxelles couverte
2. **Décentralisé** — Chaque cellule est autonome
3. **Scalable** — De 1 à 100 000 utilisateurs sans changer l'infra
4. **Reproductible** — N'importe quelle association peut déployer sa propre instance
5. **Interopérable** — Export/import des données, webhooks, API ouverte

---

## Stack Technique

### Backend : Supabase (PostgreSQL + Auth + Realtime)
- **Pourquoi** : Gratuit jusqu'à 50k utilisateurs, PostgreSQL avec PostGIS, auth intégrée, temps réel
- **Coût** : 0€ pour commencer, ~25€/mois si > 50k users

### Frontend : HTML/CSS/JS + Supabase Client
- **Pourquoi** : Léger, pas de build, déployable partout (GitHub Pages, Netlify, n'importe quel serveur)
- **Framework** : Vanilla JS ou Alpine.js pour la réactivité

### Cartographie : Leaflet + turf.js
- **Pourquoi** : Open source, léger, fonctionne offline

### Déploiement : 
- Netlify/Vercel (frontend gratuit)
- Supabase (backend gratuit)
- Domaine : ~12€/an

---

## Modèle de données

```
┌─────────────────────────────────────────────────────────────────┐
│                           USERS                                  │
├─────────────────────────────────────────────────────────────────┤
│ id (uuid, PK)                                                   │
│ email                                                           │
│ pseudo                                                          │
│ avatar_url                                                      │
│ bio                                                             │
│ created_at                                                      │
│ organization_id (FK, nullable) → ORGANIZATIONS                  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ 1:N
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                         CELLULES                                 │
├─────────────────────────────────────────────────────────────────┤
│ id (uuid, PK)                                                   │
│ creator_id (FK) → USERS                                         │
│ title                                                           │
│ description                                                     │
│ theme (enum: mobilite, environnement, social, numerique,        │
│        culture, economie, democratie, education, sante, autre)  │
│ location (PostGIS POINT)                                        │
│ territory (PostGIS POLYGON) ← périmètre d'influence             │
│ radius_km (float)                                               │
│ status (enum: draft, recruiting, active, completed, archived)   │
│ min_participants (int, default 5)                               │
│ max_participants (int, default 9)                               │
│ created_at                                                      │
│ updated_at                                                      │
│ trace_url (lien publication)                                    │
│ tags (text[])                                                   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ 1:N
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                       PARTICIPANTS                               │
├─────────────────────────────────────────────────────────────────┤
│ id (uuid, PK)                                                   │
│ cellule_id (FK) → CELLULES                                      │
│ user_id (FK) → USERS                                            │
│ role (enum: creator, member, observer)                          │
│ joined_at                                                       │
│ status (enum: active, left, removed)                            │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ N:1
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                         ATELIERS                                 │
├─────────────────────────────────────────────────────────────────┤
│ id (uuid, PK)                                                   │
│ cellule_id (FK) → CELLULES                                      │
│ title                                                           │
│ description                                                     │
│ type (enum: async, live, hybrid)                                │
│ status (enum: planned, async_phase, live_phase, completed)      │
│ async_start (timestamp)                                         │
│ async_end (timestamp) ← +14 jours                               │
│ live_start (timestamp)                                          │
│ live_end (timestamp) ← +48h                                     │
│ platform_urls (jsonb) ← liens vers les plateformes utilisées    │
│ outcomes (jsonb) ← résultats, décisions, actions                │
│ created_at                                                      │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ 1:N
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                       CONTRIBUTIONS                              │
├─────────────────────────────────────────────────────────────────┤
│ id (uuid, PK)                                                   │
│ atelier_id (FK) → ATELIERS                                      │
│ user_id (FK) → USERS                                            │
│ type (enum: idea, comment, vote, resource, synthesis)           │
│ content (text)                                                  │
│ metadata (jsonb)                                                │
│ created_at                                                      │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                         MATCHES                                  │
├─────────────────────────────────────────────────────────────────┤
│ id (uuid, PK)                                                   │
│ cellule_a_id (FK) → CELLULES                                    │
│ cellule_b_id (FK) → CELLULES                                    │
│ score (float) ← calculé selon distance + thèmes communs         │
│ status (enum: suggested, accepted, rejected, meeting_planned)   │
│ created_at                                                      │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                      ORGANIZATIONS                               │
├─────────────────────────────────────────────────────────────────┤
│ id (uuid, PK)                                                   │
│ name                                                            │
│ type (enum: asbl, collectif, commune, autre)                    │
│ description                                                     │
│ website                                                         │
│ logo_url                                                        │
│ verified (boolean)                                              │
│ created_at                                                      │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                        GRID_NODES                                │
├─────────────────────────────────────────────────────────────────┤
│ id (text, PK) ← ex: "WAL-50.450/4.850"                          │
│ location (PostGIS POINT)                                        │
│ zone (enum: bxl, wal)                                           │
│ commune (text, nullable)                                        │
│ province (text, nullable)                                       │
└─────────────────────────────────────────────────────────────────┘
```

---

## Fonctionnalités

### 1. Authentification
- Email/password
- Magic link (sans mot de passe)
- OAuth (Google, Facebook) optionnel

### 2. Carte interactive
- Tous les nœuds de la grille FWB
- Cellules actives avec leur périmètre d'influence
- Filtres : thème, status, distance
- Clic sur nœud → créer cellule
- Clic sur cellule → voir détails / rejoindre

### 3. Gestion des cellules
- **Créer** : choisir nœud(s), définir périmètre, thème, description
- **Tracer périmètre** : outil de dessin sur la carte (polygone)
- **Recruter** : partager lien, QR code
- **Gérer** : inviter, retirer participants

### 4. Workflow atelier
```
[Cellule ready (≥5 participants)]
         │
         ▼
[Lancer atelier async]
         │
         ▼
[14 jours de contributions]
  - Toutes plateformes (Slack, Discord, WhatsApp, email...)
  - Liens agrégés dans la plateforme
  - Votes, idées, ressources
         │
         ▼
[Phase live 48h]
  - Visio (lien externe)
  - Synthèse collaborative
  - Décisions
         │
         ▼
[Clôture]
  - Outcomes enregistrés
  - Export PDF
  - Archivage
```

### 5. Matching territorial
- Algorithme calcule score entre cellules :
  - Distance géographique (bonus si <10km)
  - Thèmes communs
  - Taille similaire
- Suggestions de rencontres inter-cellules
- Planification d'ateliers conjoints

### 6. Dashboard organisation
- Vue sur toutes les cellules de l'orga
- Stats : participants, ateliers, outcomes
- Export données

### 7. API publique
- REST + WebSocket (temps réel Supabase)
- Webhooks pour intégrations externes
- Export JSON/CSV

---

## Sécurité & Permissions (Row Level Security)

```sql
-- Users can only see their own data
-- Cellules are public (read) but only creator can edit
-- Participants can see their cellule's details
-- Organizations can see all their members' cellules
```

---

## Déploiement

### Étape 1 : Créer compte Supabase
1. https://supabase.com → Sign up (gratuit)
2. New project → choisir région (eu-central-1 pour Belgique)
3. Copier URL et anon key

### Étape 2 : Créer la base de données
1. SQL Editor → coller le schema (fichier fourni)
2. Activer PostGIS extension
3. Configurer Row Level Security

### Étape 3 : Déployer le frontend
1. Modifier config.js avec URL et key Supabase
2. Push sur GitHub
3. Connecter à Netlify/Vercel → auto-deploy

### Étape 4 : Configurer auth
1. Supabase dashboard → Authentication
2. Activer email confirmations
3. Configurer redirect URLs

---

## Fichiers fournis

1. `schema.sql` — Script de création de la base de données
2. `index.html` — Application frontend complète
3. `README.md` — Instructions de déploiement

---

## Évolutions futures

- [ ] App mobile (PWA)
- [ ] Notifications push
- [ ] Intégration calendrier (iCal)
- [ ] Bot Telegram/Discord
- [ ] Fédération entre instances (ActivityPub?)
- [ ] Blockchain pour certifier les outcomes

---

## Licence

GNU Affero GPL v3 — Libre, open source, copyleft fort.
Toute modification doit rester libre.
