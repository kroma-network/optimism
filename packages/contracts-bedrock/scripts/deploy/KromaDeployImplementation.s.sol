// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { Script } from "forge-std/Script.sol";

import { LibString } from "@solady/utils/LibString.sol";

import { Constants } from "src/libraries/Constants.sol";
import { Predeploys } from "src/libraries/Predeploys.sol";
import { Bytes } from "src/libraries/Bytes.sol";

import { AssetManager } from "src/L1/AssetManager.sol";
import { L2OutputOracle } from "src/L1/L2OutputOracle.sol";
import { SystemConfig } from "src/L1/SystemConfig.sol";
import { ZKProofVerifier } from "src/L1/ZKProofVerifier.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IAssetManager } from "interfaces/L1/IAssetManager.sol";
import { IColosseum } from "interfaces/L1/IColosseum.sol";
import { IKromaPortal } from "interfaces/L1/IKromaPortal.sol";
import { IL2OutputOracle } from "interfaces/L1/IL2OutputOracle.sol";
import { ISecurityCouncil } from "interfaces/L1/ISecurityCouncil.sol";
import { IValidatorManager } from "interfaces/L1/IValidatorManager.sol";
import { IZKProofVerifier } from "interfaces/L1/IZKProofVerifier.sol";
import { ISP1Verifier } from "interfaces/vendor/sp1/ISP1Verifier.sol";
import { ISecurityCouncilToken } from "interfaces/governance/ISecurityCouncilToken.sol";
import { ITimeLock } from "interfaces/governance/ITimeLock.sol";
import { IUpgradeGovernor } from "interfaces/governance/IUpgradeGovernor.sol";

import { Blueprint } from "src/libraries/Blueprint.sol";

import { DeployUtils } from "scripts/libraries/DeployUtils.sol";
import { Solarray } from "scripts/libraries/Solarray.sol";
import { BaseDeployIO } from "scripts/deploy/BaseDeployIO.sol";

