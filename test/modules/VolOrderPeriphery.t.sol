// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PlankTestBase} from "../PlankTestBase.sol";
import {PairVerifyCompliantERC20} from "../mocks/PairVerifyCompliantERC20.sol";
import {IExttload} from "univ4-core/interfaces/IExttload.sol";
import {TokenId, TokenIdLibrary} from "panoptic-v2-core/contracts/types/TokenId.sol";


interface IVolOrderPeriphery {
    function setPair(address asset, address collateral) external;
    function setVolOrder(uint88,uint16,uint24) external returns(uint256);
}

bytes32 constant PANOPTIC_TOKEN_ID_TSLOT =
    0x8bb2fa2ebf7505391db26e2cc233582857d9705b338a5a23a6d357b2d51b0c7a;

contract VolOrderPeripheryTest is PlankTestBase {
    IVolOrderPeriphery internal volOrderPeriphery;
    IExttload internal exttload;

    
    function setUp() public {
        volOrderPeriphery = IVolOrderPeriphery(deployPlank("src/modules/VolOrderPeriphery.plk"));
        exttload = IExttload(address(volOrderPeriphery));
    }

    function test__unit__setPairStoresPanopticTokenId() public {
        PairVerifyCompliantERC20 asset = new PairVerifyCompliantERC20();
        PairVerifyCompliantERC20 collateral = new PairVerifyCompliantERC20();

        address a = address(asset);
        address b = address(collateral);
	vm.startPrank(address(this));
        volOrderPeriphery.setPair(a, b);
	
	TokenId panopticTokenId = TokenId.wrap(
					       volOrderPeriphery.setVolOrder(22_000, 32_768, 4_000)
	);
	TokenIdLibrary.validate(panopticTokenId);	
vm.stopPrank();
    }
}
