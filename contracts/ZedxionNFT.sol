//Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ZedxionNFT is ERC721Enumerable, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    address busdAddress = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
    address tbusdAddress = 0xB0D0eDB26B7728b97Ef6726dAc6FB7a43d6043E1;
    address usdtAddress = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    IERC20 busd = IERC20(busdAddress);
    IERC20 tbusd = IERC20(tbusdAddress);

    address public creatorAddress = 0xA0B073bE8799A742407aB04eC02b2BfD860a1B71;

    event NewBaseURI(address base_uri);

    // Optional mapping for owner, tokenId, tokenURI
    struct NFT {
        uint256 tokenId;
        string tokenURI;
        uint256 price;
        uint256 pi;
        bool sale;
        string saleMethod;
        string auctionDay;
    }

    mapping(uint256 => NFT) public NFTs;

    struct Bid {
        address account;
        uint256 price;
        string bid_at;
    }

    mapping(uint256 => Bid[]) public Bids;

    constructor() ERC721("ZedxionNFT", "ZNT") {}

    function mintNFT(
        address recipient,
        string memory tokenURI,
        uint256 price,
        uint256 pi,
        bool sale,
        string memory saleMethod,
        string memory auctionDay
    ) public {
        _tokenIds.increment();

        busd.transferFrom(msg.sender, address(this), price * 10**18);
        uint256 newTokenId = _tokenIds.current();
        _safeMint(recipient, newTokenId);

        NFTs[newTokenId] = NFT({
            tokenId: newTokenId,
            tokenURI: tokenURI,
            price: price,
            pi: pi,
            sale: sale,
            saleMethod: saleMethod,
            auctionDay: auctionDay
        });
    }

    // Utils
    function tokensOfOwner(address _owner)
        external
        view
        returns (uint256[] memory)
    {
        uint256 tokenCount = balanceOf(_owner);
        uint256[] memory tokensIds = new uint256[](tokenCount);
        for (uint256 i = 0; i < tokenCount; i++) {
            tokensIds[i] = tokenOfOwnerByIndex(_owner, i);
        }

        return tokensIds;
    }

    function buyNFT(uint256 tokenId, uint256 price) public {
        address _owner = ownerOf(tokenId);
        require(_owner != msg.sender, "It is still your NFT");
        require(
            busd.balanceOf(msg.sender) > price * 10**18,
            "Insuficient funds!"
        );
        _transfer(_owner, msg.sender, tokenId);
        // to davide : royalty
        busd.transferFrom(
            msg.sender,
            creatorAddress,
            ((price * 3) / 100) * 10**18
        );
        // Sale status : false
        // NFTs[tokenId].sale = false;
        // to buyer : price - royalty
        busd.transferFrom(msg.sender, _owner, ((price * 97) / 100) * 10**18);
    }

    function resellNFT(uint256 tokenId) public {
        NFTs[tokenId].sale = true;
        // change the price to add P.I

        NFTs[tokenId].price =
            NFTs[tokenId].price +
            (NFTs[tokenId].price * NFTs[tokenId].pi) /
            100;
    }

    function sendNFT(address _address, uint256 _tokenId) public {
        _transfer(msg.sender, _address, _tokenId);
    }

    function placeBid(
        uint256 _tokenId,
        address _account,
        uint256 _price,
        string memory _bidAt
    ) public {
        Bids[_tokenId].push(Bid(_account, _price, _bidAt));
    }

    function getBid(uint256 _tokenId) public view returns (Bid[] memory) {
        return Bids[_tokenId];
    }

    function auctionDone(uint256 _tokenId) public {
        Bid[] memory bids = Bids[_tokenId];
        address _owner = ownerOf(_tokenId);

        uint256 largest = 0;
        uint256 largest_p;
        uint256 i;

        for (i = 0; i < bids.length; i++) {
            if (bids[i].price > largest) {
                largest = bids[i].price;
                largest_p = i;
            }
        }
        // Sned NFT's ownership to the max value bidded user
        _transfer(_owner, bids[largest_p].account, _tokenId);
        // Refund all the money to each users except max bidder
        for (i = 0; i < bids.length; i++) {
            if (i != largest_p) {
                busd.transferFrom(
                    address(this),
                    bids[largest_p].account,
                    bids[largest_p].price * 10**18
                );
            }
        }
        // Delete the current item from Bids[]
        delete Bids[_tokenId];
        // Set this NFT's saleMethod to fixed
        NFTs[_tokenId].saleMethod = 'fixed';
        // Set the NFT's price to max value
        NFTs[_tokenId].price = bids[largest_p].price;
    }

    // GETTER
    function _totalSupply() internal view returns (uint256) {
        return _tokenIds.current();
    }

    function totalMint() public view returns (uint256) {
        return _totalSupply();
    }

    function getNFT(uint256 _tokenId)
        external
        view
        returns (
            bool,
            string memory,
            uint256,
            string memory,
            string memory
        )
    {
        return (
            NFTs[_tokenId].sale,
            NFTs[_tokenId].tokenURI,
            NFTs[_tokenId].price,
            NFTs[_tokenId].saleMethod,
            NFTs[_tokenId].auctionDay
        );
    }

    function getOwnerOfNFT(uint256 _tokenId) public view returns (address) {
        address _owner = ownerOf(_tokenId);

        return _owner;
    }

    function withdrawAll() public payable onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0);
        _widthdraw(creatorAddress, address(this).balance);
    }

    function _widthdraw(address _address, uint256 _amount) private {
        (bool success, ) = _address.call{value: _amount}("");
        require(success, "Transfer failed.");
    }
}
