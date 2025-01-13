// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

// Testing utilities
import { stdError } from "forge-std/Test.sol";
import { CommonTest } from "test/setup/CommonTest.sol";
import { NextImpl } from "test/mocks/NextImpl.sol";
import { EIP1967Helper } from "test/mocks/EIP1967Helper.sol";

// Libraries
import { Types } from "src/libraries/Types.sol";

// Target contract dependencies
import { Proxy } from "src/universal/Proxy.sol";

// Target contract
import { L2OutputOracle } from "src/L1/L2OutputOracle.sol";
import { IL2OutputOracle } from "interfaces/L1/IL2OutputOracle.sol";

contract L2OutputOracle_TestBase is CommonTest {
    function setUp() public override {
        super.enableLegacyContracts();
        super.setUp();
    }
// TODO(sm-stack): Add Kroma-specific tests
//     /// @dev Helper function to propose an output.
//     function proposeAnotherOutput() public {
//         bytes32 proposedOutput2 = keccak256(abi.encode());
//         uint256 nextBlockNumber = l2OutputOracle.nextBlockNumber();
//         uint256 nextOutputIndex = l2OutputOracle.nextOutputIndex();
//         warpToProposeTime(nextBlockNumber);
//         uint256 proposedNumber = l2OutputOracle.latestBlockNumber();

//         uint256 submissionInterval = deploy.cfg().l2OutputOracleSubmissionInterval();
//         // Ensure the submissionInterval is enforced
//         assertEq(nextBlockNumber, proposedNumber + submissionInterval);

//         vm.roll(nextBlockNumber + 1);

//         vm.expectEmit(true, true, true, true);
//         emit OutputProposed(proposedOutput2, nextOutputIndex, nextBlockNumber, block.timestamp);

//         address proposer = deploy.cfg().l2OutputOracleProposer();
//         vm.prank(proposer);
//         l2OutputOracle.proposeL2Output(proposedOutput2, nextBlockNumber, 0, 0);
//     }

//     /// @dev Tests that constructor sets the initial values correctly.
//     function test_constructor_succeeds() external {
//         IL2OutputOracle oracleImpl = IL2OutputOracle(address(new L2OutputOracle()));

//         assertEq(oracleImpl.SUBMISSION_INTERVAL(), 0);
//         assertEq(oracleImpl.submissionInterval(), 0);
//         assertEq(oracleImpl.L2_BLOCK_TIME(), 0);
//         assertEq(oracleImpl.l2BlockTime(), 0);
//         assertEq(oracleImpl.latestBlockNumber(), 0);
//         assertEq(oracleImpl.startingBlockNumber(), 0);
//         assertEq(oracleImpl.startingTimestamp(), 0);
//         assertEq(oracleImpl.PROPOSER(), address(0));
//         assertEq(oracleImpl.proposer(), address(0));
//         assertEq(oracleImpl.CHALLENGER(), address(0));
//         assertEq(oracleImpl.challenger(), address(0));
//         assertEq(oracleImpl.finalizationPeriodSeconds(), 0);
//         assertEq(oracleImpl.FINALIZATION_PERIOD_SECONDS(), 0);
//     }

//     /// @dev Tests that the proxy is initialized with the correct values.
//     function test_initialize_succeeds() external {
//         address proposer = deploy.cfg().l2OutputOracleProposer();
//         address challenger = deploy.cfg().l2OutputOracleChallenger();
//         uint256 submissionInterval = deploy.cfg().l2OutputOracleSubmissionInterval();
//         uint256 startingBlockNumber = deploy.cfg().l2OutputOracleStartingBlockNumber();
//         uint256 startingTimestamp = deploy.cfg().l2OutputOracleStartingTimestamp();
//         uint256 l2BlockTime = deploy.cfg().l2BlockTime();
//         uint256 finalizationPeriodSeconds = deploy.cfg().finalizationPeriodSeconds();

//         assertEq(l2OutputOracle.SUBMISSION_INTERVAL(), submissionInterval);
//         assertEq(l2OutputOracle.submissionInterval(), submissionInterval);
//         assertEq(l2OutputOracle.L2_BLOCK_TIME(), l2BlockTime);
//         assertEq(l2OutputOracle.l2BlockTime(), l2BlockTime);
//         assertEq(l2OutputOracle.latestBlockNumber(), startingBlockNumber);
//         assertEq(l2OutputOracle.startingBlockNumber(), startingBlockNumber);
//         assertEq(l2OutputOracle.startingTimestamp(), startingTimestamp);
//         assertEq(l2OutputOracle.finalizationPeriodSeconds(), finalizationPeriodSeconds);
//         assertEq(l2OutputOracle.PROPOSER(), proposer);
//         assertEq(l2OutputOracle.proposer(), proposer);
//         assertEq(l2OutputOracle.CHALLENGER(), challenger);
//         assertEq(l2OutputOracle.FINALIZATION_PERIOD_SECONDS(), finalizationPeriodSeconds);
//         assertEq(l2OutputOracle.challenger(), challenger);
//     }
// }

// contract L2OutputOracle_getter_Test is L2OutputOracle_TestBase {
//     bytes32 proposedOutput1 = keccak256(abi.encode(1));

//     /// @dev Tests that `latestBlockNumber` returns the correct value.
//     function test_latestBlockNumber_succeeds() external {
//         uint256 proposedNumber = l2OutputOracle.nextBlockNumber();

//         // Roll to after the block number we'll propose
//         warpToProposeTime(proposedNumber);
//         vm.prank(deploy.cfg().l2OutputOracleProposer());
//         l2OutputOracle.proposeL2Output(proposedOutput1, proposedNumber, 0, 0);
//         assertEq(l2OutputOracle.latestBlockNumber(), proposedNumber);
//     }

//     /// @dev Tests that `getL2Output` returns the correct value.
//     function test_getL2Output_succeeds() external {
//         uint256 nextBlockNumber = l2OutputOracle.nextBlockNumber();
//         uint256 nextOutputIndex = l2OutputOracle.nextOutputIndex();
//         warpToProposeTime(nextBlockNumber);
//         vm.prank(deploy.cfg().l2OutputOracleProposer());
//         l2OutputOracle.proposeL2Output(proposedOutput1, nextBlockNumber, 0, 0);

//         Types.OutputProposal memory proposal = l2OutputOracle.getL2Output(nextOutputIndex);
//         assertEq(proposal.outputRoot, proposedOutput1);
//         assertEq(proposal.timestamp, block.timestamp);

//         // The block number is larger than the latest proposed output:
//         vm.expectRevert(stdError.indexOOBError);
//         l2OutputOracle.getL2Output(nextOutputIndex + 1);
//     }

//     /// @dev Tests that `getL2OutputAfter` of an L2 block number returns the L2 output of the `getL2OutputIndexAfter` of
//     /// that block number.
//     function test_getL2OutputAfter_succeeds() external {
//         uint8 iterations = 5;

//         Types.OutputProposal memory output;
//         Types.OutputProposal memory expectedOutput;

//         for (uint8 i; i < iterations; i++) {
//             proposeAnotherOutput();
//         }

//         uint256 latestBlockNumber = l2OutputOracle.latestBlockNumber();
//         for (uint8 i = iterations - 1; i > 0; i--) {
//             uint256 index = l2OutputOracle.getL2OutputIndexAfter(latestBlockNumber);
//             output = l2OutputOracle.getL2OutputAfter(latestBlockNumber);
//             expectedOutput = l2OutputOracle.getL2Output(index);
//             assertEq(output.outputRoot, expectedOutput.outputRoot);
//             assertEq(output.timestamp, expectedOutput.timestamp);
//             assertEq(output.l2BlockNumber, expectedOutput.l2BlockNumber);

//             latestBlockNumber -= l2OutputOracle.SUBMISSION_INTERVAL();
//         }
//     }

//     /// @dev Tests that `getL2OutputIndexAfter` returns the correct value
//     ///      when the input is the exact block number of the proposal.
//     function test_getL2OutputIndexAfter_sameBlock_succeeds() external {
//         bytes32 output1 = keccak256(abi.encode(1));
//         uint256 nextBlockNumber1 = l2OutputOracle.nextBlockNumber();
//         warpToProposeTime(nextBlockNumber1);
//         vm.prank(deploy.cfg().l2OutputOracleProposer());
//         l2OutputOracle.proposeL2Output(output1, nextBlockNumber1, 0, 0);

//         // Querying with exact same block as proposed returns the proposal.
//         uint256 index1 = l2OutputOracle.getL2OutputIndexAfter(nextBlockNumber1);
//         assertEq(index1, 0);
//         assertEq(
//             keccak256(abi.encode(l2OutputOracle.getL2Output(index1))),
//             keccak256(abi.encode(output1, block.timestamp, nextBlockNumber1))
//         );
//     }

//     /// @dev Tests that `getL2OutputIndexAfter` returns the correct value
//     ///      when the input is the previous block number of the proposal.
//     function test_getL2OutputIndexAfter_previousBlock_succeeds() external {
//         bytes32 output1 = keccak256(abi.encode(1));
//         uint256 nextBlockNumber1 = l2OutputOracle.nextBlockNumber();
//         warpToProposeTime(nextBlockNumber1);
//         vm.prank(deploy.cfg().l2OutputOracleProposer());
//         l2OutputOracle.proposeL2Output(output1, nextBlockNumber1, 0, 0);

//         // Querying with previous block returns the proposal too.
//         uint256 index1 = l2OutputOracle.getL2OutputIndexAfter(nextBlockNumber1 - 1);
//         assertEq(index1, 0);
//         assertEq(
//             keccak256(abi.encode(l2OutputOracle.getL2Output(index1))),
//             keccak256(abi.encode(output1, block.timestamp, nextBlockNumber1))
//         );
//     }

//     /// @dev Tests that `getL2OutputIndexAfter` returns the correct value.
//     function test_getL2OutputIndexAfter_multipleOutputsExist_succeeds() external {
//         bytes32 output1 = keccak256(abi.encode(1));
//         uint256 nextBlockNumber1 = l2OutputOracle.nextBlockNumber();
//         warpToProposeTime(nextBlockNumber1);
//         vm.prank(deploy.cfg().l2OutputOracleProposer());
//         l2OutputOracle.proposeL2Output(output1, nextBlockNumber1, 0, 0);

//         bytes32 output2 = keccak256(abi.encode(2));
//         uint256 nextBlockNumber2 = l2OutputOracle.nextBlockNumber();
//         warpToProposeTime(nextBlockNumber2);
//         vm.prank(deploy.cfg().l2OutputOracleProposer());
//         l2OutputOracle.proposeL2Output(output2, nextBlockNumber2, 0, 0);

//         bytes32 output3 = keccak256(abi.encode(3));
//         uint256 nextBlockNumber3 = l2OutputOracle.nextBlockNumber();
//         warpToProposeTime(nextBlockNumber3);
//         vm.prank(deploy.cfg().l2OutputOracleProposer());
//         l2OutputOracle.proposeL2Output(output3, nextBlockNumber3, 0, 0);

//         bytes32 output4 = keccak256(abi.encode(4));
//         uint256 nextBlockNumber4 = l2OutputOracle.nextBlockNumber();
//         warpToProposeTime(nextBlockNumber4);
//         vm.prank(deploy.cfg().l2OutputOracleProposer());
//         l2OutputOracle.proposeL2Output(output4, nextBlockNumber4, 0, 0);

//         // Querying with a block number between the first and second proposal
//         uint256 index1 = l2OutputOracle.getL2OutputIndexAfter(nextBlockNumber1 + 1);
//         assertEq(index1, 1);
//         assertEq(
//             keccak256(abi.encode(l2OutputOracle.getL2Output(index1))),
//             keccak256(abi.encode(output2, l2OutputOracle.computeL2Timestamp(nextBlockNumber2) + 1, nextBlockNumber2))
//         );

//         // Querying with a block number between the second and third proposal
//         uint256 index2 = l2OutputOracle.getL2OutputIndexAfter(nextBlockNumber2 + 1);
//         assertEq(index2, 2);
//         assertEq(
//             keccak256(abi.encode(l2OutputOracle.getL2Output(index2))),
//             keccak256(abi.encode(output3, l2OutputOracle.computeL2Timestamp(nextBlockNumber3) + 1, nextBlockNumber3))
//         );

//         // Querying with a block number between the third and fourth proposal
//         uint256 index3 = l2OutputOracle.getL2OutputIndexAfter(nextBlockNumber3 + 1);
//         assertEq(index3, 3);
//         assertEq(
//             keccak256(abi.encode(l2OutputOracle.getL2Output(index3))),
//             keccak256(abi.encode(output4, l2OutputOracle.computeL2Timestamp(nextBlockNumber4) + 1, nextBlockNumber4))
//         );
//     }

//     /// @dev Tests that `getL2OutputIndexAfter` reverts when no output exists.
//     function test_getL2OutputIndexAfter_noOutputsExis_reverts() external {
//         vm.expectRevert("L2OutputOracle: cannot get output as no outputs have been proposed yet");
//         l2OutputOracle.getL2OutputIndexAfter(0);
//     }

//     /// @dev Tests that `nextBlockNumber` returns the correct value.
//     function test_nextBlockNumber_succeeds() external view {
//         assertEq(
//             l2OutputOracle.nextBlockNumber(),
//             // The return value should match this arithmetic
//             l2OutputOracle.latestBlockNumber() + l2OutputOracle.SUBMISSION_INTERVAL()
//         );
//     }

//     /// @dev Tests that `computeL2Timestamp` returns the correct value.
//     function test_computeL2Timestamp_succeeds() external {
//         uint256 startingBlockNumber = deploy.cfg().l2OutputOracleStartingBlockNumber();
//         uint256 startingTimestamp = deploy.cfg().l2OutputOracleStartingTimestamp();
//         uint256 l2BlockTime = deploy.cfg().l2BlockTime();

//         // reverts if timestamp is too low
//         vm.expectRevert(stdError.arithmeticError);
//         l2OutputOracle.computeL2Timestamp(startingBlockNumber - 1);

//         // check timestamp for the very first block
//         assertEq(l2OutputOracle.computeL2Timestamp(startingBlockNumber), startingTimestamp);

//         // check timestamp for the first block after the starting block
//         assertEq(l2OutputOracle.computeL2Timestamp(startingBlockNumber + 1), startingTimestamp + l2BlockTime);

//         // check timestamp for some other block number
//         assertEq(
//             l2OutputOracle.computeL2Timestamp(startingBlockNumber + 96024), startingTimestamp + l2BlockTime * 96024
//         );
//     }
// }

// contract L2OutputOracle_proposeL2Output_Test is L2OutputOracle_TestBase {
//     /// @dev Test that `proposeL2Output` succeeds for a valid input
//     ///      and when a block hash and number are not specified.
//     function test_proposeL2Output_proposeAnotherOutput_succeeds() public {
//         proposeAnotherOutput();
//     }

//     /// @dev Tests that `proposeL2Output` succeeds when given valid input and
//     ///      when a block hash and number are specified for reorg protection.
//     function test_proposeWithBlockhashAndHeight_succeeds() external {
//         // Get the number and hash of a previous block in the chain
//         uint256 prevL1BlockNumber = block.number - 1;
//         bytes32 prevL1BlockHash = blockhash(prevL1BlockNumber);

//         uint256 nextBlockNumber = l2OutputOracle.nextBlockNumber();
//         warpToProposeTime(nextBlockNumber);
//         vm.prank(deploy.cfg().l2OutputOracleProposer());
//         l2OutputOracle.proposeL2Output(nonZeroHash, nextBlockNumber, prevL1BlockHash, prevL1BlockNumber);
//     }

//     /// @dev Tests that `proposeL2Output` reverts when called by a party
//     ///      that is not the proposer.
//     function test_proposeL2Output_notProposer_reverts() external {
//         uint256 nextBlockNumber = l2OutputOracle.nextBlockNumber();
//         warpToProposeTime(nextBlockNumber);

//         vm.prank(address(128));
//         vm.expectRevert("L2OutputOracle: only the proposer address can propose new outputs");
//         l2OutputOracle.proposeL2Output(nonZeroHash, nextBlockNumber, 0, 0);
//     }

//     /// @dev Tests that `proposeL2Output` reverts when given a zero blockhash.
//     function test_proposeL2Output_emptyOutput_reverts() external {
//         bytes32 outputToPropose = bytes32(0);
//         uint256 nextBlockNumber = l2OutputOracle.nextBlockNumber();
//         warpToProposeTime(nextBlockNumber);
//         vm.prank(deploy.cfg().l2OutputOracleProposer());
//         vm.expectRevert("L2OutputOracle: L2 output proposal cannot be the zero hash");
//         l2OutputOracle.proposeL2Output(outputToPropose, nextBlockNumber, 0, 0);
//     }

//     /// @dev Tests that `proposeL2Output` reverts when given a block number
//     ///      that does not match the next expected block number.
//     function test_proposeL2Output_unexpectedBlockNumber_reverts() external {
//         uint256 nextBlockNumber = l2OutputOracle.nextBlockNumber();
//         warpToProposeTime(nextBlockNumber);
//         vm.prank(deploy.cfg().l2OutputOracleProposer());
//         vm.expectRevert("L2OutputOracle: block number must be equal to next expected block number");
//         l2OutputOracle.proposeL2Output(nonZeroHash, nextBlockNumber - 1, 0, 0);
//     }

//     /// @dev Tests that `proposeL2Output` reverts when given a block number
//     ///      that has a timestamp in the future.
//     function test_proposeL2Output_futureTimetamp_reverts() external {
//         uint256 nextBlockNumber = l2OutputOracle.nextBlockNumber();
//         uint256 nextTimestamp = l2OutputOracle.computeL2Timestamp(nextBlockNumber);
//         vm.warp(nextTimestamp);
//         vm.prank(deploy.cfg().l2OutputOracleProposer());
//         vm.expectRevert("L2OutputOracle: cannot propose L2 output in the future");
//         l2OutputOracle.proposeL2Output(nonZeroHash, nextBlockNumber, 0, 0);
//     }

//     /// @dev Tests that `proposeL2Output` reverts when given a block number
//     ///      whose hash does not match the given block hash.
//     function test_proposeL2Output_wrongFork_reverts() external {
//         uint256 nextBlockNumber = l2OutputOracle.nextBlockNumber();
//         warpToProposeTime(nextBlockNumber);
//         vm.prank(deploy.cfg().l2OutputOracleProposer());
//         vm.expectRevert("L2OutputOracle: block hash does not match the hash at the expected height");
//         l2OutputOracle.proposeL2Output(nonZeroHash, nextBlockNumber, bytes32(uint256(0x01)), block.number);
//     }

//     /// @dev Tests that `proposeL2Output` reverts when given a block number
//     ///      whose block hash does not match the given block hash.
//     function test_proposeL2Output_unmatchedBlockhash_reverts() external {
//         // Move ahead to block 100 so that we can reference historical blocks
//         vm.roll(100);

//         // Get the number and hash of a previous block in the chain
//         uint256 l1BlockNumber = block.number - 1;
//         bytes32 l1BlockHash = blockhash(l1BlockNumber);

//         uint256 nextBlockNumber = l2OutputOracle.nextBlockNumber();
//         warpToProposeTime(nextBlockNumber);
//         vm.prank(deploy.cfg().l2OutputOracleProposer());

//         // This will fail when foundry no longer returns zerod block hashes
//         vm.expectRevert("L2OutputOracle: block hash does not match the hash at the expected height");
//         l2OutputOracle.proposeL2Output(nonZeroHash, nextBlockNumber, l1BlockHash, l1BlockNumber - 1);
//     }
// }

// contract L2OutputOracle_deleteOutputs_Test is L2OutputOracle_TestBase {
//     /// @dev Tests that `deleteL2Outputs` succeeds for a single output.
//     function test_deleteOutputs_singleOutput_succeeds() external {
//         proposeAnotherOutput();
//         proposeAnotherOutput();

//         uint256 latestBlockNumber = l2OutputOracle.latestBlockNumber();
//         uint256 latestOutputIndex = l2OutputOracle.latestOutputIndex();
//         Types.OutputProposal memory newLatestOutput = l2OutputOracle.getL2Output(latestOutputIndex - 1);

//         vm.prank(l2OutputOracle.CHALLENGER());
//         vm.prank(l2OutputOracle.challenger());
//         vm.expectEmit(true, true, false, false);
//         emit OutputsDeleted(latestOutputIndex + 1, latestOutputIndex);
//         l2OutputOracle.deleteL2Outputs(latestOutputIndex);

//         // validate latestBlockNumber has been reduced
//         uint256 latestBlockNumberAfter = l2OutputOracle.latestBlockNumber();
//         uint256 latestOutputIndexAfter = l2OutputOracle.latestOutputIndex();
//         uint256 submissionInterval = deploy.cfg().l2OutputOracleSubmissionInterval();
//         assertEq(latestBlockNumber - submissionInterval, latestBlockNumberAfter);

//         // validate that the new latest output is as expected.
//         Types.OutputProposal memory proposal = l2OutputOracle.getL2Output(latestOutputIndexAfter);
//         assertEq(newLatestOutput.outputRoot, proposal.outputRoot);
//         assertEq(newLatestOutput.timestamp, proposal.timestamp);
//     }

//     /// @dev Tests that `deleteL2Outputs` succeeds for multiple outputs.
//     function test_deleteOutputs_multipleOutputs_succeeds() external {
//         proposeAnotherOutput();
//         proposeAnotherOutput();
//         proposeAnotherOutput();
//         proposeAnotherOutput();

//         uint256 latestBlockNumber = l2OutputOracle.latestBlockNumber();
//         uint256 latestOutputIndex = l2OutputOracle.latestOutputIndex();
//         Types.OutputProposal memory newLatestOutput = l2OutputOracle.getL2Output(latestOutputIndex - 3);

//         vm.prank(l2OutputOracle.CHALLENGER());
//         vm.prank(l2OutputOracle.challenger());
//         vm.expectEmit(true, true, false, false);
//         emit OutputsDeleted(latestOutputIndex + 1, latestOutputIndex - 2);
//         l2OutputOracle.deleteL2Outputs(latestOutputIndex - 2);

//         // validate latestBlockNumber has been reduced
//         uint256 latestBlockNumberAfter = l2OutputOracle.latestBlockNumber();
//         uint256 latestOutputIndexAfter = l2OutputOracle.latestOutputIndex();
//         uint256 submissionInterval = deploy.cfg().l2OutputOracleSubmissionInterval();
//         assertEq(latestBlockNumber - submissionInterval * 3, latestBlockNumberAfter);

//         // validate that the new latest output is as expected.
//         Types.OutputProposal memory proposal = l2OutputOracle.getL2Output(latestOutputIndexAfter);
//         assertEq(newLatestOutput.outputRoot, proposal.outputRoot);
//         assertEq(newLatestOutput.timestamp, proposal.timestamp);
//     }

//     /// @dev Tests that `deleteL2Outputs` reverts when not called by the challenger.
//     function test_deleteL2Outputs_ifNotChallenger_reverts() external {
//         uint256 latestBlockNumber = l2OutputOracle.latestBlockNumber();

//         vm.expectRevert("L2OutputOracle: only the challenger address can delete outputs");
//         l2OutputOracle.deleteL2Outputs(latestBlockNumber);
//     }

//     /// @dev Tests that `deleteL2Outputs` reverts for a non-existant output index.
//     function test_deleteL2Outputs_nonExistent_reverts() external {
//         proposeAnotherOutput();

//         uint256 latestBlockNumber = l2OutputOracle.latestBlockNumber();

//         vm.prank(l2OutputOracle.CHALLENGER());
//         vm.prank(l2OutputOracle.challenger());
//         vm.expectRevert("L2OutputOracle: cannot delete outputs after the latest output index");
//         l2OutputOracle.deleteL2Outputs(latestBlockNumber + 1);
//     }

//     /// @dev Tests that `deleteL2Outputs` reverts when trying to delete outputs
//     ///      after the latest output index.
//     function test_deleteL2Outputs_afterLatest_reverts() external {
//         proposeAnotherOutput();
//         proposeAnotherOutput();
//         proposeAnotherOutput();

//         // Delete the latest two outputs
//         uint256 latestOutputIndex = l2OutputOracle.latestOutputIndex();
//         vm.prank(l2OutputOracle.CHALLENGER());
//         vm.prank(l2OutputOracle.challenger());
//         l2OutputOracle.deleteL2Outputs(latestOutputIndex - 2);

//         // Now try to delete the same output again
//         vm.prank(l2OutputOracle.CHALLENGER());
//         vm.prank(l2OutputOracle.challenger());
//         vm.expectRevert("L2OutputOracle: cannot delete outputs after the latest output index");
//         l2OutputOracle.deleteL2Outputs(latestOutputIndex - 2);
//     }

//     /// @dev Tests that `deleteL2Outputs` reverts for finalized outputs.
//     function test_deleteL2Outputs_finalized_reverts() external {
//         proposeAnotherOutput();

//         // Warp past the finalization period + 1 second
//         vm.warp(block.timestamp + l2OutputOracle.FINALIZATION_PERIOD_SECONDS() + 1);

//         uint256 latestOutputIndex = l2OutputOracle.latestOutputIndex();

//         // Try to delete a finalized output
//         vm.prank(l2OutputOracle.CHALLENGER());
//         vm.prank(l2OutputOracle.challenger());
//         vm.expectRevert("L2OutputOracle: cannot delete outputs that have already been finalized");
//         l2OutputOracle.deleteL2Outputs(latestOutputIndex);
//     }
// }

// contract L2OutputOracleUpgradeable_Test is L2OutputOracle_TestBase {
//     /// @dev Tests that the proxy can be successfully upgraded.
//     function test_upgrading_succeeds() external {
//         Proxy proxy = Proxy(deploy.mustGetAddress("L2OutputOracleProxy"));
//         // Check an unused slot before upgrading.
//         bytes32 slot21Before = vm.load(address(l2OutputOracle), bytes32(uint256(21)));
//         assertEq(bytes32(0), slot21Before);

//         NextImpl nextImpl = new NextImpl();
//         vm.startPrank(EIP1967Helper.getAdmin(address(proxy)));
//         // Reviewer note: the NextImpl() still uses reinitializer. If we want to remove that, we'll need to use a
//         //   two step upgrade with the Storage lib.
//         proxy.upgradeToAndCall(address(nextImpl), abi.encodeCall(NextImpl.initialize, (2)));
//         assertEq(proxy.implementation(), address(nextImpl));

//         // Verify that the NextImpl contract initialized its values according as expected
//         bytes32 slot21After = vm.load(address(l2OutputOracle), bytes32(uint256(21)));
//         bytes32 slot21Expected = NextImpl(address(l2OutputOracle)).slot21Init();
//         assertEq(slot21Expected, slot21After);
//     }

//     /// @dev Tests that initialize reverts if the submissionInterval is zero.
//     function test_initialize_submissionInterval_reverts() external {
//         // Reset the initialized field in the 0th storage slot
//         // so that initialize can be called again.
//         vm.store(address(l2OutputOracle), bytes32(uint256(0)), bytes32(uint256(0)));

//         uint256 l2BlockTime = deploy.cfg().l2BlockTime();
//         uint256 startingBlockNumber = deploy.cfg().l2OutputOracleStartingBlockNumber();
//         uint256 startingTimestamp = deploy.cfg().l2OutputOracleStartingTimestamp();
//         address proposer = deploy.cfg().l2OutputOracleProposer();
//         address challenger = deploy.cfg().l2OutputOracleChallenger();
//         uint256 finalizationPeriodSeconds = deploy.cfg().finalizationPeriodSeconds();

//         vm.expectRevert("L2OutputOracle: submission interval must be greater than 0");
//         l2OutputOracle.initialize({
//             _submissionInterval: 0,
//             _l2BlockTime: l2BlockTime,
//             _startingBlockNumber: startingBlockNumber,
//             _startingTimestamp: startingTimestamp,
//             _proposer: proposer,
//             _challenger: challenger,
//             _finalizationPeriodSeconds: finalizationPeriodSeconds
//         });
//     }

//     /// @dev Tests that initialize reverts if the l2BlockTime is invalid.
//     function test_initialize_l2BlockTimeZero_reverts() external {
//         // Reset the initialized field in the 0th storage slot
//         // so that initialize can be called again.
//         vm.store(address(l2OutputOracle), bytes32(uint256(0)), bytes32(uint256(0)));

//         uint256 submissionInterval = deploy.cfg().l2OutputOracleSubmissionInterval();
//         uint256 startingBlockNumber = deploy.cfg().l2OutputOracleStartingBlockNumber();
//         uint256 startingTimestamp = deploy.cfg().l2OutputOracleStartingTimestamp();
//         address proposer = deploy.cfg().l2OutputOracleProposer();
//         address challenger = deploy.cfg().l2OutputOracleChallenger();
//         uint256 finalizationPeriodSeconds = deploy.cfg().finalizationPeriodSeconds();

//         vm.expectRevert("L2OutputOracle: L2 block time must be greater than 0");
//         l2OutputOracle.initialize({
//             _submissionInterval: submissionInterval,
//             _l2BlockTime: 0,
//             _startingBlockNumber: startingBlockNumber,
//             _startingTimestamp: startingTimestamp,
//             _proposer: proposer,
//             _challenger: challenger,
//             _finalizationPeriodSeconds: finalizationPeriodSeconds
//         });
//     }

//     /// @dev Tests that initialize reverts if the starting timestamp is invalid.
//     function test_initialize_badTimestamp_reverts() external {
//         // Reset the initialized field in the 0th storage slot
//         // so that initialize can be called again.
//         vm.store(address(l2OutputOracle), bytes32(uint256(0)), bytes32(uint256(0)));

//         uint256 submissionInterval = deploy.cfg().l2OutputOracleSubmissionInterval();
//         uint256 l2BlockTime = deploy.cfg().l2BlockTime();
//         uint256 startingBlockNumber = deploy.cfg().l2OutputOracleStartingBlockNumber();
//         address proposer = deploy.cfg().l2OutputOracleProposer();
//         address challenger = deploy.cfg().l2OutputOracleChallenger();
//         uint256 finalizationPeriodSeconds = deploy.cfg().finalizationPeriodSeconds();

//         vm.expectRevert("L2OutputOracle: starting L2 timestamp must be less than current time");
//         l2OutputOracle.initialize({
//             _submissionInterval: submissionInterval,
//             _l2BlockTime: l2BlockTime,
//             _startingBlockNumber: startingBlockNumber,
//             _startingTimestamp: block.timestamp + 1,
//             _proposer: proposer,
//             _challenger: challenger,
//             _finalizationPeriodSeconds: finalizationPeriodSeconds
//         });
//     }
}

