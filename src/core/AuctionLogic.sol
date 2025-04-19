// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {Errors} from "src/util/Errors.sol";
import {Pausable} from "src/util/Pausable.sol";
import {WDTOKEN, SwapToken} from "src/util/AuctionToken.sol";

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

contract AuctionLogic is Pausable, UUPSUpgradeable, Initializable, ReentrancyGuard {
    enum State {
        None,
        Listed, // 경매 등록됨
        Inprogress, // 경매 진행중
        Completed, // 경매 완료됨
        Canceled // 경매 취소됨

    }

    struct Auction {
        uint256 auctionId; // 경매 고유 ID
        address payable owner; // 경매 token 소유자
        address tokenAddress; // 경매 token address
        uint256 tokenId; // NFT ID
        uint256 startTime; // 경매 시작 시간
        uint256 endTime; // 경매 종료 시간
        uint256 openPrice; // 경매 시작가
        address highestBidder; // 높은 입찰가
        uint256 highestPrice; // 높은 입찰 주소
        State status;
    }

    /// 여러개의 경매를 경매 id를 통해 만든 mapping
    mapping(uint256 => Auction) private auctionList;

    /// 경매가 실패 한 후 돌려줄 금액
    mapping(address => uint256) private bidReturn;

    // (NFT 컨트랙트 주소, 토큰 ID) => 경매 여부
    mapping(address => mapping(uint256 => bool)) public isListed;
    /// AuctionProxy를 만든 owner
    address private auctionOwner;

    /// 경매 개수를 세는 counter
    uint256 private auctionCounter = 0;

    /// 경매 진행 시간
    uint256 public constant ACUTION_TIME = 3 days;

    /// token 주소
    WDTOKEN public token;

    /// swap contract
    SwapToken public swap;

    /// auctionList에 listed 된 state이어만 함
    modifier onlyInproress(uint256 Id) {
        if (auctionList[Id].status != State.Inprogress) {
            revert Errors.NotInprogress();
        }
        _;
    }

    /// msg sender가 nft owner
    modifier onlyNftOwner(uint256 Id) {
        if (auctionList[Id].owner != msg.sender) {
            revert Errors.NotNFTOwner();
        }
        _;
    }

    /// state = completed
    modifier onlyCompleted(uint256 Id) {
        if (auctionList[Id].status != State.Completed) {
            revert Errors.NotCompleted();
        }
        _;
    }

    /// only auction contract owner
    modifier onlyAuctionOwner() {
        if (msg.sender != auctionOwner) {
            revert Errors.NotAuctionOwner(msg.sender);
        }
        _;
    }

    /// 상태가 변환될 수 있는 modifier
    modifier transitionState(uint256 Id) {
        if ((auctionList[Id].startTime < block.timestamp) && (auctionList[Id].status == State.Listed)) {
            nextState(Id);
        }
        if (
            (auctionList[Id].startTime + ACUTION_TIME < block.timestamp) && (auctionList[Id].status == State.Inprogress)
        ) {
            nextState(Id);
        }
        _;
    }

    /// Logic 서버가 초기화 되지 않도록 하는 함수
    constructor() {
        _disableInitializers();
    }

    /// proxy 서버의 owner를 딱 한번 초기화 시키는 함수
    function intializeV2(address _swap) external reinitializer(2) onlyProxy {
        auctionOwner = msg.sender;
        swap = SwapToken(payable(_swap));
        token = WDTOKEN(swap.token());
    }

    /// bidReturn getter func
    function getBidreturn() external view onlyProxy returns (uint256) {
        return (bidReturn[msg.sender]);
    }

    function getTokenBalance() external view onlyProxy returns (uint256) {
        return (token.balanceOf(msg.sender));
    }
    /// auction state getter func

    function getState(uint256 Id) external view onlyProxy returns (State) {
        return (auctionList[Id].status);
    }

    function getauctionOwner() external view onlyProxy returns (address) {
        return (auctionOwner);
    }

    /// auction list getter func
    function getAuctioniList(uint256 Id) external view onlyProxy returns (Auction memory) {
        require(Id < auctionCounter, "Id < acutionCounter");
        return auctionList[Id];
    }

    /// 다음 state 이동
    function nextState(uint256 Id) private whenNotPaused {
        auctionList[Id].status = State(uint8(auctionList[Id].status) + 1);
    }

    /// token이 erc721를 따르는지 확인
    function isERC721(address tokenAddress) private view returns (bool) {
        IERC165 tokens = IERC165(tokenAddress);

        try tokens.supportsInterface(0x80ac58cd) returns (bool isSupported) {
            return isSupported;
        } catch {
            return false;
        }
    }

    /// @notice 경매를 만드는 함수
    /// @dev msg sender와 nft 소유주 일치 해야 함  emergency stop 적용
    /// @param _tokenAddress nft를 만든 contract addr
    /// @param _tokenId  nft id
    /// @param _startTime 경매 시작 시간 현재 블록보다 커야 함
    /// @param _openPrice 경매 시작가
    /// @return auctionId 경매 Id

    function listingAuction(address _tokenAddress, uint256 _tokenId, uint256 _startTime, uint256 _openPrice)
        external
        whenNotPaused
        onlyProxy
        returns (uint256 auctionId)
    {
        require(_startTime > block.timestamp, "Start time is faster than block time");
        require(isERC721(_tokenAddress), "Only ERC721 Token");
        IERC721 nftToken = IERC721(_tokenAddress);
        require(nftToken.getApproved(_tokenId) == address(this), "NFT must approve to auction");
        if (nftToken.ownerOf(_tokenId) != msg.sender) {
            revert Errors.NotNFTOwner();
        }
        require(isListed[_tokenAddress][_tokenId] == false, "Already Listed NFT");
        auctionList[auctionCounter] = Auction({
            auctionId: auctionCounter,
            owner: payable(msg.sender),
            tokenAddress: _tokenAddress,
            tokenId: _tokenId,
            startTime: _startTime,
            openPrice: _openPrice,
            endTime: _startTime + ACUTION_TIME,
            highestBidder: address(0),
            highestPrice: _openPrice,
            status: State.Listed
        });
        isListed[_tokenAddress][_tokenId] = true; // list에 올라갔는지 체크
        auctionCounter += 1;
        return (auctionCounter - 1);
    }

    /// @notice multicall로 경매 등록
    /// @dev struct 만들 여러 인자를 받아 multicall
    /// @return  auction에 등록된 id 배열 반환
    function multiList(
        address[] memory tokenAddress,
        uint256[] memory tokenId,
        uint256[] memory startTime,
        uint256[] memory openPrice
    ) external whenNotPaused onlyProxy returns (uint256[] memory) {
        uint256 arrLen = tokenAddress.length;
        if ((arrLen != tokenId.length) || (arrLen != startTime.length) || (arrLen != openPrice.length)) {
            revert Errors.NotEqualEachArgument();
        }
        bytes[] memory callData = new bytes[](arrLen);
        for (uint256 i = 0; i < arrLen; i++) {
            callData[i] = abi.encodeWithSignature(
                "listingAuction(address,uint256,uint256,uint256)",
                tokenAddress[i],
                tokenId[i],
                startTime[i],
                openPrice[i]
            );
        }
        uint256[] memory tokenIds = new uint256[](arrLen);
        bytes[] memory results;
        (bool success, bytes memory data) =
            address(this).delegatecall(abi.encodeWithSignature("multicall(bytes[])", callData));
        if (!success) revert Errors.FailDelegateCall();

        results = abi.decode(data, (bytes[]));
        for (uint256 i = 0; i < results.length; i++) {
            tokenIds[i] = abi.decode(results[i], (uint256));
        }
        return (tokenIds);
    }

    /// @notice 경매 입찰을 받는다. 현재 최고가 보다 커야한다.
    /// @dev bidder가 0이면 안된다. 그전 가격의 값은 bid return에 들어간다. emergency stop
    /// @param Id auctionList의 키 값
    function offerBid(uint256 Id) external payable whenNotPaused onlyProxy transitionState(Id) onlyInproress(Id) {
        Auction memory info = auctionList[Id];
        require(info.highestPrice < msg.value, "Must Bid over the Highest Price");
        if (info.highestBidder != address(0)) {
            bidReturn[info.highestBidder] += info.highestPrice;
        }
        auctionList[Id].highestPrice = msg.value;
        auctionList[Id].highestBidder = msg.sender;
        // 입찰을 한다면 0.01 % token을 준다
        token.transfer(msg.sender, swap.getETHPriceInToken(msg.value / 10000));
    }

    /// @notice 경매 입찰을 받는다. 현재 최고가 보다 커야한다.
    /// @dev offerbid 함수와 다른점으로 amount 변수를 추가
    /// @param Id auctionList의 키 값
    /// @param amount msg.value 대신 보낼 값
    function offerBids(uint256 Id, uint256 amount)
        external
        payable
        whenNotPaused
        onlyProxy
        transitionState(Id)
        onlyInproress(Id)
    {
        Auction memory info = auctionList[Id];
        require(info.highestPrice < amount, "Must Bid over the Highest Price");
        require(amount < msg.value, "Msg value is low than amount");
        if (info.highestBidder != address(0)) {
            bidReturn[info.highestBidder] += info.highestPrice;
        }
        auctionList[Id].highestPrice = amount;
        auctionList[Id].highestBidder = msg.sender;
        // 입찰을 한다면 0.01 % token을 준다
        token.transfer(msg.sender, swap.getETHPriceInToken(amount / 10000));
    }

    /// @notice multicall 입찰
    /// @dev mulitcall로 보낸다 중간에 에러나면 revert
    /// @param ids auctionList의 키 값
    /// @param bids bid array 대신 보낼 값
    function multiOffer(uint256[] memory ids, uint256[] memory bids)
        external
        payable
        onlyProxy
        whenNotPaused
        returns (bool)
    {
        if (ids.length != bids.length) revert Errors.NotEqualEachArgument();
        uint256 bidsamount;
        uint256 idlength = ids.length;
        bytes[] memory callData = new bytes[](idlength);
        for (uint256 i = 0; i < idlength; i++) {
            callData[i] = abi.encodeWithSignature("offerBids(uint256,uint256)", ids[i], bids[i]);
            bidsamount += bids[i];
        }
        require(bidsamount == msg.value, "Not same bids, value");

        (bool success,) = address(this).delegatecall(abi.encodeWithSignature("multicall(bytes[])", callData));

        if (!success) revert Errors.FailDelegateCall();
        return (success);
    }

    /// @notice 경매 소유자가 경매를 취소하는 함수
    /// @dev 취소가 가능한 경매 상태는 listed일 때만
    ///      address(0) 이라는 건 아직 입찰이 없다는 뜻
    /// @param Id auctionList의 키 값
    function cancelAuction(uint256 Id) external onlyProxy transitionState(Id) onlyNftOwner(Id) {
        Auction memory info = auctionList[Id];
        require(info.status == State.Listed, "Only Cancel Listed state");
        auctionList[Id].status = State.Canceled;
    }

    /// @notice Bidreturn 에 있는 돈을 인출하는 함수
    /// @dev nft 구매한사람이 직접 달라고 하는거 pull 방식
    function withdrawBid() external onlyProxy {
        uint256 amount = bidReturn[msg.sender];
        if (amount > 0) {
            bidReturn[msg.sender] = 0;
            bool success = payable(msg.sender).send(amount);
            if (!success) {
                revert Errors.transferError();
            }
        }
    }

    /// @notice 경매가 끝난 후 낙찰자가 NFT 받고, 생성자는 돈을 받는
    /// @dev pull 방식 nft가 거래서에 approve 되어있어야 함 두개의 과정이 같이 실행되어야 해서 atomic하게 실행
    /// @param Id auctionList의 키 값
    /// @return bool 성공 여부
    function claim(uint256 Id) external onlyProxy nonReentrant transitionState(Id) onlyCompleted(Id) returns (bool) {
        Auction memory info = auctionList[Id];
        IERC721 nftToken = IERC721(info.tokenAddress);

        require(msg.sender == info.highestBidder, "Must HighestBidder");
        require(nftToken.getApproved(info.tokenId) == address(this), "NFT must approve to auction"); // 토큰의 id가 Auction contract에게 approve 되어 있어야 함

        if (info.owner == info.highestBidder) return (false); // owner = bidder 같을 경우 false
        nftToken.safeTransferFrom(info.owner, info.highestBidder, info.tokenId); // 토큰 bidder가 ca일 경우 onerc721Received 함수 있어야 함 없으면 터짐

        /// auction이 수수료 0.1% 가져감... ㅎㅎ 이돈은 좋은곳에 쓰일예정
        uint256 fee = info.highestPrice / 1000;
        (bool success,) = info.owner.call{value: info.highestPrice - fee}("");
        if (!success) {
            revert Errors.transferError();
        }
        swap.swapETHToken{value: fee}();
        // 입찰 완료 되면 총 금액의
        return (true);
    }

    /// @notice stop 된 경우에만 실행, 실행 중인 경매 입찰자에게 돈 환불
    /// @dev msg sender는 최고 입찰자, 그리고 state는 진행중이어야 함
    /// @param Id auctionList의 키 값
    function emergencyWithdraw(uint256 Id) external onlyProxy whenPaused {
        Auction memory info = auctionList[Id];

        require(msg.sender == info.highestBidder, "Must HighestBidder");
        if (info.status == State.Inprogress) {
            // 진행중인 경매일 때 최고 비드 에게 돈 환불
            auctionList[Id].status = State.Canceled;
            bool success = payable(info.highestBidder).send(info.highestPrice);
            if (!success) {
                revert Errors.transferError();
            }
        }
    }

    /// @notice 긴급상황에 contract로 정지
    /// @dev 경매 등록, 입찰하는 함수들은 정지 됨
    function stopContract() external override onlyProxy onlyAuctionOwner {
        _paused = true;
        emit Paused(msg.sender);
    }

    /// @notice Stop된 contract resume
    /// @dev stop된 상태에서 실행
    function resumeContract() external override onlyProxy onlyAuctionOwner whenPaused {
        _paused = false;
        emit Unpaused(msg.sender);
    }

    /// @notice multicall 로 여러 함수 하나의 transaction에 실행
    /// @dev delegatecall로 여러 함수 실행
    function multicall(bytes[] calldata data) external payable returns (bytes[] memory results) {
        bool success;

        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            (success, results[i]) = address(this).delegatecall(data[i]);
            if (!success) revert Errors.FailDelegateCall();
        }
        return results;
    }

    function _authorizeUpgrade(address newImplementation) internal virtual override onlyProxy {}

    receive() external payable {}
}
