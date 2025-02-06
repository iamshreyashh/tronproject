// contracts/GLDToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ShreyCoin is ERC20 {
    constructor() ERC20("Gold", "GLD") {
        _mint(msg.sender, 10000);
    }
}