// See DeploySuperchain.s.sol for detailed comments on the script architecture used here.
contract KromaDeployImplementationsInput is BaseDeployIO {
    bytes32 internal _salt;
    /// @notice Deploy configs for AssetManager.
    IERC20 internal _assetToken;
    IERC721 internal _kgh;
    address internal _securityCouncil;
    address internal _vault;
    IValidatorManager internal _validatorManager;
    uint128 internal _minDelegationPeriod;
    uint128 internal _bondAmount;

    /// @notice Deploy configs for Colosseum.
    L2OutputOracle internal _l2OutputOracle;
    ZKProofVerifier internal _zkProofVerifier;
    uint256 internal _creationPeriodSeconds;
    uint256 internal _bisectionTimeout;
    uint256 internal _provingTimeout;
    uint256[] internal _segmentsLengths;

    /// @notice Deploy configs for KromaPortal.
    bool internal _paused;
    SystemConfig internal _systemConfig;

    /// @notice Deploy configs for SecurityCouncil.
    address internal _colosseum;
    address internal _governor;

    /// @notice Deploy configs for ValidatorManager.
    AssetManager internal _assetManager;
    address internal _trustedValidator;
    uint128 internal _minRegisterAmount;
    uint128 internal _minActivateAmount;
    uint128 internal _commissionChangeDelaySeconds;
    uint128 internal _roundDurationSeconds;
    uint128 internal _softJailPeriodSeconds;
    uint128 internal _hardJailPeriodSeconds;
    uint128 internal _jailThreshold;
    uint128 internal _maxFinalizations;
    uint128 internal _baseReward;

    /// @notice Deploy configs for ZKProofVerifier.
    ISP1Verifier internal _sp1Verifier;
    bytes32 internal _vKey;

    function set(bytes4 _sel, uint256 _value) public {
        require(_value != 0, "KromaDeployImplementationsInput: cannot set zero value");

        // forgefmt: disable-start
        if (_sel == this.creationPeriodSeconds.selector) _creationPeriodSeconds = _value;
        else if (_sel == this.bisectionTimeout.selector) _bisectionTimeout = _value;
        else if (_sel == this.provingTimeout.selector) _provingTimeout = _value;
        else revert("KromaDeployImplementationsInput: unknown selector");
        // forgefmt: disable-end
    }

    function set(bytes4 _sel, uint128 _value) public {
        require(_value != 0, "KromaDeployImplementationsInput: cannot set zero value");

        // forgefmt: disable-start
        if (_sel == this.minRegisterAmount.selector) _minRegisterAmount = _value;
        else if (_sel == this.minActivateAmount.selector) _minActivateAmount = _value;
        else if (_sel == this.commissionChangeDelaySeconds.selector) _commissionChangeDelaySeconds = _value;
        else if (_sel == this.roundDurationSeconds.selector) _roundDurationSeconds = _value;
        else if (_sel == this.softJailPeriodSeconds.selector) _softJailPeriodSeconds = _value;
        else if (_sel == this.hardJailPeriodSeconds.selector) _hardJailPeriodSeconds = _value;
        else if (_sel == this.jailThreshold.selector) _jailThreshold = _value;
        else if (_sel == this.maxFinalizations.selector) _maxFinalizations = _value;
        else if (_sel == this.baseReward.selector) _baseReward = _value;
        else if (_sel == this.minDelegationPeriod.selector) _minDelegationPeriod = _value;
        else if (_sel == this.bondAmount.selector) _bondAmount = _value;
        // forgefmt: disable-end
    }

    function set(bytes4 _sel, address _addr) public {
        require(_addr != address(0), "KromaDeployImplementationsInput: cannot set zero address");

        // forgefmt: disable-start
        if (_sel == this.assetToken.selector) _assetToken = IERC20(_addr);
        else if (_sel == this.kgh.selector) _kgh = IERC721(_addr);
        else if (_sel == this.securityCouncil.selector) _securityCouncil = _addr;
        else if (_sel == this.vault.selector) _vault = _addr;
        else if (_sel == this.validatorManager.selector) _validatorManager = IValidatorManager(_addr);
        else if (_sel == this.l2OutputOracle.selector) _l2OutputOracle = L2OutputOracle(_addr);
        else if (_sel == this.zkProofVerifier.selector) _zkProofVerifier = ZKProofVerifier(_addr);
        else if (_sel == this.systemConfig.selector) _systemConfig = SystemConfig(_addr);
        else if (_sel == this.colosseum.selector) _colosseum = _addr;
        else if (_sel == this.governor.selector) _governor = _addr;
        else if (_sel == this.assetManager.selector) _assetManager = AssetManager(_addr);
        else if (_sel == this.trustedValidator.selector) _trustedValidator = _addr;
        else if (_sel == this.sp1Verifier.selector) _sp1Verifier = ISP1Verifier(_addr);
        else revert("KromaDeployImplementationsInput: unknown selector");
        // forgefmt: disable-start
    }

    function set(bytes4 _sel, uint256[] memory _values) public {
        require(_values.length != 0, "KromaDeployImplementationsInput: cannot set zero length");

        if (_sel == this.segmentsLengths.selector) _segmentsLengths = _values;
        else revert("KromaDeployImplementationsInput: unknown selector");
    }

    function set(bytes4 _sel, bytes32 _value) public {
        if (_sel == this.salt.selector) _salt = _value;
        else if (_sel == this.vKey.selector) _vKey = _value;
        else revert("KromaDeployImplementationsInput: unknown selector");
    }

    function set(bytes4 _sel, bool _value) public {
        if (_sel == this.paused.selector) _paused = _value;
        else revert("KromaDeployImplementationsInput: unknown selector");
    }

    function salt() public view returns (bytes32) {
        // TODO check if implementations are deployed based on code+salt and skip deploy if so.
        return _salt;
    }

    function creationPeriodSeconds() public view returns (uint256) {
        require(_creationPeriodSeconds != 0, "KromaDeployImplementationsInput: not set");
        return _creationPeriodSeconds;
    }

    function bisectionTimeout() public view returns (uint256) {
        require(_bisectionTimeout != 0, "KromaDeployImplementationsInput: not set");
        return _bisectionTimeout;
    }

    function provingTimeout() public view returns (uint256) {
        require(_provingTimeout != 0, "KromaDeployImplementationsInput: not set");
        return _provingTimeout;
    }

    function minRegisterAmount() public view returns (uint128) {
        require(_minRegisterAmount != 0, "KromaDeployImplementationsInput: not set");
        return _minRegisterAmount;
    }

    function minActivateAmount() public view returns (uint128) {
        require(_minActivateAmount != 0, "KromaDeployImplementationsInput: not set");
        return _minActivateAmount;
    }

    function commissionChangeDelaySeconds() public view returns (uint128) {
        require(_commissionChangeDelaySeconds != 0, "KromaDeployImplementationsInput: not set");
        return _commissionChangeDelaySeconds;
    }

    function roundDurationSeconds() public view returns (uint128) {
        require(_roundDurationSeconds != 0, "KromaDeployImplementationsInput: not set");
        return _roundDurationSeconds;
    }

    function softJailPeriodSeconds() public view returns (uint128) {
        require(_softJailPeriodSeconds != 0, "KromaDeployImplementationsInput: not set");
        return _softJailPeriodSeconds;
    }

    function hardJailPeriodSeconds() public view returns (uint128) {
        require(_hardJailPeriodSeconds != 0, "KromaDeployImplementationsInput: not set");
        return _hardJailPeriodSeconds;
    }

    function jailThreshold() public view returns (uint128) {
        require(_jailThreshold != 0, "KromaDeployImplementationsInput: not set");
        return _jailThreshold;
    }

    function maxFinalizations() public view returns (uint128) {
        require(_maxFinalizations != 0, "KromaDeployImplementationsInput: not set");
        return _maxFinalizations;
    }

    function baseReward() public view returns (uint128) {
        require(_baseReward != 0, "KromaDeployImplementationsInput: not set");
        return _baseReward;
    }

    function minDelegationPeriod() public view returns (uint128) {
        require(_minDelegationPeriod != 0, "KromaDeployImplementationsInput: not set");
        return _minDelegationPeriod;
    }

    function bondAmount() public view returns (uint128) {
        require(_bondAmount != 0, "KromaDeployImplementationsInput: not set");
        return _bondAmount;
    }

    function assetToken() public view returns (IERC20) {
        require(address(_assetToken) != address(0), "KromaDeployImplementationsInput: not set");
        return _assetToken;
    }

    function kgh() public view returns (IERC721) {
        require(address(_kgh) != address(0), "KromaDeployImplementationsInput: not set");
        return _kgh;
    }

    function securityCouncil() public view returns (address) {
        require(_securityCouncil != address(0), "KromaDeployImplementationsInput: not set");
        return _securityCouncil;
    }

    function vault() public view returns (address) {
        require(_vault != address(0), "KromaDeployImplementationsInput: not set");
        return _vault;
    }

    function validatorManager() public view returns (IValidatorManager) {
        require(address(_validatorManager) != address(0), "KromaDeployImplementationsInput: not set");
        return _validatorManager;
    }

    function l2OutputOracle() public view returns (L2OutputOracle) {
        require(address(_l2OutputOracle) != address(0), "KromaDeployImplementationsInput: not set");
        return _l2OutputOracle;
    }

    function zkProofVerifier() public view returns (ZKProofVerifier) {
        require(address(_zkProofVerifier) != address(0), "KromaDeployImplementationsInput: not set");
        return _zkProofVerifier;
    }

    function systemConfig() public view returns (SystemConfig) {
        require(address(_systemConfig) != address(0), "KromaDeployImplementationsInput: not set");
        return _systemConfig;
    }

    function colosseum() public view returns (address) {
        require(_colosseum != address(0), "KromaDeployImplementationsInput: not set");
        return _colosseum;
    }

    function governor() public view returns (address) {
        require(_governor != address(0), "KromaDeployImplementationsInput: not set");
        return _governor;
    }

    function assetManager() public view returns (AssetManager) {
        require(address(_assetManager) != address(0), "KromaDeployImplementationsInput: not set");
        return _assetManager;
    }

    function trustedValidator() public view returns (address) {
        require(_trustedValidator != address(0), "KromaDeployImplementationsInput: not set");
        return _trustedValidator;
    }

    function sp1Verifier() public view returns (ISP1Verifier) {
        require(address(_sp1Verifier) != address(0), "KromaDeployImplementationsInput: not set");
        return _sp1Verifier;
    }

    function segmentsLengths() public view returns (uint256[] memory) {
        require(_segmentsLengths.length != 0, "KromaDeployImplementationsInput: not set");
        return _segmentsLengths;
    }

    function vKey() public view returns (bytes32) {
        require(_vKey != bytes32(0), "KromaDeployImplementationsInput: not set");
        return _vKey;
    }

    function paused() public view returns (bool) {
        require(_paused, "KromaDeployImplementationsInput: not set");
        return _paused;
    }
}

