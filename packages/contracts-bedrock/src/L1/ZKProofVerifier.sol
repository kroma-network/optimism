// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

// Libraries
import { KromaTypes } from "src/libraries/KromaTypes.sol";

// Interfaces
import { ISemver } from "interfaces/universal/ISemver.sol";
import { ISP1Verifier } from "interfaces/vendor/sp1/ISP1Verifier.sol";

/// @custom:proxied true
/// @title ZKProofVerifier
/// @notice The ZKProofVerifier contract verifies public inputs and corresponding ZK proofs.
///         Currently it verifies zkVM proofs using SP1Verifier contract.
contract ZKProofVerifier is ISemver {
    /// @notice Address of the SP1VerifierGateway contract.
    ISP1Verifier internal immutable SP1_VERIFIER;

    /// @notice The verification key for the zkVM program.
    bytes32 internal immutable ZKVM_PROGRAM_V_KEY;

    /// @notice Reverts when the zkVM program verification key is invalid.
    error InvalidZkVmVKey();

    /// @notice Reverts when the public input is invalid.
    error InvalidPublicInput();

    /// @notice Reverts when the source output root is mismatched.
    error SrcOutputMismatched();

    /// @notice Reverts when the destination output root is matched. (only for fault proof)
    error DstOutputMatched();

    /// @notice Semantic version.
    /// @custom:semver 1.1.0
    string public constant version = "1.1.0";

    /// @notice Constructs the ZKProofVerifier contract.
    /// @param _sp1Verifier Address of the SP1VerifierGateway contract.
    /// @param _zkVmProgramVKey The verification key for the zkVM program.
    constructor(ISP1Verifier _sp1Verifier, bytes32 _zkVmProgramVKey) {
        SP1_VERIFIER = _sp1Verifier;
        ZKVM_PROGRAM_V_KEY = _zkVmProgramVKey;
    }

    /// @notice Getter for the address of SP1VerifierGateway contract.
    function sp1Verifier() external view returns (ISP1Verifier) {
        return SP1_VERIFIER;
    }

    /// @notice Getter for the verification key for the zkVM program.
    function zkVmProgramVKey() external view returns (bytes32) {
        return ZKVM_PROGRAM_V_KEY;
    }

    /// @notice Verifies zkVM public inputs and proof.
    /// @param _zkVmProof The public input and proof using zkVM.
    /// @param _storedSrcOutput The stored source output root.
    /// @param _storedDstOutput The stored destination output root. It will only be used for fault proving.
    /// @param _storedL1Head The stored L1 block hash.
    /// @return publicInputHash_ Hash of public input.
    function verifyZkVmProof(
        KromaTypes.ZkVmProof calldata _zkVmProof,
        bytes32 _storedSrcOutput,
        bytes32 _storedDstOutput,
        bytes32 _storedL1Head
    )
        external
        view
        returns (bytes32 publicInputHash_)
    {
        if (_zkVmProof.zkVmProgramVKey != ZKVM_PROGRAM_V_KEY) revert InvalidZkVmVKey();

        _validatePublicInputOutput(
            _storedSrcOutput,
            _storedDstOutput,
            bytes32(_zkVmProof.publicValues[8:40]), // skip ABI-encoding prefix at publicValues[0:8].
            bytes32(_zkVmProof.publicValues[48:80]) // skip ABI-encoding prefix at publicValues[40:48].
        );

        // Check if the L1 block hash is correct.
        // Skip ABI-encoding prefix at publicValues[80:88].
        if (bytes32(_zkVmProof.publicValues[88:120]) != _storedL1Head) revert InvalidPublicInput();

        SP1_VERIFIER.verifyProof(ZKVM_PROGRAM_V_KEY, _zkVmProof.publicValues, _zkVmProof.proofBytes);

        publicInputHash_ = keccak256(_zkVmProof.publicValues);
    }

    /// @notice Checks if the public input outputs are valid. Reverts if they are invalid.
    /// @param _storedSrcOutput The stored source output root.
    /// @param _storedDstOutput The stored destination output root.
    /// @param _publicInputSrcOutput The source output root of public input.
    /// @param _publicInputDstOutput The destination output root of public input.
    function _validatePublicInputOutput(
        bytes32 _storedSrcOutput,
        bytes32 _storedDstOutput,
        bytes32 _publicInputSrcOutput,
        bytes32 _publicInputDstOutput
    )
        internal
        pure
    {
        if (_storedSrcOutput != _publicInputSrcOutput) revert SrcOutputMismatched();
        // If _storedDstOutput is non-zero, it is fault proving case, not validity proving.
        // Then assert _publicInputDstOutput is different with on-chain stored destination output.
        if (_storedDstOutput != bytes32(0)) {
            if (_storedDstOutput == _publicInputDstOutput) revert DstOutputMatched();
        }
    }
}
