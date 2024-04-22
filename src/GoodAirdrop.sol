// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract GooldAirdrop {
    address public immutable token;
    uint256 public transfers;

    error InvalidLengths();

    constructor(address _token) {
        token = _token;
    }

    function airdropGood(address[] calldata recipients, uint256[] calldata amounts, uint256 totalAmount) public {
        if (recipients.length != amounts.length) revert InvalidLengths();

        IERC20(token).transferFrom(msg.sender, address(this), totalAmount);

        for (uint256 i; i < recipients.length;) {
            IERC20(token).transfer(recipients[i], amounts[i]);
            unchecked {
                ++i;
            }
        }

        unchecked {
            transfers += recipients.length;
        }
    }
}
