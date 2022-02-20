// SPDX-License-Identifier: MIT
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "erc721a/contracts/ERC721A.sol";
import "erc721a/contracts/extensions/ERC721AOwnersExplicit.sol";

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
    uint256 immutable maxPerMintSize;
    uint256 immutable totalSize;
    uint256 immutable devMintSize;
    uint256 immutable auctionAndDevMintSize;
    string private _baseURI;
    string public merkleRoot;

    constructor(
        uint256 _maxPerMintSize,
        uint256 _totalSize,
        uint256 _devMintSize,
        uint256 _auctionAndDevMintSize
    ) ERC721A("LeoWang", "LEOWANG") {
        maxPerMintSize = _maxPerMintSize;
        totalSize = _totalSize;
        devMintSize = _devMintSize;
        auctionAndDevMintSize = _auctionAndDevMintSize;
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
      require(totalSupply() + quantity <= totalSize, "too many already minted before dev mint");
      require(quantity <= devMintSize,"too many dev mint");
      require(quantity % maxPerMintSize == 0, "dev mint can only Mint maxPerMintSize multiples");
      _safeMint((msg.sender, quantity);
      
    }

    uint256 public constant AUCTION_START_PRICE = 0.1 ether;
    uint256 public constant AUCTION_END_PRICE = 0.05 ether;
    uint256 public constant AUCTION_TOTAL_TIME = 30 minutes;
    uint256 public constant AUCTION_DROP_TIME = 6 minutes;
    uint256 public constant AUCTION_DROP_PER_STEP =
        (AUCTION_START_PRICE - AUCTION_END_PRICE) /
            (AUCTION_TOTAL_TIME / AUCTION_DROP_TIME);
}