contract L2OutputOracleTest is L2OutputOracle_Initializer {
    bytes32 submittedOutput1 = keccak256(abi.encode(1));

    function setUp() public override {
        super.setUp();

        vm.prank(trusted);
        pool.deposit{ value: trusted.balance }();
    }

    function test_constructor_succeeds() external {
        assertEq(address(oracle.VALIDATOR_POOL()), address(pool));
        assertEq(address(oracle.VALIDATOR_MANAGER()), address(valMgr));
        assertEq(oracle.COLOSSEUM(), address(colosseum));
        assertEq(oracle.SUBMISSION_INTERVAL(), submissionInterval);
        assertEq(oracle.L2_BLOCK_TIME(), l2BlockTime);
        assertEq(oracle.FINALIZATION_PERIOD_SECONDS(), finalizationPeriodSeconds);
        assertEq(oracle.latestBlockNumber(), startingBlockNumber);
        assertEq(oracle.startingBlockNumber(), startingBlockNumber);
        assertEq(oracle.startingTimestamp(), startingTimestamp);
    }

    function test_constructor_badTimestamp_reverts() external {
        vm.expectRevert("L2OutputOracle: starting L2 timestamp must be less than current time");
        new L2OutputOracle({
            _validatorPool: pool,
            _validatorManager: valMgr,
            _colosseum: address(colosseum),
            _submissionInterval: submissionInterval,
            _l2BlockTime: l2BlockTime,
            _startingBlockNumber: startingBlockNumber,
            _startingTimestamp: block.timestamp + 1,
            _finalizationPeriodSeconds: finalizationPeriodSeconds
        });
    }

    function test_constructor_l2BlockTimeZero_reverts() external {
        vm.expectRevert("L2OutputOracle: L2 block time must be greater than 0");
        new L2OutputOracle({
            _validatorPool: pool,
            _validatorManager: valMgr,
            _colosseum: address(colosseum),
            _submissionInterval: submissionInterval,
            _l2BlockTime: 0,
            _startingBlockNumber: startingBlockNumber,
            _startingTimestamp: block.timestamp,
            _finalizationPeriodSeconds: finalizationPeriodSeconds
        });
    }

    function test_constructor_submissionInterval_reverts() external {
        vm.expectRevert("L2OutputOracle: submission interval must be greater than 0");
        new L2OutputOracle({
            _validatorPool: pool,
            _validatorManager: valMgr,
            _colosseum: address(colosseum),
            _submissionInterval: 0,
            _l2BlockTime: l2BlockTime,
            _startingBlockNumber: startingBlockNumber,
            _startingTimestamp: block.timestamp,
            _finalizationPeriodSeconds: finalizationPeriodSeconds
        });
    }

    /****************
     * Getter Tests *
     ****************/

    // Test: latestBlockNumber() should return the correct value
    function test_latestBlockNumber_succeeds() external {
        uint256 submittedNumber = oracle.nextBlockNumber();

        // Roll to after the block number we'll submit
        warpToSubmitTime();
        vm.prank(trusted);
        oracle.submitL2Output(submittedOutput1, submittedNumber, 0, 0);
        assertEq(oracle.latestBlockNumber(), submittedNumber);
    }

    // Test: getL2Output() should return the correct value
    function test_getL2Output_succeeds() external {
        uint256 nextBlockNumber = oracle.nextBlockNumber();
        uint256 nextOutputIndex = oracle.nextOutputIndex();
        warpToSubmitTime();
        vm.prank(trusted);
        oracle.submitL2Output(submittedOutput1, nextBlockNumber, 0, 0);

        Types.CheckpointOutput memory output = oracle.getL2Output(nextOutputIndex);
        assertEq(output.outputRoot, submittedOutput1);
        assertEq(output.timestamp, block.timestamp);

        // The block number is larger than the latest submitted output:
        vm.expectRevert(stdError.indexOOBError);
        oracle.getL2Output(nextOutputIndex + 1);
    }

    // Test: getL2OutputIndexAfter() returns correct value when input is exact block
    function test_getL2OutputIndexAfter_sameBlock_succeeds() external {
        bytes32 output1 = keccak256(abi.encode(1));
        uint256 nextBlockNumber1 = oracle.nextBlockNumber();
        warpToSubmitTime();
        vm.prank(trusted);
        oracle.submitL2Output(output1, nextBlockNumber1, 0, 0);

        // Querying with exact same block as submitted returns the output.
        uint256 index1 = oracle.getL2OutputIndexAfter(nextBlockNumber1);
        assertEq(index1, 0);
    }

    // Test: getL2OutputIndexAfter() returns correct value when input is previous block
    function test_getL2OutputIndexAfter_previousBlock_succeeds() external {
        bytes32 output1 = keccak256(abi.encode(1));
        uint256 nextBlockNumber1 = oracle.nextBlockNumber();
        warpToSubmitTime();
        vm.prank(trusted);
        oracle.submitL2Output(output1, nextBlockNumber1, 0, 0);

        // Querying with previous block returns the output too.
        uint256 index1 = oracle.getL2OutputIndexAfter(nextBlockNumber1 - 1);
        assertEq(index1, 0);
    }

    // Test: getL2OutputIndexAfter() returns correct value during binary search
    function test_getL2OutputIndexAfter_multipleOutputsExist_succeeds() external {
        bytes32 output1 = keccak256(abi.encode(1));
        uint256 nextBlockNumber1 = oracle.nextBlockNumber();
        warpToSubmitTime();
        vm.prank(trusted);
        oracle.submitL2Output(output1, nextBlockNumber1, 0, 0);

        bytes32 output2 = keccak256(abi.encode(2));
        uint256 nextBlockNumber2 = oracle.nextBlockNumber();
        warpToSubmitTime();
        vm.prank(trusted);
        oracle.submitL2Output(output2, nextBlockNumber2, 0, 0);

        bytes32 output3 = keccak256(abi.encode(3));
        uint256 nextBlockNumber3 = oracle.nextBlockNumber();
        warpToSubmitTime();
        vm.prank(trusted);
        oracle.submitL2Output(output3, nextBlockNumber3, 0, 0);

        bytes32 output4 = keccak256(abi.encode(4));
        uint256 nextBlockNumber4 = oracle.nextBlockNumber();
        warpToSubmitTime();
        vm.prank(trusted);
        oracle.submitL2Output(output4, nextBlockNumber4, 0, 0);

        // Querying with a block number between the first and second output
        uint256 index1 = oracle.getL2OutputIndexAfter(nextBlockNumber1 + 1);
        assertEq(index1, 1);

        // Querying with a block number between the second and third output
        uint256 index2 = oracle.getL2OutputIndexAfter(nextBlockNumber2 + 1);
        assertEq(index2, 2);

        // Querying with a block number between the third and fourth output
        uint256 index3 = oracle.getL2OutputIndexAfter(nextBlockNumber3 + 1);
        assertEq(index3, 3);
    }

    // Test: getL2OutputIndexAfter() reverts when no output exists yet
    function test_getL2OutputIndexAfter_noOutputsExist_reverts() external {
        vm.expectRevert("L2OutputOracle: cannot get output as no outputs have been submitted yet");
        oracle.getL2OutputIndexAfter(0);
    }

    // Test: nextBlockNumber() should return the correct value
    function test_nextBlockNumber_succeeds() external {
        assertEq(oracle.nextBlockNumber(), oracle.latestBlockNumber());

        test_submitL2Output_submitAnotherOutput_succeeds();

        assertEq(
            oracle.nextBlockNumber(),
            // The return value should match this arithmetic
            oracle.latestBlockNumber() + oracle.SUBMISSION_INTERVAL()
        );
    }

    function test_computeL2Timestamp_succeeds() external {
        // reverts if timestamp is too low
        vm.expectRevert(stdError.arithmeticError);
        oracle.computeL2Timestamp(startingBlockNumber - 1);

        // returns the correct value...
        // ... for the very first block
        assertEq(oracle.computeL2Timestamp(startingBlockNumber), startingTimestamp);

        // ... for the first block after the starting block
        assertEq(
            oracle.computeL2Timestamp(startingBlockNumber + 1),
            startingTimestamp + l2BlockTime
        );

        // ... for some other block number
        assertEq(
            oracle.computeL2Timestamp(startingBlockNumber + 96024),
            startingTimestamp + l2BlockTime * 96024
        );
    }

    function test_nextOutputMinL2Timestamp_succeeds() external {
        assertEq(
            oracle.nextOutputMinL2Timestamp(),
            oracle.computeL2Timestamp(oracle.nextBlockNumber() + 1)
        );
    }

    /*****************************
     * Submit Tests - Happy Path *
     *****************************/

    // Test: submitL2Output succeeds when given valid input, and no block hash and number are
    // specified.
    function test_submitL2Output_submitAnotherOutput_succeeds() public {
        startingBlockNumber = oracle.startingBlockNumber();
        bytes32 submittedOutput2 = keccak256(abi.encode());
        uint256 nextBlockNumber = oracle.nextBlockNumber();
        uint256 nextOutputIndex = oracle.nextOutputIndex();
        warpToSubmitTime();
        uint256 submittedNumber = oracle.latestBlockNumber();

        // Ensure the submissionInterval is enforced
        if (nextBlockNumber == startingBlockNumber) {
            assertEq(nextBlockNumber, submittedNumber);
        } else {
            assertEq(nextBlockNumber, submittedNumber + submissionInterval);
        }

        vm.roll(nextBlockNumber + 1);

        uint128 finalizedAt = uint128(block.timestamp + oracle.FINALIZATION_PERIOD_SECONDS());
        vm.expectCall(
            address(oracle.VALIDATOR_POOL()),
            abi.encodeWithSelector(ValidatorPool.createBond.selector, nextOutputIndex, finalizedAt)
        );
        vm.expectEmit(true, true, true, true);
        emit OutputSubmitted(submittedOutput2, nextOutputIndex, nextBlockNumber, block.timestamp);
        vm.prank(trusted);
        oracle.submitL2Output(submittedOutput2, nextBlockNumber, 0, 0);
    }

    // Test: submitL2Output succeeds when given valid input, and when a block hash and number are
    // specified for reorg protection.
    function test_submitWithBlockhashAndHeight_succeeds() external {
        // Get the number and hash of a previous block in the chain
        uint256 prevL1BlockNumber = block.number - 1;
        bytes32 prevL1BlockHash = blockhash(prevL1BlockNumber);
        uint256 nextBlockNumber = oracle.nextBlockNumber();
        warpToSubmitTime();

        vm.prank(trusted);
        oracle.submitL2Output(nonZeroHash, nextBlockNumber, prevL1BlockHash, prevL1BlockNumber);
    }

    /***************************
     * Submit Tests - Sad Path *
     ***************************/

    // Test: submitL2Output fails if called by a party that is not the validator.
    function test_submitL2Output_notValidator_reverts() external {
        uint256 nextBlockNumber = oracle.nextBlockNumber();
        warpToSubmitTime();

        vm.prank(address(128));
        vm.expectRevert("L2OutputOracle: only the next selected validator can submit output");
        oracle.submitL2Output(nonZeroHash, nextBlockNumber, 0, 0);
    }

    // Test: submitL2Output fails given a zero blockhash.
    function test_submitL2Output_emptyOutput_reverts() external {
        bytes32 outputToSubmit = bytes32(0);
        uint256 nextBlockNumber = oracle.nextBlockNumber();
        warpToSubmitTime();
        vm.prank(trusted);
        vm.expectRevert("L2OutputOracle: L2 checkpoint output cannot be the zero hash");
        oracle.submitL2Output(outputToSubmit, nextBlockNumber, 0, 0);
    }

    // Test: submitL2Output fails if the block number doesn't match the next expected number.
    function test_submitL2Output_unexpectedBlockNumber_reverts() external {
        uint256 nextBlockNumber = oracle.nextBlockNumber();
        warpToSubmitTime();
        vm.prank(trusted);
        vm.expectRevert("L2OutputOracle: block number must be equal to next expected block number");
        oracle.submitL2Output(nonZeroHash, nextBlockNumber - 1, 0, 0);
    }

    // Test: submitL2Output fails if it would have a timestamp in the future.
    function test_submitL2Output_futureTimetamp_reverts() external {
        uint256 nextBlockNumber = oracle.nextBlockNumber();
        uint256 nextTimestamp = oracle.nextOutputMinL2Timestamp();
        vm.warp(nextTimestamp - 1);
        vm.prank(trusted);
        vm.expectRevert("L2OutputOracle: cannot submit L2 output in the future");
        oracle.submitL2Output(nonZeroHash, nextBlockNumber, 0, 0);
    }

    // Test: submitL2Output fails if a non-existent L1 block hash and number are provided for reorg
    // protection.
    function test_submitL2Output_wrongFork_reverts() external {
        uint256 nextBlockNumber = oracle.nextBlockNumber();
        warpToSubmitTime();
        vm.prank(trusted);
        vm.expectRevert(
            "L2OutputOracle: block hash does not match the hash at the expected height"
        );
        oracle.submitL2Output(
            nonZeroHash,
            nextBlockNumber,
            bytes32(uint256(0x01)),
            block.number - 1
        );
    }

    // Test: submitL2Output fails when given valid input, but the block hash and number do not
    // match.
    function test_submitL2Output_unmatchedBlockhash_reverts() external {
        // Move ahead to block 100 so that we can reference historical blocks
        vm.roll(100);

        // Get the number and hash of a previous block in the chain
        uint256 l1BlockNumber = block.number - 1;
        bytes32 l1BlockHash = blockhash(l1BlockNumber);

        uint256 nextBlockNumber = oracle.nextBlockNumber();
        warpToSubmitTime();
        vm.prank(trusted);

        // This will fail when foundry no longer returns zerod block hashes
        vm.expectRevert(
            "L2OutputOracle: block hash does not match the hash at the expected height"
        );
        oracle.submitL2Output(nonZeroHash, nextBlockNumber, l1BlockHash, l1BlockNumber - 1);
    }

    /*****************************
     * Replace Tests - Happy Path *
     *****************************/

    function test_replaceL2Output_succeeds() external {
        test_submitL2Output_submitAnotherOutput_succeeds();
        test_submitL2Output_submitAnotherOutput_succeeds();
        test_submitL2Output_submitAnotherOutput_succeeds();

        uint256 outputIndex = oracle.latestOutputIndex() - 1;
        bytes32 newOutputRoot = keccak256(abi.encode("new_output"));

        vm.prank(address(colosseum));
        vm.expectEmit(true, true, false, false);
        emit OutputReplaced(outputIndex, challenger, newOutputRoot);
        oracle.replaceL2Output(outputIndex, newOutputRoot, challenger);

        // validate that the output root is replaced
        Types.CheckpointOutput memory output = oracle.getL2Output(outputIndex);
        assertEq(newOutputRoot, output.outputRoot);
        assertEq(challenger, output.submitter);
    }

    /***************************
     * Replace Tests - Sad Path *
     ***************************/

    function test_replaceL2Output_ifNotChallenger_reverts() external {
        uint256 latestBlockNumber = oracle.latestBlockNumber();

        vm.expectRevert("L2OutputOracle: only the colosseum contract can replace an output");
        oracle.replaceL2Output(latestBlockNumber, keccak256(abi.encode("new_output")), address(1));
    }

    function test_replaceL2Output_zeroAddress_reverts() external {
        uint256 latestBlockNumber = oracle.latestBlockNumber();

        vm.prank(address(colosseum));
        vm.expectRevert("L2OutputOracle: submitter address cannot be zero");
        oracle.replaceL2Output(latestBlockNumber, keccak256(abi.encode("new_output")), address(0));
    }

    function test_replaceL2Output_nonExistent_reverts() external {
        test_submitL2Output_submitAnotherOutput_succeeds();

        uint256 latestBlockNumber = oracle.latestBlockNumber();

        vm.prank(address(colosseum));
        vm.expectRevert("L2OutputOracle: cannot replace an output after the latest output index");
        oracle.replaceL2Output(
            latestBlockNumber + 1,
            keccak256(abi.encode("new_output")),
            challenger
        );
    }

    function test_replaceL2Output_finalized_reverts() external {
        test_submitL2Output_submitAnotherOutput_succeeds();

        // Warp past the finalization period + 1 second
        vm.warp(block.timestamp + oracle.FINALIZATION_PERIOD_SECONDS() + 1);

        uint256 latestOutputIndex = oracle.latestOutputIndex();

        // Try to delete a finalized output
        vm.prank(address(colosseum));
        vm.expectRevert("L2OutputOracle: cannot replace an output that has already been finalized");
        oracle.replaceL2Output(latestOutputIndex, keccak256(abi.encode("new_output")), challenger);
    }
}

