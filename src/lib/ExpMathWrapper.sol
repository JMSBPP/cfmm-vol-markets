// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ExpMath} from "bunni-v2/src/lib/ExpMath.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";

interface IExpMathWrapper {
    function expQ96(int256) external pure returns(int256);
    function lnQ96(int256) external pure returns(int256);
    function lnQ96RoundingUp(int256) external pure returns (int256);
    function getSqrtPriceAtTickWad(int256) external pure returns (uint160);
    function lnWad(int256) external pure returns(int256);

}
contract ExpMathWrapper {
    function expQ96(int256 _in) external pure returns(int256 out){
	out = ExpMath.expQ96(_in);
    }
    
    function lnQ96(int256 _in) external pure returns(int256 out) {
	out = ExpMath.lnQ96(_in);
    }
    function lnQ96RoundingUp(int256 _in) external pure returns (int256 out) {
	out = ExpMath.lnQ96RoundingUp(_in);
    }
    
    function getSqrtPriceAtTickWad(int256 _in) external pure returns (uint160 out){
	out = ExpMath.getSqrtPriceAtTickWad(_in);
    }

    function lnWad(int256 _in) external pure returns(int256 out) {
	out = FixedPointMathLib.lnWad(_in);
    }
}
