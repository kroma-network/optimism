// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

// Testing
import "forge-std/Test.sol";

// Contracts
import { UnstructuredInitializable } from "src/universal/UnstructuredInitializable.sol";

/// @dev A simple contract that inherits UnstructuredInitializable for testing.
contract TestContract is UnstructuredInitializable {
    uint256 public value;

    function initialize(uint256 _value) external initializer {
        value = _value;
    }

    function initializeV2(uint256 _value) external reinitializer(2) {
        value = _value;
    }

    function version() external view returns (uint8) {
        return _getInitializedVersion();
    }

    /// @dev Expose internal _disableInitializers() for testing.
    function disable() external {
        _disableInitializers();
    }
}

/// @dev A contract to verify _INITIALIZING_SLOT state during initialization.
contract InitInspector is UnstructuredInitializable {
    address public callerDuringInit;
    bool public seenInitializing;

    function initialize() external initializer {
        callerDuringInit = msg.sender;
        seenInitializing = _isInitializing(); // should be true
    }

    function version() external view returns (uint8) {
        return _getInitializedVersion();
    }
}

contract UnstructuredInitializableTest is Test {
    TestContract internal testContract;

    // Expected slot values
    bytes32 internal constant EXPECTED_INITIALIZED_SLOT =
        0xb25dec660ce7a75ea4eb44c1b5224935800fab1a1f943d17d507a18ac7a572ed;
    bytes32 internal constant EXPECTED_INITIALIZING_SLOT =
        0xd16b04d7a8aa3daae4087064b34e44bdfbd8a7259d9f2873842472ff4fff712a;

    function setUp() public {
        testContract = new TestContract();
    }

    function test_initializer_setsValueOnce() public {
        testContract.initialize(100);
        assertEq(testContract.value(), 100);
        assertEq(testContract.version(), 1);
    }

    function test_initializer_revertsIfCalledTwice() public {
        testContract.initialize(100);

        vm.expectRevert("Initializable: already initialized");
        testContract.initialize(200);
    }

    function test_reinitializer_allowsUpgradeOnce() public {
        testContract.initialize(1);
        testContract.initializeV2(222);

        assertEq(testContract.value(), 222);
        assertEq(testContract.version(), 2);
    }

    function test_reinitializer_revertsIfSameVersion() public {
        testContract.initialize(1);
        testContract.initializeV2(111);

        vm.expectRevert("Initializable: already initialized");
        testContract.initializeV2(999);
    }

    function test_disableInitializers_blocksAll() public {
        testContract.disable();

        vm.expectRevert("Initializable: already initialized");
        testContract.initialize(123);

        vm.expectRevert("Initializable: already initialized");
        testContract.initializeV2(456);
    }

    function test_versionTracking() public {
        assertEq(testContract.version(), 0); // not initialized yet

        testContract.initialize(10);
        assertEq(testContract.version(), 1);

        testContract.initializeV2(20);
        assertEq(testContract.version(), 2);
    }

    /// @notice Confirms version 1 is stored in the top byte of the expected slot.
    function test_initializedSlotMatchesStorage() public {
        testContract.initialize(123);

        bytes32 raw = vm.load(address(testContract), EXPECTED_INITIALIZED_SLOT);
        uint8 storedVersion = uint8(uint256(raw) & 0xFF); // extract lowest byte
        assertEq(storedVersion, 1);
    }

    /// @notice Confirms _isInitializing was true during the initializer.
    function test_initializingSlotBehavior() public {
        InitInspector inspector = new InitInspector();
        inspector.initialize();

        assertEq(inspector.callerDuringInit(), address(this));
        assertEq(inspector.seenInitializing(), true);
    }
}