contract L2OutputOracle_ValidatorSystemUpgrade_Test is ValidatorSystemUpgrade_Initializer {
    function setUp() public override {
        super.setUp();

        vm.prank(trusted);
        pool.deposit{ value: trusted.balance }();
        _registerValidator(trusted, minActivateAmount);

        // Submit outputs to leave 1 output before ValidatorPool is terminated
        for (uint256 i; i <= terminateOutputIndex - 1; i++) {
            _submitL2OutputV1();
        }
    }

    function test_submitL2Output_upgradeValidatorSystem_succeeds() external {
        // Assert terminateOutputIndex still interacts with ValidatorPool
        warpToSubmitTime();
        uint256 nextBlockNumber = oracle.nextBlockNumber();
        bytes32 outputRoot = keccak256(abi.encode(nextBlockNumber));

        assertFalse(pool.isTerminated(oracle.nextOutputIndex()));
        assertEq(pool.nextValidator(), trusted);

        uint128 finalizedAt = uint128(block.timestamp + oracle.FINALIZATION_PERIOD_SECONDS());
        vm.expectCall(
            address(oracle.VALIDATOR_POOL()),
            abi.encodeWithSelector(ValidatorPool.nextValidator.selector)
        );
        vm.expectCall(
            address(oracle.VALIDATOR_POOL()),
            abi.encodeWithSelector(
                ValidatorPool.createBond.selector,
                oracle.nextOutputIndex(),
                finalizedAt
            )
        );
        vm.prank(trusted);
        oracle.submitL2Output(outputRoot, nextBlockNumber, 0, 0);

        // Assert terminateOutputIndex + 1 interacts with ValidatorManager
        warpToSubmitTime();
        nextBlockNumber = oracle.nextBlockNumber();
        outputRoot = keccak256(abi.encode(nextBlockNumber));

        assertTrue(pool.isTerminated(oracle.nextOutputIndex()));
        assertEq(valMgr.nextValidator(), trusted);

        vm.expectCall(
            address(oracle.VALIDATOR_MANAGER()),
            abi.encodeWithSelector(IValidatorManager.checkSubmissionEligibility.selector, trusted)
        );
        vm.expectCall(
            address(oracle.VALIDATOR_MANAGER()),
            abi.encodeWithSelector(
                IValidatorManager.afterSubmitL2Output.selector,
                oracle.nextOutputIndex()
            )
        );
        vm.prank(trusted);
        oracle.submitL2Output(outputRoot, nextBlockNumber, 0, 0);
    }

    function test_setNextFinalizeOutputIndex_succeeds() external {
        // Only ValidatorPool can set finalized output before upgrade
        vm.prank(address(pool));
        oracle.setNextFinalizeOutputIndex(1);
        assertEq(oracle.nextFinalizeOutputIndex(), 1);

        vm.prank(address(pool));
        oracle.setNextFinalizeOutputIndex(terminateOutputIndex + 1);
        assertEq(oracle.nextFinalizeOutputIndex(), terminateOutputIndex + 1);

        // Now only ValidatorManager can set finalized output after upgrade
        vm.prank(address(valMgr));
        oracle.setNextFinalizeOutputIndex(terminateOutputIndex + 2);
        assertEq(oracle.nextFinalizeOutputIndex(), terminateOutputIndex + 2);
    }

    function test_setNextFinalizeOutputIndex_wrongCaller_reverts() external {
        // Only ValidatorPool can set finalized output before upgrade
        vm.prank(address(valMgr));
        vm.expectRevert(
            "L2OutputOracle: only the validator pool contract can set next finalize output index"
        );
        oracle.setNextFinalizeOutputIndex(1);

        // Now only ValidatorManager can set finalized output after upgrade
        vm.prank(address(pool));
        vm.expectRevert(
            "L2OutputOracle: only the validator manager contract can set next finalize output index"
        );
        oracle.setNextFinalizeOutputIndex(terminateOutputIndex + 2);
    }
}

