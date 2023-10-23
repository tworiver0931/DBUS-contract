// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract DTicket is ERC1155, Ownable {
    constructor(address initialOwner)
        ERC1155("https://ipfs.io/ipfs/QmTysNoXEoXtYzUazX1f26bWDU3bP5pgkUwLuewGZeANLX/{id}.json")
        Ownable(initialOwner)
    {}

    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    function mint(address account, uint256 id, uint256 amount, bytes memory data)
        public
        onlyOwner
    {
        _mint(account, id, amount, data);
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        public
        onlyOwner
    {
        _mintBatch(to, ids, amounts, data);
    }

    function uri(uint256 _tokenid) override public pure returns (string memory) {
        return string(
            abi.encodePacked(
                "https://ipfs.io/ipfs/QmTysNoXEoXtYzUazX1f26bWDU3bP5pgkUwLuewGZeANLX/",
                Strings.toString(_tokenid),".json"
            )
        );
    }
}