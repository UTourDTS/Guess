pragma solidity ^0.4.24;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";


contract ProductFactory is Ownable {

    using SafeMath for uint256;

    event NewProduct(uint256 productId, string _name, string _nameEn, string _discription, string _discEn, uint256 price);

    uint256 private randomDigits = 4;
    uint256 private randomModulus = 10 ** randomDigits;
    uint256 private nonce;

    struct Product {
        string name;
        string nameEn;
        string disc;
        string discEn;
        uint256 price;
        uint256 guessPrice;
        uint256 prcnt;
    }

    Product[] public products;
    mapping (uint256 => address) public productToOwner;
    mapping (address => uint256) public ownerProductCount;

    function createProduct(string _name, string _nameEn, string _discription, string _discEn, uint256 _price, uint256 _prcnt) public {
        // require(ownerProductCount[msg.sender] == 0);
        uint256 rand = _generateRandom(randomModulus);
        uint256 p = _price.mul(rand).div(randomModulus);
        _createProduct(_name, _nameEn, _discription, _discEn, _price, p, _prcnt);
    }

    function _createProduct(string _name, string _nameEn, string _discription, string _discEn, uint256 _price, uint256 _guessPrice, uint256 _prcnt) internal {
        uint256 id = products.push(Product(_name, _nameEn, _discription, _discEn, _price, _guessPrice, _prcnt)) - 1;
        productToOwner[id] = msg.sender;
        ownerProductCount[msg.sender]++;
        emit NewProduct(id, _name, _nameEn, _discription, _discEn, _price);
    }

    function _generateRandom(uint256 _modulus) private returns (uint256) {
        nonce++;
        uint256 rand = uint256(keccak256(abi.encodePacked(now, msg.sender, nonce)));
        return rand % _modulus;
    }

    function _toBytes(uint256 x) private pure returns (bytes b) {
        b = new bytes(32);
        assembly { mstore(add(b, 32), x) }
    }
}
