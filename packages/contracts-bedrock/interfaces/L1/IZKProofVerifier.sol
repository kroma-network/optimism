// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { KromaTypes } from "src/libraries/KromaTypes.sol";
import { ISP1Verifier } from "interfaces/vendor/sp1/ISP1Verifier.sol";

interface IZKProofVerifier {
    error InvalidZkVmVKey();
    error InvalidPublicInput();
    error SrcOutputMismatched();
    error DstOutputMatched();

    function version() external view returns (string memory);
    function sp1Verifier() external view returns (ISP1Verifier);
    function zkVmProgramVKey() external view returns (bytes32);
    function verifyZkVmProof(
        KromaTypes.ZkVmProof calldata _zkVmProof,
        bytes32 _storedSrcOutput,
        bytes32 _storedDstOutput,
        bytes32 _storedL1Head
    )
        external
        view
        returns (bytes32 publicInputHash_);

    function __constructor__(ISP1Verifier _sp1Verifier, bytes32 _zkVmProgramVKey) external;
}
