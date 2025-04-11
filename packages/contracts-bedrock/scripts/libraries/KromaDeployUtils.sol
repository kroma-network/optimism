// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Scripts
import { Vm } from "forge-std/Vm.sol";
import { DeployUtils } from "scripts/libraries/DeployUtils.sol";
import { Artifacts } from "scripts/Artifacts.s.sol";

// Interfaces
import { IProxy } from "interfaces/universal/IProxy.sol";
import { IAddressManager } from "interfaces/legacy/IAddressManager.sol";
import { IL1ChugSplashProxy } from "interfaces/legacy/IL1ChugSplashProxy.sol";
import { IResolvedDelegateProxy } from "interfaces/legacy/IResolvedDelegateProxy.sol";

/// @notice Wrapper contract around DeployUtils with all methods exposed.
library KromaDeployUtils {
    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function create1(string memory _name, bytes memory _args) internal returns (address payable) {
        return DeployUtils.create1(_name, _args);
    }

    function create1(string memory _name) internal returns (address payable) {
        return DeployUtils.create1(_name);
    }

    function create1AndSave(
        Artifacts _save,
        string memory _name,
        string memory _nick,
        bytes memory _args
    )
        internal
        returns (address payable)
    {
        return DeployUtils.create1AndSave(_save, _name, _nick, _args);
    }

    function create1AndSave(
        Artifacts _save,
        string memory _name,
        string memory _nickname
    )
        internal
        returns (address payable)
    {
        return DeployUtils.create1AndSave(_save, _name, _nickname);
    }

    function create1AndSave(
        Artifacts _save,
        string memory _name,
        bytes memory _args
    )
        internal
        returns (address payable)
    {
        return DeployUtils.create1AndSave(_save, _name, _args);
    }

    function create2(string memory _name, bytes memory _args, bytes32 _salt) internal returns (address payable) {
        return DeployUtils.create2(_name, _args, _salt);
    }

    function create2(string memory _name, bytes32 _salt) internal returns (address payable) {
        return DeployUtils.create2(_name, _salt);
    }

    function create2AndSave(
        Artifacts _save,
        string memory _name,
        string memory _nick,
        bytes memory _args,
        bytes32 _salt
    )
        internal
        returns (address payable)
    {
        return DeployUtils.create2AndSave(_save, _name, _nick, _args, _salt);
    }

    function create2AndSave(
        Artifacts _save,
        string memory _name,
        string memory _nick,
        bytes32 _salt
    )
        internal
        returns (address payable)
    {
        return DeployUtils.create2AndSave(_save, _name, _nick, _salt);
    }

    function create2AndSave(
        Artifacts _save,
        string memory _name,
        bytes memory _args,
        bytes32 _salt
    )
        internal
        returns (address payable)
    {
        return DeployUtils.create2AndSave(_save, _name, _args, _salt);
    }

    function create2AndSave(Artifacts _save, string memory _name, bytes32 _salt) internal returns (address payable) {
        return DeployUtils.create2AndSave(_save, _name, _salt);
    }

    function toIOAddress(address _sender, string memory _identifier) internal pure returns (address) {
        return DeployUtils.toIOAddress(_sender, _identifier);
    }

    function encodeConstructor(bytes memory _data) internal pure returns (bytes memory) {
        return DeployUtils.encodeConstructor(_data);
    }

    function assertValidContractAddress(address _who) internal view {
        DeployUtils.assertValidContractAddress(_who);
    }

    function assertERC1967ImplementationSet(address _proxy) internal returns (address) {
        return DeployUtils.assertERC1967ImplementationSet(_proxy);
    }

    function assertL1ChugSplashImplementationSet(address _proxy) internal returns (address) {
        return DeployUtils.assertL1ChugSplashImplementationSet(_proxy);
    }

    function assertResolvedDelegateProxyImplementationSet(
        string memory _implementationName,
        IAddressManager _addressManager
    )
        internal
        view
        returns (address)
    {
        return DeployUtils.assertResolvedDelegateProxyImplementationSet(_implementationName, _addressManager);
    }

    function buildERC1967ProxyWithImpl(string memory _proxyImplName) internal returns (IProxy) {
        return DeployUtils.buildERC1967ProxyWithImpl(_proxyImplName);
    }

    function buildL1ChugSplashProxyWithImpl(string memory _proxyImplName) internal returns (IL1ChugSplashProxy) {
        return DeployUtils.buildL1ChugSplashProxyWithImpl(_proxyImplName);
    }

    function buildResolvedDelegateProxyWithImpl(
        IAddressManager _addressManager,
        string memory _proxyImplName
    )
        internal
        returns (IResolvedDelegateProxy)
    {
        return DeployUtils.buildResolvedDelegateProxyWithImpl(_addressManager, _proxyImplName);
    }

    function buildAddressManager() internal returns (IAddressManager) {
        return DeployUtils.buildAddressManager();
    }

    function assertValidContractAddresses(address[] memory _addrs) internal view {
        DeployUtils.assertValidContractAddresses(_addrs);
    }

    function assertInitialized(address _contractAddress, uint256 _slot, uint256 _offset) internal view {
        bytes32 slotVal = vm.load(_contractAddress, bytes32(_slot));
        uint8 value = uint8((uint256(slotVal) >> (_offset * 8)) & 0xFF);
        require(
            value >= 1 || value == type(uint8).max,
            "DeployUtils: value at the given slot and offset does not indicate initialization"
        );
    }
}
