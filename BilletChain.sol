// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

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
}