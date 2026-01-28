Parfait, un mode décentralisé total. Chaque navigateur est autonome, peut exporter/importer des données, et synchroniser manuellement avec d'autres via fichiers JSON ou QR codes.## 🔄 MODE AUTONOME — Protocole de secours

### Principe

**Chaque navigateur = une instance autonome.** Pas de serveur nécessaire. Synchronisation manuelle via fichiers.

### Méthodes de sync P2P

| Méthode | Usage |
|---------|-------|
| **📁 Fichier JSON** | Export complet, partage par email/cloud/clé USB |
| **📋 Copier/Coller** | Via n'importe quel chat (Signal, WhatsApp, Telegram, email) |
| **🔗 URL** | Héberge ton JSON quelque part (GitHub Gist, Pastebin, ton site) |
| **📱 QR Code** | Scan entre appareils (pour cellules individuelles) |

### Workflow fédération

```
┌─────────────┐         ┌─────────────┐         ┌─────────────┐
│  Instance A │         │  Instance B │         │  Instance C │
│  (Alice)    │         │  (Bob)      │         │  (Carla)    │
└──────┬──────┘         └──────┬──────┘         └──────┬──────┘
       │                       │                       │
       │ ── Export JSON ──────▶│                       │
       │                       │ ── Export JSON ──────▶│
       │◀── Import + Merge ────│                       │
       │                       │◀── Import + Merge ────│
       │                       │                       │
       ▼                       ▼                       ▼
   Données                 Données                 Données
   fusionnées             fusionnées              fusionnées
```

### Fonctionnalités

**Export**
- `📦 Tout exporter` → backup complet
- `🏠 Cellules seules` → partage léger
- `📱 QR Code` → une cellule à la fois
- `📋 Copier` → texte JSON brut

**Import**
- Glisser-déposer fichier
- Coller texte JSON
- Charger depuis URL
- **Fusionner** (garde tout) ou **Remplacer** (écrase)

**Fédération**
- Cellules importées marquées `FÉDÉRÉ`
- Suivi des sources (qui a donné quoi)
- Suppression par source possible

### Structure des données

```json
{
  "version": "1.0",
  "instanceId": "C1234abc",
  "exportedAt": "2026-01-28T...",
  "cellules": [...],
  "ateliers": [...],
  "federatedSources": [
    { "id": "Cxyz", "name": "Alice", "importedAt": "...", "celluleCount": 5 }
  ]
}
```

### Cas d'usage

1. **Réunion sans internet** : chacun travaille localement, export/import après
2. **Multi-assos** : chaque asso a son instance, sync mensuelle
3. **Backup** : export régulier vers cloud perso
4. **Migration** : passer du mode autonome au mode Supabase en important les données

### Grille FWB complète incluse

- ~3000 nœuds Bruxelles + Wallonie
- Fonctionne 100% offline après premier chargement
