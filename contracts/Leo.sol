// SPDX-License-Identifier: MIT
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "erc721a/contracts/ERC721A.sol";
import "erc721a/contracts/extensions/ERC721AOwnersExplicit.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * 需求:
 * 1. 盲盒
 * 2. 白名單 (merkle tree)
 * 3. 荷蘭拍
 * 4. 公開拍
 * 5. 開發者保留
 *
 * 安全性:
 * 1. 避免合約調用
 *
 * 流程：
 * dev mint -> auction mint -> whitelist -> public
 */

contract Leo is Ownable, ERC721A, ERC721AOwnersExplicit, ReentrancyGuard {
    using SafeMath for uint256;
    uint256 immutable maxPerMintSize;
    uint256 immutable totalSize;
    uint256 immutable devMintSize;
    uint256 immutable auctionAndDevMintSize;
    string public merkleRoot;
    bool private _isReveal = true;
    string private _baseTokenURI;

    struct SaleConfig {
        uint64 publicPrice;
        uint32 publicStartTime;
        uint64 whitePrice;
        uint32 auctionStartTime;
    }

    SaleConfig public saleConfig;

    constructor(
        uint256 _maxPerMintSize,
        uint256 _totalSize,
        uint256 _devMintSize,
        uint256 _auctionAndDevMintSize,
        string memory baseTokenURI
    ) ERC721A("LeoWang", "LEOWANG") {
        maxPerMintSize = _maxPerMintSize;
        totalSize = _totalSize;
        devMintSize = _devMintSize;
        auctionAndDevMintSize = _auctionAndDevMintSize;
        _baseTokenURI = baseTokenURI;

        require(
            totalSize >= auctionAndDevMintSize,
            "totalSize need to larger than auctionAndDevMintSize"
        );
    }

    modifier callerIsUser() {
        require(
            tx.origin == msg.sender,
            "The caller need to user, not contract"
        );
        _;
    }

    function devMint(uint256 quantity) external onlyOwner {
        require(
            totalSupply() + quantity <= totalSize,
            "too many already minted before dev mint"
        );
        require(
            _numberMinted(msg.sender).add(quantity) <= devMintSize,
            "too many dev mint"
        );
        require(
            quantity % maxPerMintSize == 0,
            "dev mint can only Mint maxPerMintSize multiples"
        );
        _safeMint(msg.sender, quantity);
    }

    function auctionMint(uint256 quantity) external payable callerIsUser {
        uint256 startTime = uint256(saleConfig.auctionStartTime);

        require(
            startTime != 0 && block.timestamp >= startTime,
            "sale has not start yet"
        );
        require(
            _numberMinted(msg.sender).add(quantity) <= maxPerMintSize,
            "can not mint this quantity"
        );
        require(
            totalSupply().add(quantity) <= auctionAndDevMintSize,
            "not enough remaining reserved for auction to support desired mint amount"
        );
        uint256 totalPrice = getAuctionPrice(startTime).mul(quantity);
        _safeMint(msg.sender, quantity);
        refundIfOver(totalPrice);
    }

    function refundIfOver(uint256 price) private {
        require(msg.value >= price, "need to send more ETH.");
        if (msg.value > price) {
            payable(msg.sender).transfer(msg.value - price);
        }
    }
    
    function endAuctionAndSetupNonAuctionSaleInfo (uint64 publicPriceWei, uint32 publicStartTime,uint64 whitePriceWei) external onlyOwner{
        saleConfig = SaleConfig(
            publicPriceWei,
            publicStartTime,
            whitePriceWei,
            0
        );
    }

    uint256 public constant AUCTION_START_PRICE = 0.1 ether;
    uint256 public constant AUCTION_END_PRICE = 0.05 ether;
    uint256 public constant AUCTION_TOTAL_TIME = 30 minutes;
    uint256 public constant AUCTION_DROP_TIME = 6 minutes;
    uint256 public constant AUCTION_DROP_PER_STEP =
        (AUCTION_START_PRICE - AUCTION_END_PRICE) /
            (AUCTION_TOTAL_TIME / AUCTION_DROP_TIME);

    function setAuctionStartTime (uint32 timestamp) external onlyOwner {
        saleConfig.auctionStartTime = timestamp;
    }

    function getAuctionPrice(uint256 startTime) public view returns (uint256) {
        if (block.timestamp < startTime) {
            return AUCTION_START_PRICE;
        }

        if (block.timestamp - startTime >= AUCTION_TOTAL_TIME) {
            return AUCTION_END_PRICE;
        } else {
            uint256 steps = (block.timestamp - startTime) / AUCTION_DROP_TIME;
            return AUCTION_START_PRICE - (steps * AUCTION_DROP_PER_STEP);
        }
    }

    function setReveal(bool _reveal) external onlyOwner {
        _isReveal = _reveal;
    }

    function setTokenURI(string calldata _tokenURI) external onlyOwner {
        _baseTokenURI = _tokenURI;
    }

    function _baseURI() internal view virtual override returns(string memory) {
        return _baseTokenURI;
    }

    function getTokenURI(uint tokenId) external view returns(string memory){
        if(_isReveal){
            return _baseTokenURI;
        } else{
            return tokenURI(tokenId);
        }
    }

    function withdraw() external onlyOwner nonReentrant{
        (bool success,) = msg.sender.call{value:address(this).balance}("");
        require(success,"Transfer failed.");
    }
}
