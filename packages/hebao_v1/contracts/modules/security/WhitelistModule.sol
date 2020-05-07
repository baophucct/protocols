/*

  Copyright 2017 Loopring Project Ltd (Loopring Foundation).

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
*/
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "../../lib/MathUint.sol";
import "./GuardianUtils.sol";

import "../../iface/Wallet.sol";

import "./SecurityModule.sol";


/// @title WhitelistModule
/// @dev Manages whitelisted addresses.
contract WhitelistModule is SecurityModule
{
    using MathUint for uint;

    uint public delayPeriod;

    constructor(
        Controller  _controller,
        uint        _delayPeriod
        )
        public
        SecurityModule(_controller)
    {
        require(_delayPeriod > 0, "INVALID_DELAY");
        delayPeriod = _delayPeriod;
    }

    function addToWhitelist(
        address wallet,
        address addr
        )
        external
        nonReentrant
        onlyWhenWalletUnlocked(wallet)
        onlyFromMetaTxOrWalletOwner(wallet)
    {
        controller.whitelistStore().addToWhitelist(wallet, addr, now.add(delayPeriod));
    }

    function addToWhitelistImmediately(
        address            wallet,
        address            addr
        )
        external
        nonReentrant
        onlyWhenWalletUnlocked(wallet)
        onlyFromMetaTx
    {
        controller.whitelistStore().addToWhitelist(wallet, addr, now);
    }

    function removeFromWhitelist(
        address wallet,
        address addr
        )
        external
        nonReentrant
        onlyWhenWalletUnlocked(wallet)
        onlyFromMetaTxOrWalletOwner(wallet)
    {
        controller.whitelistStore().removeFromWhitelist(wallet, addr);
    }

    function getWhitelist(address wallet)
        public
        view
        returns (
            address[] memory addresses,
            uint[]    memory effectiveTimes
        )
    {
        return controller.whitelistStore().whitelist(wallet);
    }

    function isWhitelisted(
        address wallet,
        address addr)
        public
        view
        returns (
            bool isWhitelistedAndEffective,
            uint effectiveTime
        )
    {
        return controller.whitelistStore().isWhitelisted(wallet, addr);
    }

    function boundMethods()
        public
        pure
        override
        returns (bytes4[] memory methods)
    {
        methods = new bytes4[](2);
        methods[0] = this.getWhitelist.selector;
        methods[1] = this.isWhitelisted.selector;
    }

    function extractMetaTxSigners(
        address   wallet,
        bytes4    method,
        bytes     memory /*data*/,
        address[] memory txSigners
        )
        internal
        view
        override
        returns (address[] memory signers)
    {
        if (method == this.addToWhitelist.selector ||
            method == this.removeFromWhitelist.selector) {
            signers = new address[](1);
            signers[0] = Wallet(wallet).owner();
        } else if(method == this.addToWhitelistImmediately.selector) {
            return txSigners;
        } else {
            revert("INVALID_METHOD");
        }
    }

    function areMetaTxSignersAuthorized(
        address   wallet,
        bytes     memory data,
        address[] memory signers
        )
        internal
        view
        override
        returns (bool)
    {
        // First validate that all signers are the owner or a guardian
        if (!super.areMetaTxSignersAuthorized(wallet, data, signers)) {
            return false;
        }

        bytes4 method = extractMethod(data);
        if(method == this.addToWhitelistImmediately.selector) {
            GuardianUtils.requireMajority(
                controller.securityStore(),
                wallet,
                signers,
                GuardianUtils.SigRequirement.OwnerRequired
            );
        }
    }
}
