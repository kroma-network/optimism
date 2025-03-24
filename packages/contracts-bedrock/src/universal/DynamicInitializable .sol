// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

/// @title DynamicInitializable
/// @notice Proxy-safe initializer logic with version tracking, allowing initialization and reinitialization
///         using dynamically assigned storage slots. Designed for upgradeable contracts.
abstract contract DynamicInitializable {
    /// @notice The storage slot that holds the initialized version of the contract.
    /// @dev    Slot: `bytes32(uint256(keccak256("initializable.dynamic.initialized")) - 1)`
    bytes32 internal constant _INITIALIZED_SLOT =
        0xdce1487834563344805069907c71c21ed215aa325e782a45fba464598c724d5f;

    /// @notice The storage slot that tracks whether the contract is in the middle of initializing.
    /// @dev    Slot: `bytes32(uint256(keccak256("initializable.dynamic.initializing")) - 1)`
    bytes32 internal constant _INITIALIZING_SLOT =
        0xa087681743c4d5a51783217156afb13546a4b1765274fae6966078bdcc8caa91;

    /// @notice Emitted whenever the contract is initialized or reinitialized.
    /// @param version The version number that was initialized.
    event Initialized(uint8 version);

    /// @notice Modifier to protect an initializer function so it can only be called once.
    /// @dev    Sets version to 1. Allows nested calls when within the initialization context.
    modifier initializer() {
        bool isTopLevelCall = !_isInitializing();
        require(
            _getInitializedVersion() < 1 || (isTopLevelCall && !_isInitialized()),
            "Initializable: already initialized"
        );

        _setInitializedVersion(1);
        if (isTopLevelCall) {
            _setInitializing(true);
        }
        _;
        if (isTopLevelCall) {
            _setInitializing(false);
            emit Initialized(1);
        }
    }

    /// @notice Modifier to allow initialization for a specific version.
    /// @dev    Each version number can only be used once, and must be greater than previous.
    /// @param version The initialization version to apply.
    modifier reinitializer(uint8 version) {
        require(!_isInitializing(), "Initializable: contract is initializing");
        require(
            _getInitializedVersion() < version,
            "Initializable: already initialized"
        );

        _setInitializedVersion(version);
        _setInitializing(true);
        _;
        _setInitializing(false);
        emit Initialized(version);
    }

    /// @notice Modifier to allow a function to run only during initialization.
    /// @dev    Typically used for internal setup logic in upgrade paths.
    modifier onlyInitializing() {
        require(_isInitializing(), "Initializable: contract is not initializing");
        _;
    }

    /// @notice Locks the contract against all future initialization calls.
    /// @dev    Sets the version to the maximum `uint8` value.
    function _disableInitializers() internal {
        _setInitializedVersion(type(uint8).max);
    }

    /// @notice Reads the current initialized version from storage.
    /// @return version The last successfully initialized version.
    function _getInitializedVersion() internal view returns (uint8 version) {
        bytes32 slot = _INITIALIZED_SLOT;
        assembly {
            version := sload(slot)
        }
    }

    /// @notice Stores the provided version number to the initialized slot.
    /// @param version The version number to write (should be > previous).
    function _setInitializedVersion(uint8 version) private {
        bytes32 slot = _INITIALIZED_SLOT;
        assembly {
            sstore(slot, version)
        }
    }

    /// @notice Returns true if the contract has been initialized with any version.
    /// @return True if initialized with version > 0.
    function _isInitialized() internal view returns (bool) {
        return _getInitializedVersion() > 0;
    }

    /// @notice Returns true if the contract is currently within an initializer context.
    /// @return initializing True if currently initializing.
    function _isInitializing() internal view returns (bool initializing) {
        bytes32 slot = _INITIALIZING_SLOT;
        assembly {
            initializing := sload(slot)
        }
    }

    /// @notice Internal setter for the `_initializing` flag.
    /// @param value Boolean to indicate initializing state (true = initializing).
    function _setInitializing(bool value) private {
        bytes32 slot = _INITIALIZING_SLOT;
        assembly {
            sstore(slot, value)
        }
    }
}
