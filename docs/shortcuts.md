# Shortcuts (import + personnalisation)

Ce repo utilise **iPhone Shortcuts** comme interface et **SSH** comme transport pour déclencher l’exécution sur le Mac.

Principe: **aucun secret sur l’iPhone**. Les secrets restent sur le Mac (`config/env.sh`).

---

## Importer un shortcut (.shortcut) (général)

Les `.shortcut` peuvent être stockés dans `shortcuts/` et importés dans l’app Raccourcis.

### Sur macOS (app Raccourcis)

1. Ouvrir **Raccourcis**
2. Trouver le shortcut à exporter
3. **Partager** → **Exporter le raccourci…**
4. Enregistrer le fichier `.shortcut`
5. L’ouvrir/importer sur l’iPhone (AirDrop, Fichiers, iCloud Drive…)

### Sur iOS (app Raccourcis)

1. Recevoir le fichier `.shortcut` (AirDrop / Fichiers / iCloud Drive)
2. Toucher le fichier → il s’ouvre dans **Raccourcis**
3. Toucher **Ajouter le raccourci**
4. Valider les demandes d’autorisations éventuelles

---

## Personnalisation générique (tous les shortcuts): “Exécuter le script avec SSH”

La personnalisation côté iPhone est **toujours** dans le bloc **“Exécuter le script avec SSH”**.

À renseigner:

- **Même réseau**: l’iPhone et le Mac doivent être sur le même réseau (LAN/Wi‑Fi), sauf si tu as un VPN/port‑forwarding.
- **IP du Mac**: renseigner l’IP atteignable depuis l’iPhone.
- **User macOS**: l’utilisateur SSH du Mac.
- **Authentification**: configurer l’auth SSH.

Setup actuel (tel que tu l’utilises):

- **Host**: IP du Mac (ex: `192.168.1.23`)
- **User**: user macOS (ex: `cyril`)
- **Authentication**: **Password**
- **Password**: mot de passe du user macOS

> Note: même si les secrets API restent sur le Mac, ce bloc SSH contient des infos d’accès (IP, user, mot de passe si auth “mot de passe”).

---

## Catalogue

Chaque shortcut exporté doit avoir **sa section dédiée** ci-dessous: quoi il fait et quoi personnaliser.

---

## Shortcut: “ClickUp task” (`@shortcuts/ClickUp task.shortcut`)

### Objectif

Créer une tâche ClickUp à partir d’un titre saisi sur l’iPhone.

### Spécifique à ce shortcut: ClickUp List ID (`CLICKUP_LIST_ID`)

Ce shortcut appelle le script `clickup/create_task.sh`, qui dépend de `config/env.sh`.

À personnaliser:

- `CLICKUP_LIST_ID`: **l’ID de la liste ClickUp cible** (spécifique à ton espace)

Requis aussi:

- `CLICKUP_TOKEN`: token ClickUp (reste sur le Mac)

Étapes:

1. Copier le fichier d’exemple si besoin:

```bash
cp config/env.example.sh config/env.sh
```

2. Mettre à jour `config/env.sh`:
   - `CLICKUP_TOKEN="..."`
   - `CLICKUP_LIST_ID="..."` ← ton List ID ClickUp

Tout le reste (import et configuration SSH) est **générique** et documenté plus haut.

