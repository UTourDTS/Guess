pragma solidity ^0.4.24;

import "./ProductFactory.sol";


contract ProductHelper is ProductFactory {

    modifier onlyOwnerOf(uint _productId) {
        require(msg.sender == productToOwner[_productId]);
        _;
    }
    
    function getProductsByOwner(address _owner) external view returns(uint256[]) {
        uint256[] memory result = new uint256[](ownerProductCount[_owner]);
        uint256 counter = 0;
        for (uint256 i = 0; i < products.length; i++) {
            if (productToOwner[i] == _owner) {
                result[counter] = i;
                counter++;
            }
        }
        return result;
    }

    function withdraw() external onlyOwner {
        owner.transfer(address(this).balance);
    }
}