contract KromaDeployImplementationsOutput is BaseDeployIO {



}

contract DeployImplementations is Script {
    // -------- Core Deployment Methods --------

    function run(KromaDeployImplementationsInput _dii, KromaDeployImplementationsOutput _dio) public {
        // Deploy the implementations.


        // Deploy the OP Contracts Manager with the new implementations set.

        _dio.checkOutput(_dii);
    }

    // -------- Deployment Steps --------


    // -------- Utilities --------

    function etchIOContracts() public returns (KromaDeployImplementationsInput dii_, KromaDeployImplementationsOutput dio_) {
        (dii_, dio_) = getIOContracts();
        vm.etch(address(dii_), type(KromaDeployImplementationsInput).runtimeCode);
        vm.etch(address(dio_), type(KromaDeployImplementationsOutput).runtimeCode);
    }

    function getIOContracts() public view returns (KromaDeployImplementationsInput dii_, KromaDeployImplementationsOutput dio_) {
        dii_ = KromaDeployImplementationsInput(DeployUtils.toIOAddress(msg.sender, "optimism.KromaDeployImplementationsInput"));
        dio_ = KromaDeployImplementationsOutput(DeployUtils.toIOAddress(msg.sender, "optimism.KromaDeployImplementationsOutput"));
    }

    function deployBytecode(bytes memory _bytecode, bytes32 _salt) public returns (address newContract_) {
        assembly ("memory-safe") {
            newContract_ := create2(0, add(_bytecode, 0x20), mload(_bytecode), _salt)
        }
        require(newContract_ != address(0), "KromaDeployImplementationsOutput: create2 failed");
    }

    function deployBigBytecode(
        bytes memory _bytecode,
        bytes32 _salt
    )
        public
        returns (address newContract1_, address newContract2_)
    {
        // Preamble needs 3 bytes.
        uint256 maxInitCodeSize = 24576 - 3;
        require(_bytecode.length > maxInitCodeSize, "KromaDeployImplementationsOutput: Use deployBytecode instead");

        bytes memory part1Slice = Bytes.slice(_bytecode, 0, maxInitCodeSize);
        bytes memory part1 = Blueprint.blueprintDeployerBytecode(part1Slice);
        bytes memory part2Slice = Bytes.slice(_bytecode, maxInitCodeSize, _bytecode.length - maxInitCodeSize);
        bytes memory part2 = Blueprint.blueprintDeployerBytecode(part2Slice);

        newContract1_ = deployBytecode(part1, _salt);
        newContract2_ = deployBytecode(part2, _salt);
    }

    // Zero address is returned if the address is not found in '_standardVersionsToml'.
    function getReleaseAddress(
        string memory _version,
        string memory _contractName,
        string memory _standardVersionsToml
    )
        internal
        pure
        returns (address addr_)
    {
        string memory baseKey = string.concat('.releases["', _version, '"].', _contractName);
        string memory implAddressKey = string.concat(baseKey, ".implementation_address");
        string memory addressKey = string.concat(baseKey, ".address");
        try vm.parseTomlAddress(_standardVersionsToml, implAddressKey) returns (address parsedAddr_) {
            addr_ = parsedAddr_;
        } catch {
            try vm.parseTomlAddress(_standardVersionsToml, addressKey) returns (address parsedAddr_) {
                addr_ = parsedAddr_;
            } catch {
                addr_ = address(0);
            }
        }
    }
}
