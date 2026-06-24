// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/BilletChain.sol";

contract PriceFeedMock {
    function getLatestPrice() external pure returns (uint256) {
        return 10; // 1 Euro = 10 Wei
    }
}

contract BilletChainTest is Test {
    BilletChain public billetterie;
    PriceFeedMock public mockOracle;

    address public organisateur = address(0xA1);
    address public acheteur1 = address(0xA2);
    address public acheteur2 = address(0xA3);

    function setUp() public {
        vm.startPrank(organisateur);
        mockOracle = new PriceFeedMock();
        // 2 tickets max pour tester facilement la saturation, 20 Euros le ticket (200 Wei)
        billetterie = new BilletChain(2, 20, address(mockOracle));
        vm.stopPrank();
    }

    // 1. Test Achat Réussi
    function testAchatInitialReussi() public {
        vm.deal(acheteur1, 1000 wei);
        vm.prank(acheteur1);
        billetterie.buyTicket{value: 200 wei}();

        (address possesseur,,,) = billetterie.tickets(1);
        assertEq(possesseur, acheteur1);
    }

    // 2. Test Échec si montant incorrect
    function testAchatInitialEchecMontant() public {
        vm.deal(acheteur1, 1000 wei);
        vm.prank(acheteur1);
        vm.expectRevert("Montant paye incorrect");
        billetterie.buyTicket{value: 150 wei}();
    }

    // 3. Test Échec si événement complet (Exigence 2.1)
    function testEchecSiComplet() public {
        vm.deal(acheteur1, 1000 wei);
        vm.deal(acheteur2, 1000 wei);

        // On achète les 2 seuls tickets disponibles
        vm.prank(acheteur1);
        billetterie.buyTicket{value: 200 wei}();
        vm.prank(acheteur2);
        billetterie.buyTicket{value: 200 wei}();

        // Le 3ème achat doit crash
        address acheteur3 = address(0xA4);
        vm.deal(acheteur3, 1000 wei);
        vm.prank(acheteur3);
        vm.expectRevert("Evenement complet");
        billetterie.buyTicket{value: 200 wei}();
    }

    // 4. Test Cycle de Revente valide
    function testReventeEtRachat() public {
        vm.deal(acheteur1, 1000 wei);
        vm.prank(acheteur1);
        billetterie.buyTicket{value: 200 wei}();

        vm.prank(acheteur1);
        billetterie.putTicketOnSale(1, 210 wei); // 210 <= 220 (110%)

        vm.deal(acheteur2, 1000 wei);
        vm.prank(acheteur2);
        billetterie.buySecondHandTicket{value: 210 wei}(1);

        (address possesseur,,,) = billetterie.tickets(1);
        assertEq(possesseur, acheteur2);
    }

    // 5. Test Échec si dépassement du plafond des 110% (Exigence 2.2)
    function testEchecSiDepassementPlafond() public {
        vm.deal(acheteur1, 1000 wei);
        vm.prank(acheteur1);
        billetterie.buyTicket{value: 200 wei}();

        vm.prank(acheteur1);
        vm.expectRevert("Prix au-dessus du plafond de 110%");
        billetterie.putTicketOnSale(1, 221 wei); // 221 Wei c'est > 110% (220 Wei max)
    }

    // 6. Test Retrait des fonds (Exigence 2.3)
    function testRetraitFonds() public {
        vm.deal(acheteur1, 1000 wei);
        vm.prank(acheteur1);
        billetterie.buyTicket{value: 200 wei}();

        // L'organisateur (A1) doit avoir 200 Wei de solde dans le contrat
        uint256 soldeAvant = organisateur.balance;
        
        vm.prank(organisateur);
        billetterie.claimEarnings();

        assertEq(organisateur.balance, soldeAvant + 200 wei);
    }
}