contract L2OutputOracleUpgradeable_Test is L2OutputOracle_Initializer {
    Proxy internal proxy;

    function setUp() public override {
        super.setUp();
        proxy = Proxy(payable(address(oracle)));
    }

    function test_initValuesOnProxy_succeeds() external {
        assertEq(submissionInterval, oracleImpl.SUBMISSION_INTERVAL());
        assertEq(l2BlockTime, oracleImpl.L2_BLOCK_TIME());
        assertEq(startingBlockNumber, oracleImpl.startingBlockNumber());
        assertEq(startingTimestamp, oracleImpl.startingTimestamp());

        assertEq(address(oracle.VALIDATOR_POOL()), address(pool));
        assertEq(address(oracle.VALIDATOR_MANAGER()), address(valMgr));
        assertEq(address(colosseum), oracleImpl.COLOSSEUM());
    }

    function test_initializeProxy_alreadyInitialized_reverts() external {
        vm.expectRevert("Initializable: contract is already initialized");
        L2OutputOracle(payable(proxy)).initialize(startingBlockNumber, startingTimestamp);
    }

    function test_initializeImpl_alreadyInitialized_reverts() external {
        vm.expectRevert("Initializable: contract is already initialized");
        L2OutputOracle(oracleImpl).initialize(startingBlockNumber, startingTimestamp);
    }

    function test_upgrading_succeeds() external {
        // Check an unused slot before upgrading.
        bytes32 slot21Before = vm.load(address(oracle), bytes32(uint256(21)));
        assertEq(bytes32(0), slot21Before);

        NextImpl nextImpl = new NextImpl();
        vm.startPrank(multisig);
        proxy.upgradeToAndCall(
            address(nextImpl),
            abi.encodeWithSelector(NextImpl.initialize.selector)
        );
        assertEq(proxy.implementation(), address(nextImpl));

        // Verify that the NextImpl contract initialized its values according as expected
        bytes32 slot21After = vm.load(address(oracle), bytes32(uint256(21)));
        bytes32 slot21Expected = NextImpl(address(oracle)).slot21Init();
        assertEq(slot21Expected, slot21After);
    }
}
