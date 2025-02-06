// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "interfaces/Ownable.sol";

interface IReserveAuditor {
    function verifyReserves(uint256 amount) external view returns (bool);
}

contract NuChainStablecoinTron is ERC20, ERC20Burnable, AccessControl, Ownable {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    uint256 public constant INITIAL_MINT = 1_000_000 * 10**18;

    IReserveAuditor public reserveAuditor;
    address public treasuryWallet;
    uint256 public reserveRatio;
    uint256 public transactionFeePercentage;

    event TreasuryWalletUpdated(address indexed previousWallet, address indexed newWallet);
    event ReserveAuditorUpdated(address indexed previousAuditor, address indexed newAuditor);
    event TransactionFeeUpdated(uint256 previousFee, uint256 newFee);

    constructor(
    ) ERC20("NuChain Stablecoin", "USDN") {
        address _reserveAuditor = 0x01d8d7B2bA2227fE304F586Ac8d573a30DFdfAA6;
        address _treasuryWallet = 0x01d8d7B2bA2227fE304F586Ac8d573a30DFdfAA6;
        require(_reserveAuditor != address(0), "Invalid reserve auditor address");
        require(_treasuryWallet != address(0), "Invalid treasury wallet address");


        // Assign initial settings
        reserveAuditor = IReserveAuditor(_reserveAuditor);
        treasuryWallet = _treasuryWallet;
        reserveRatio = 1e18; // Default 1:1 reserve ratio
        transactionFeePercentage = 0; // Default no transaction fee

        // Mint initial supply to admin
        _mint(msg.sender, INITIAL_MINT);
    }

    // Function to update the treasury wallet
    function updateTreasuryWallet(address newWallet) external onlyOwner {
        require(newWallet != address(0), "Invalid treasury wallet address");
        emit TreasuryWalletUpdated(treasuryWallet, newWallet);
        treasuryWallet = newWallet;
    }

    // Function to update the reserve auditor
    function updateReserveAuditor(address newAuditor) external onlyOwner {
        require(newAuditor != address(0), "Invalid reserve auditor address");
        emit ReserveAuditorUpdated(address(reserveAuditor), newAuditor);
        reserveAuditor = IReserveAuditor(newAuditor);
    }

    // Function to update transaction fee percentage
    function updateTransactionFee(uint256 newFee) external onlyOwner {
        require(newFee <= 100, "Fee percentage cannot exceed 100%");
        emit TransactionFeeUpdated(transactionFeePercentage, newFee);
        transactionFeePercentage = newFee;
    }

    // Override _transfer to include transaction fee logic
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override {
        if (transactionFeePercentage > 0 && treasuryWallet != address(0)) {
            uint256 fee = (amount * transactionFeePercentage) / 100;
            uint256 amountAfterFee = amount - fee;

            super._transfer(sender, treasuryWallet, fee); // Transfer fee to treasury
            super._transfer(sender, recipient, amountAfterFee); // Transfer remaining amount to recipient
        } else {
            super._transfer(sender, recipient, amount);
        }
    }
}
