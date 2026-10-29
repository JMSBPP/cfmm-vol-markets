// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;
import {PlankTestBase} from "plank/PlankTestBase.sol";



enum WindowState {
	NotSet_1,
	NotSet_2,
	WindowNotInitialized,
	WindowInitialized
}
bytes32 constant WINDOW_SLOT = 0x11a586e09432f3d1b89c99706d3b8f3173c77004ae593e7e676b5ed839be424c;

interface IWindow {
    error InvalidWindowRuntimeConstructor();
    function set_window(uint256) external;
}

contract WindowTest is PlankTestBase {
	
    address main;
    WindowState windowState;
    
    function setUp() public {
	main = deployPlank("src/Main.plk");
	vm.makePersistent(main);
    }
    modifier whenSetWindowIsCalled() {
        _;
    }
    
    function test_WhenSetWindowIsCalled(uint256 nonZeroWindowLen) external whenSetWindowIsCalled {
    }

    function test_RevertWhen_WindowLenConstructorArgIsZero() external whenSetWindowIsCalled {
	uint256 zeroLen = 0;
	vm.expectRevert(IWindow.InvalidWindowRuntimeConstructor.selector);
	IWindow(main).set_window(zeroLen);
        // It should revert.
        //     Because windowLen is the greater than zero.
    }

    function test_WhenWindowLenConstructorArgIsGreaterThanZero(uint256 nonZeroWindowLen) external whenSetWindowIsCalled {
	main = deployPlank("src/Main.plk");
        vm.assume(nonZeroWindowLen >0);
	IWindow(main).set_window(nonZeroWindowLen);
	uint256 windowLenStored = uint256(vm.load(main, WINDOW_SLOT));
	assertEq(windowLenStored, nonZeroWindowLen);
	uint256 windowStateStored = uint256(vm.load(main, bytes32(uint256(WINDOW_SLOT) + 2)));
	assertEq(uint256(WindowState.WindowNotInitialized),windowStateStored);
    }
}

