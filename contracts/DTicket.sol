// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DTicket is ERC1155, ERC1155Burnable, Ownable {
    constructor()
        ERC1155(
            'ipfs://QmRosEA8anXta7r1QESj67EYqS9knHTJfpASqzP7XQMFU3/{id}.json'
        )
    {}
    string private baseURI;

    
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

    function setURI(string memory _newuri) public onlyOwner {
        _setURI(_newuri);
    }
}