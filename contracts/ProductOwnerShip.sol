pragma solidity ^0.4.24;

import "./ProductHelper.sol";
import "openzeppelin-solidity/contracts/token/ERC721/ERC721.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";


contract ProductOwnership is ProductHelper, ERC721 {

    using SafeMath for uint256;

    mapping (uint => address) productApprovals;

    function balanceOf(address _owner) public view returns (uint256 _balance) {
        return ownerProductCount[_owner];
    }

    function ownerOf(uint256 _tokenId) public view returns (address _owner) {
        return productToOwner[_tokenId];
    }

    function _transfer(address _from, address _to, uint256 _tokenId) private {
        ownerProductCount[_to] = ownerProductCount[_to].add(1);
        ownerProductCount[msg.sender] = ownerProductCount[msg.sender].sub(1);
        productToOwner[_tokenId] = _to;
        emit Transfer(_from, _to, _tokenId);
    }

    function transfer(address _to, uint256 _tokenId) public onlyOwnerOf(_tokenId) {
        _transfer(msg.sender, _to, _tokenId);
    }

    function approve(address _to, uint256 _tokenId) public onlyOwnerOf(_tokenId) {
        productApprovals[_tokenId] = _to;
        emit Approval(msg.sender, _to, _tokenId);
    }

    function takeOwnership(uint256 _tokenId) public {
        require(productApprovals[_tokenId] == msg.sender);
        address owner = ownerOf(_tokenId);
        _transfer(owner, msg.sender, _tokenId);
    }
}