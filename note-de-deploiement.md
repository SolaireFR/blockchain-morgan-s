## NOTE DE DÉPLOIEMENT — BILLETCHAIN
### 1. Le choix du réseau de test

Je choisis le réseau Remix VM avec l'emplacement "Osaka".
Pourquoi ? C'est un réseau fonctionnel et definie par defaut dans Remix IDE.

### 1. Les valeurs pour la création (le Constructeur)
Quand je clique sur Deploy dans Remix, je remplis les 3 cases comme ça :

- _maxTickets : 20 (pour bloquer la vente à 20 places max).
- _ticketPriceEUR : 20 (pour fixer le prix de base à 20 €).
- _oracleAddress : 0xf8e81D47203A594245E36C48e151709F0C19fBe8 (l'adresse magique de l'oracle).

### 3. Où trouver l'adresse de l'oracle de taux ?

Je vais sur Remix IDE. J'accède à la page de deploiement et je regarde le deploiement de PriceFeedMock. 

Dans la section "Deployed Contracts", il y a les infos du contrat.
![Feed](address-feed.png)

Je copie l'adresse en dessous du nom du contrat et je l'utilise dans **_oracleAddress**.
