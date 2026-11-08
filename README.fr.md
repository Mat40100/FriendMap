# FriendMap

*[English version](README.md)*

Un addon World of Warcraft (client WoW Forever) qui affiche vos amis sur la carte du monde et la minicarte — icône de classe et petite plaque de nom aux couleurs de la classe — dès qu'ils utilisent aussi FriendMap et partagent un groupe avec vous.

## Fonctionnalités

- **Vos amis sur la carte** : icône de classe + nom sur la carte du monde, icônes plus petites sur la minicarte. Survolez pour voir niveau/classe/groupe, clic droit pour chuchoter.
- **Groupes** : créez-en autant que vous voulez. Chaque groupe utilise son propre canal d'addon caché et protégé par mot de passe pour savoir qui est en ligne ; les données sont envoyées en messages d'addon invisibles à ces membres uniquement (WoW Forever bloque les messages d'addon dans les canaux personnalisés). Rien n'apparaît dans votre chat.
- **Rejoindre facilement** : invitations en jeu (fenêtre Accepter/Refuser), liens cliquables dans le chat, ou un code de partage à coller n'importe où (Discord…).
- **JcJ sauvage** : un halo rouge pulsant entoure l'icône d'un ami pendant un combat JcJ en extérieur et, si l'option est activée, vos groupes sont prévenus quand vous en commencez un.
- **Pings sur la carte** : Alt+clic sur la carte du monde pour faire apparaître un marqueur pulsant chez tous vos amis (avec un son).
- **À l'aide !** : un bouton (ou automatiquement sous 30 % de vie en combat JcJ) alerte votre groupe, montre où vous êtes et oriente leur flèche vers vous.
- **Traces** : de petits points montrent le trajet de chaque ami sur les 3 dernières minutes.
- **Distance et flèche** : les infobulles indiquent « 340 yd NE » (en mètres environ ×0,9) ; cliquez sur un ami sur la carte pour afficher une flèche qui pointe vers lui.
- **Statut** : un court statut (« farm », « cherche groupe »…) affiché sous votre nom sur la carte.
- **Fil des victimes et classement** : votre groupe voit vos victimes en JcJ sauvage ; classement hebdomadaire dans la fenêtre et avec `/fm top`. Les victimes sont synchronisées entre tous les membres du groupe, même celles faites pendant que vous ou le tueur étiez hors ligne (tout ami qui les a vues les transmet).
- **Niveaux et hauts faits** : annoncés au groupe, avec un halo doré sur l'icône.
- **Point de ralliement** : Alt+Maj+clic sur la carte (ou **Rally here**) pour poser un drapeau vers lequel tout le monde reçoit une flèche.
- **Carte de chaleur** : sur la carte du continent, chaque zone affiche combien d'amis s'y trouvent.

## Installation

1. Téléchargez la dernière version : **[FriendMap sur la page Releases](https://github.com/Mat40100/FriendMap/releases/latest)** → `FriendMap-vX.Y.Z-forever.zip`.
2. Extrayez-le dans votre dossier AddOns :
   ```
   World of Warcraft/_forever_/Interface/AddOns/
   ```
3. Vérifiez que le dossier s'appelle `FriendMap` (c'est déjà le cas dans le ZIP de la release ; un « Code → Download ZIP » du dépôt s'extrait en `FriendMap-main` et doit être renommé). Vous devez obtenir :
   ```
   Interface/AddOns/FriendMap/FriendMap.toc
   ```
4. Lancez le jeu (ou tapez `/reload`) et vérifiez que **FriendMap** est activé dans la liste des AddOns de l'écran de sélection des personnages.

Pour mettre à jour, remplacez le dossier par la nouvelle version (vos groupes sont conservés, ils sont enregistrés dans `WTF/`).

## Menu de la carte

Dès qu'une carte est ouverte — carte du monde de Blizzard, **carte de MelloUI** ou un autre addon de carte — un petit bouton FriendMap apparaît en haut à droite (Maj+glisser pour le déplacer). Son menu permet de :

- **Ping / Rally at my map pin** : Ctrl+clic n'importe où sur la carte pour poser le repère standard du jeu, puis choisissez une de ces options. Fonctionne sur toutes les cartes qui utilisent le repère du jeu (Blizzard, MelloUI…).
- Ping / ralliement à votre position, retirer le point de ralliement, appeler à l'aide.
- Activer/désactiver les traces, la carte de chaleur, les icônes de la minicarte ; arrêter la flèche ; ouvrir la fenêtre FriendMap.

Sur la carte de Blizzard, vous pouvez aussi faire Alt+clic (ping) et Alt+Maj+clic (ralliement) directement.

## Mises à jour

FriendMap vous prévient quand une nouvelle version existe : dès qu'un membre de vos groupes utilise une version plus récente, vous recevez un message dans le chat (et le titre de la fenêtre l'indique). Tapez `/fm update` pour copier le lien de téléchargement, puis réinstallez comme ci-dessus. `/fm version` affiche votre version.

## Barre rapide

Une petite barre d'icônes déplaçable pour les actions en un clic : **À l'aide !**, ping à votre position, ralliement ici, retirer le point de ralliement, suivre l'ami le plus proche, arrêter la flèche, activer/désactiver le partage de position, activer/désactiver les annonces JcJ, classement JcJ, réglages (engrenage). Par défaut elle affiche **À l'aide !**, **Ralliement ici**, le **classement JcJ** et les **Réglages**.

Choisissez les icônes affichées avec le bouton **Quick bar** dans `/fm`, avec `/fm bar`, ou par clic droit sur la barre. Vous pouvez aussi la masquer, la verrouiller, la mettre à la verticale et changer la taille des icônes. Glissez la barre pour la déplacer.

## Premiers pas

1. Tapez `/fm` pour ouvrir la fenêtre.
2. Une personne clique sur **Create group** et lui donne un nom.
3. Faites venir vos amis, comme vous préférez :
   - **Invite** : entrez le nom de leur personnage (ou ciblez-les avant). Ils reçoivent une fenêtre Accepter/Refuser.
   - **Link** : insère un lien cliquable `[FriendMap: Nom]` dans le chat ; un clic dessus propose de rejoindre le groupe.
   - **Code** : affiche un code `FMAP:...` à copier (Ctrl+C) et à envoyer où vous voulez. Vos amis rejoignent avec **Join with code** ou `/fm join FMAP:...`.
4. Ouvrez la carte du monde : vos amis y apparaissent.


## Commandes

| Commande | Description |
|---|---|
| `/fm` | Ouvrir / fermer la fenêtre |
| `/fm create <nom>` | Créer un groupe |
| `/fm join FMAP:...` | Rejoindre un groupe avec un code de partage |
| `/fm invite <joueur> [groupe]` | Inviter un joueur |
| `/fm link [groupe]` | Publier un lien cliquable dans le chat |
| `/fm code [groupe]` | Afficher le code de partage à copier |
| `/fm leave [groupe]` | Quitter un groupe |
| `/fm list` | Lister vos groupes et les membres en ligne |
| `/fm share` | Activer/désactiver le partage de votre position |
| `/fm minimap` | Activer/désactiver les icônes sur la minicarte |
| `/fm pvp` | Activer/désactiver l'annonce de vos combats JcJ sauvage |
| `/fm pvpalert` | Activer/désactiver l'alerte à l'écran pour les combats de vos amis |
| `/fm ping [texte]` | Ping à votre position |
| `/fm help` | Appeler votre groupe à l'aide |
| `/fm autohelp` | Activer/désactiver l'appel à l'aide automatique |
| `/fm status <texte>` | Définir votre statut (vide = effacer) |
| `/fm track <nom>` | Flèche vers un ami (sans nom = arrêter) |
| `/fm rally` / `/fm rally clear` | Poser / retirer le point de ralliement à votre position |
| `/fm rally off` / `/fm rally on` | Masquer / afficher la flèche vers le point de ralliement |
| `/fm top` | Ouvrir le classement hebdomadaire JcJ sauvage |
| `/fm members` | Afficher tous les joueurs vus dans chacun de vos groupes (en ligne / vu il y a) |
| `/fm trails` / `/fm heatmap` | Activer/désactiver les traces / la carte de chaleur |

`[groupe]` peut être le numéro du groupe dans `/fm list`, ou son nom. Sans lui, le premier groupe est utilisé.

## Limites

- Tout le monde doit avoir FriendMap installé.
- Les canaux et invitations ne fonctionnent qu'entre joueurs du même royaume ou de royaumes connectés.
- La position ne peut généralement pas être lue en donjon/raid : les amis qui s'y trouvent n'apparaissent qu'à leur sortie.
- La détection JcJ et le fil des victimes se basent sur votre cible, focalisation, survol et barres d'info (le journal de combat est inaccessible aux addons sur ce client) : activer les barres d'info des ennemis aide. Une victime est comptée quand un ennemi que vous combattiez meurt, même si quelqu'un d'autre a porté le dernier coup.
- Le lien cliquable peut être supprimé par le serveur ; le code de partage fonctionne toujours.

## Crédits

Utilise [HereBeDragons](https://github.com/Nevcairiel/HereBeDragons), LibStub et CallbackHandler.
