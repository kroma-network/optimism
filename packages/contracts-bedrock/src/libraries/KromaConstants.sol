// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title KromaConstants
/// @notice Constants is a library for storing constants. Simple! Don't put everything in here, just
///         the stuff used in multiple contracts. Constants that only apply to a single contract
///         should be defined in that contract instead.
library KromaConstants {
    /**
     * @notice An address that identifies that current submission round is a public round.
     */
    address internal constant VALIDATOR_PUBLIC_ROUND_ADDRESS = address(type(uint160).max);
}
