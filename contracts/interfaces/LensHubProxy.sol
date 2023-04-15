// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface LensHubProxy {
    function tokenOfOwnerByIndex(address addr, uint256 index) external view returns (uint256);

    function getFollowNFT(uint256 profileId) external view returns (address);
}