// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {ByteHasher} from "./helpers/ByteHasher.sol";
import {IWorldID} from "./interfaces/IWorldID.sol";
import "./interfaces/IContentsContract.sol";
import "./interfaces/LensFollowNFT.sol";
import "./interfaces/LensHubProxy.sol";

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract AdToken is ERC721, ERC721URIStorage, IContentsContract, Ownable {
    uint256 public requiredLensFollowers;
    LensHubProxy lensHubProxyInstance;

    event RequiredFollowersUpdated(uint256 oldValue, uint256 newValue);
    event NewAdContentMinted(uint256 tokenId);

    using ByteHasher for bytes;

    ///////////////////////////////////////////////////////////////////////////////
    ///                                  ERRORS                                ///
    //////////////////////////////////////////////////////////////////////////////

    /// @notice Thrown when attempting to reuse a nullifier
    error InvalidNullifier();

    /// @dev The World ID instance that will be used for verifying proofs
    IWorldID internal immutable worldId;

    /// @dev The contract's external nullifier hash
    uint256 internal immutable externalNullifier;

    /// @dev The World ID group ID (always 1)
    uint256 internal immutable groupId = 1;

    /// @dev Whether a nullifier hash has been used already. Used to guarantee an action is only performed once by a single person
    mapping(uint256 => bool) internal nullifierHashes;

    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    /// @param _worldId The WorldID instance that will verify the proofs
    /// @param _appId The World ID app ID
    /// @param _actionId The World ID action ID
    constructor(
        IWorldID _worldId,
        string memory _appId,
        string memory _actionId,
        address _lensProxyHubAddress
    ) ERC721("AdToken", "ADK") {
        worldId = _worldId;
        externalNullifier = abi
            .encodePacked(abi.encodePacked(_appId).hashToField(), _actionId)
            .hashToField();
        lensHubProxyInstance = LensHubProxy(_lensProxyHubAddress);
    }

    function setRequiredFollowers(uint256 _requiredFollowers) external onlyOwner {
        uint256 oldValue = requiredLensFollowers;
        requiredLensFollowers = _requiredFollowers;
        emit RequiredFollowersUpdated(oldValue, _requiredFollowers);
    }

    function safeMintForDebugging(address to, string memory uri) public onlyOwner returns (uint256) {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);

        return tokenId;
    }

    function verifyAndExecute(
        address signal,
        uint256 root,
        uint256 nullifierHash,
        uint256[8] calldata proof,
        address to,
        string memory uri
    ) public {
        // First, we make sure this person hasn't done this before
        if (nullifierHashes[nullifierHash]) revert InvalidNullifier();

        // We now verify the provided proof is valid and the user is verified by World ID
        worldId.verifyProof(
            root,
            groupId,
            abi.encodePacked(signal).hashToField(),
            nullifierHash,
            externalNullifier,
            proof
        );

        // uint256 numFollowers = function(message.sender)

        // We now record the user has done this, so they can't do it again (proof of uniqueness)
        nullifierHashes[nullifierHash] = true;

        // Finally, execute your logic here, for example issue a token, NFT, etc...
        // Make sure to emit some kind of event afterwards!

        // uint256 lensProfileId = lensHubProxyInstance.defaultProfile(signal);
        // address lensFollowNftAddress = lensHubProxyInstance.getFollowNFT(lensProfileId);
        // setFollowNftAddress(lensFollowNftAddress);
        // uint256 numFollowers = lensFollowNftInstance.totalSupply();
        // return numFollowers;

        // MINT

        uint256 lensProfileId = lensHubProxyInstance.tokenOfOwnerByIndex(signal, 0);
        address lensFollowNftAddress = lensHubProxyInstance.getFollowNFT(lensProfileId);
        LensFollowNFT lensFollowNftInstance = LensFollowNFT(lensFollowNftAddress);
        uint256 numFollowers = lensFollowNftInstance.totalSupply();

        // require at least one follower
        require(numFollowers >= requiredLensFollowers, "You have insufficient number of followers on Lens");

        // Mint
        uint256 tokenId = safeMintForDebugging(to, uri);
        emit NewAdContentMinted(tokenId);
    }

    // The following functions are overrides required by Solidity.

    function _burn(
        uint256 tokenId
    ) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(
        uint256 tokenId
    ) public view override(ERC721, ERC721URIStorage, IContentsContract) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function ownerOf(
        uint256 tokenId
    ) public view override(ERC721, IContentsContract) returns (address) {
        return super.ownerOf(tokenId);
    }
}
