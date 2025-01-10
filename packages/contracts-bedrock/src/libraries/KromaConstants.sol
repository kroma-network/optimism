// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title KromaConstants
/// @notice Constants is a library for storing constants. Simple! Don't put everything in here, just
///         the stuff used in multiple contracts. Constants that only apply to a single contract
///         should be defined in that contract instead.
library KromaConstants {
    /**
     * @notice The denominator of the validator reward.
     *         DO NOT change this value if the L2 chain is already operational.
     */
    uint256 internal constant VALIDATOR_REWARD_DENOMINATOR = 10000;

    /**
     * @notice An address that identifies that current submission round is a public round.
     */
    address internal constant VALIDATOR_PUBLIC_ROUND_ADDRESS = address(type(uint160).max);
}
