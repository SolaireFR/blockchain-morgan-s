## Partie théorique par Morgan SECRETIN

### Q1 — Fondamentaux. Pourquoi l'exécution d'un smart contract est-elle déterministe et répliquée sur tous les nœuds ? En quoi cela explique-t-il qu'un contrat ne puisse pas, par lui-même, connaître une donnée du monde réel (taux de change, météo, hasard) ?
Chaque nœud du réseau doit exécuter la transaction et obtenir exactement le même résultat pour valider le bloc. Si le contrat appelait une API externe, les nœuds obtiendraient des résultats différents (car le prix ou la météo change), ce qui briserait le consensus de la blockchain.

### Q2 — Cryptographie. Lorsqu'un spectateur achète un billet, sa transaction est signée. Expliquez brièvement le rôle de la signature et de la clé privée, et comment le réseau vérifie qui est l'émetteur sans connaître la clé privée.
La clé privée sert à signer mathématiquement la transaction pour prouver l'accord de l'utilisateur sans jamais la dévoiler. Les nœuds utilisent ensuite la clé publique de l'émetteur pour vérifier que la signature correspond bien au message envoyé.

### Q3 — Tokens. Pourquoi le billet de ce sujet relève-t-il d'un standard de tokens uniques plutôt que d'un standard de tokens interchangeables ? Donnez un cas d'usage où le second serait pertinent à la place.
Chaque billet correspond à une place précise et possède son propre historique de prix d'achat, ce qui le rend unique (standard ERC-721). Un standard interchangeable (ERC-20) serait en revanche idéal pour créer une monnaie stable (stablecoin) ou des jetons de fidélité pour la salle.

### Q4 — Sécurité. Citez deux vulnérabilités étudiées en formation qui menacent ce système, et expliquez précisément comment votre code s'en protège.
Le contrat est exposé à la réentrance lors des retraits, bloquée en utilisant le pattern "Checks-Effects-Interactions" (ou un modifier nonReentrant). Il est aussi exposé au vol de fonds, contré par le pattern "Pull over Push" qui isole les retraits de chaque utilisateur.

### Q5 — Gas. Donnez deux décisions concrètes que vous avez prises dans votre code pour réduire le coût en gas, et expliquez pourquoi elles fonctionnent.
J'ai utilisé des variables en mémoire (memory) pour stocker temporairement les données dans les boucles de lecture, ce qui évite des accès très coûteux au stockage réseau (storage). J'ai aussi défini les fonctions de consultation en external view pour que leur lecture soit totalement gratuite pour l'utilisateur.