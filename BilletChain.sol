// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// A1 : 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4
// A2 : 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2
// A3 : 0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db
// Taux Feed : 0xf8e81D47203A594245E36C48e151709F0C19fBe8

// Interface pour l'Oracle de prix (ex: Chainlink)
interface IPriceFeed {
    function getLatestPrice() external view returns (uint256);
}

contract BilletChain {
    // --- VARIABLES DE CONFIGURATION ---
    address public organizer;      // L'organisateur (Owner) de l'événement
    uint256 public maxTickets;     // Nombre maximum de billets disponibles
    uint256 public totalSold;      // Compteur des ventes initiales
    uint256 public ticketPriceEUR; // Prix fixe du billet en Euros
    IPriceFeed public priceFeed;   // L'adresse de l'Oracle de change

    // Structure claire pour définir les propriétés d'un billet
    struct Ticket {
        address owner;             // Propriétaire actuel du billet
        uint256 initialPriceWei;   // Prix d'achat d'origine (sert de base pour le plafond de 110%)
        uint256 resalePriceWei;    // Prix fixé pour la revente (0 si pas sur le marché)
        bool isAvailableForSale;   // Statut de mise en vente sur le marché secondaire
    }

    // Stockage des données (Mappings)
    mapping(uint256 => Ticket) public tickets;           // Associe un ID unique à son billet
    mapping(address => uint256) public balancesToWithdraw; // Solde en attente de retrait (Pattern Pull)

    // Événements (Events) pour le suivi de l'activité
    event TicketPurchased(uint256 indexed ticketId, address indexed buyer, uint256 price);
    event TicketPutOnSale(uint256 indexed ticketId, uint256 resalePrice);
    event TicketResold(uint256 indexed ticketId, address indexed previousOwner, address indexed newOwner, uint256 price);

    constructor(uint256 _maxTickets, uint256 _ticketPriceEUR, address _oracleAddress) {
        organizer = msg.sender;
        maxTickets = _maxTickets;
        ticketPriceEUR = _ticketPriceEUR;
        priceFeed = IPriceFeed(_oracleAddress);
    }

    // =========================================================================
    // FONCTIONNALITÉ 1 : VENTE INITIALE (Guichet principal)
    // =========================================================================
    function buyTicket() external payable {
        // Vérifie la disponibilité des places
        require(totalSold < maxTickets, "Evenement complet");

        // Calcul dynamique du prix avec l'oracle (ex: conversion Euro -> Wei)
        uint256 rateWeiPerEuro = priceFeed.getLatestPrice();
        uint256 exactPriceWei = ticketPriceEUR * rateWeiPerEuro;

        // Sécurité : Exige le montant exact au Wei près
        require(msg.value == exactPriceWei, "Montant paye incorrect");

        // Attribution du numéro de billet unique
        uint256 ticketId = totalSold + 1;

        // Création et enregistrement du billet
        tickets[ticketId] = Ticket({
            owner: msg.sender,
            initialPriceWei: msg.value,
            resalePriceWei: 0,
            isAvailableForSale: false
        });

        totalSold++;
        
        // Stockage des fonds de la vente pour l'organisateur (Pattern Pull)
        balancesToWithdraw[organizer] += msg.value;

        emit TicketPurchased(ticketId, msg.sender, msg.value);
    }

    // =========================================================================
    // FONCTIONNALITÉ 2 : REVENTE (Marché secondaire entre particuliers)
    // =========================================================================
    
    // Étape A : Le détenteur met sa place en vente
    function putTicketOnSale(uint256 _ticketId, uint256 _resalePriceWei) external {
        Ticket storage ticket = tickets[_ticketId];
        
        // Sécurité : Seul le vrai possesseur du billet peut initier la vente
        require(ticket.owner == msg.sender, "Vous n'etes pas le proprietaire");
        
        // Règle du TP : Limite anti-spéculation bloquée à 110% maximum du prix de départ
        uint256 maxPriceAllowed = (ticket.initialPriceWei * 110) / 100;
        require(_resalePriceWei <= maxPriceAllowed, "Prix au-dessus du plafond de 110%");

        // Enregistrement des conditions du marché
        ticket.resalePriceWei = _resalePriceWei;
        ticket.isAvailableForSale = true;

        emit TicketPutOnSale(_ticketId, _resalePriceWei);
    }

    // Étape B : Un second acheteur valide le rachat de l'occasion
    function buySecondHandTicket(uint256 _ticketId) external payable {
        Ticket storage ticket = tickets[_ticketId];

        // Vérifications de validité de la vente
        require(ticket.isAvailableForSale, "Ce billet n'est pas en vente");
        require(msg.value == ticket.resalePriceWei, "Montant paye incorrect");

        address formalOwner = ticket.owner;

        // Mutation de la propriété du billet
        ticket.owner = msg.sender;
        ticket.isAvailableForSale = false;
        ticket.resalePriceWei = 0; // Sortie automatique du marché secondaire

        // Transfert comptable des fonds vers le vendeur (Pattern Pull)
        balancesToWithdraw[formalOwner] += msg.value;

        emit TicketResold(_ticketId, formalOwner, msg.sender, msg.value);
    }

    // =========================================================================
    // FONCTIONNALITÉ 3 : ENCAISSEMENT DES REVENUS (Sécurisation des retraits)
    // =========================================================================
    function claimEarnings() external {
        uint256 revenue = balancesToWithdraw[msg.sender];
        
        // Bloque les appels inutiles si le solde est nul
        require(revenue > 0, "Aucun fonds a retirer");

        // Protection Anti-Réentrance (Règle CEI : Modification du solde AVANT l'envoi)
        balancesToWithdraw[msg.sender] = 0;

        // Transfert physique de l'argent natif de la blockchain
        (bool executionSuccess, ) = payable(msg.sender).call{value: revenue}("");
        require(executionSuccess, "Echec du transfert");
    }

    // =========================================================================
    // FONCTIONNALITÉ 4 : CONSULTATION ÉCONOME (Optimisation du Gas)
    // =========================================================================
    // La mention "external view" garantit la gratuité totale de lecture hors transaction
    function getOnSaleCount(uint256[] calldata _ticketIds) external view returns (uint256) {
        uint256 totalOnSale = 0;
        
        // Boucle hautement optimisée en lecture pure directe (Calldata / Storage)
        for (uint256 i = 0; i < _ticketIds.length; i++) {
            if (tickets[_ticketIds[i]].isAvailableForSale) {
                totalOnSale++;
            }
        }
        return totalOnSale;
    }
}

// Vive les commentaires
