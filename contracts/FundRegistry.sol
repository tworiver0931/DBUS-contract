// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.9;
pragma abicoder v2;


import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "contracts/DTicket.sol";

// 펀드를 생성, 업데이트하고 정보를 가지고 올 수 있는 컨트랙트트

contract FundRegistry is ERC1155Holder, Ownable {
    DTicket token;
    uint96 public fundCount = 1;
    constructor(DTicket _token, address initialOwner) Ownable(initialOwner) {
        token = _token;
    }
    struct Fund {
        uint96 id;
        address owner; // 정보 변경할 수 있는 owenr 주소
        uint48 createdAt;
        uint48 updatedAt;
        address payee; // 토큰 수취인 주소
        uint256 threshold; // 펀딩 임계 토큰량
        uint256 donationAmount; // 현재 펀딩된 토큰량
        bool isEnd; // 펀딩이 끝났는지
        // 펀딩(노선)의 메타데이터도 추가해야함
    }

    struct Donation {
        address user;
        uint96 fundId;
        uint256 amount;
    }


    mapping(uint96 => Fund) public funds;
    mapping(uint96 => address[]) public fundUsers;
    mapping(uint96 => mapping(address => Donation[])) public fundDonations;



    event FundCreated(
        uint96 indexed id,
        address owner, 
        address payee, 
        uint256 indexed threshold, 
        uint256 indexed amount, 
        bool isEnd,
        uint time
    );
    event FundUpdated(
        uint96 indexed id, 
        address owner, 
        address payee, 
        uint256 indexed threshold, 
        uint256 indexed amount, 
        bool isEnd, 
        uint time
    );
    /// @notice Emitted when a donation has been made
    event FundCompletion(
        uint96 indexed FundId,
        uint256 donationAmount,
        uint256 time
    );
    

    function defaultMintToOwner(uint256 _amount) public onlyOwner {
        token.mint(owner(), 0, _amount, "0x0" ); //0번 토큰을 funding한 만큼 nft를 전송함.
    }

    function createFund(
        address _owner,
        address _payee,
        uint256 _threshold
    ) external  onlyOwner{
        uint96 _id = fundCount;
        funds[_id] = Fund(
            _id, 
            _owner, 
            uint48(block.timestamp), 
            uint48(block.timestamp), 
            _payee,
            _threshold,
            0,
            false
        );

        // event
        emit FundCreated(_id, _owner, _payee, _threshold, 0, false, block.timestamp);
        
        fundCount += 1;
    }

    function createDonation(
        address _user,
        uint96 _fundId,
        uint256 _amount
    ) private {

        require(token.balanceOf(_user, 0) > _amount, "token amount of user not sufficient" );
        require(token.isApprovedForAll(_user, address(this) ), "token allowance shortage");
        token.safeTransferFrom(_user, address(this), 0, _amount, "0x0");
        

        Donation memory newDonation = Donation(
            _user,
            _fundId,
            _amount
        );
        fundDonations[_fundId][_user].push(newDonation);
        funds[_fundId].donationAmount = funds[_fundId].donationAmount + _amount;

        address[] storage _fundUsers = fundUsers[_fundId];

        bool isAdd = true;
        for (uint96 i = 0; i < _fundUsers.length; i++){
            if (_fundUsers[i] == _user){
                isAdd = false;
                break;
            }
        }
        if (isAdd){
            _fundUsers.push(_user);
        }

    }

    function donate(
        address _user,
        uint96 _fundId,
        uint256 _amount
    ) external onlyOwner {
        // Create new donation
        createDonation(_user, _fundId, _amount);
        validateFunds(_fundId);
    }

    function validateFunds(uint96 _fundIdx) private {        
        if(funds[_fundIdx].threshold < funds[_fundIdx].donationAmount) { //임계량을 넘었는지 체크한다.
            token.safeTransferFrom(address(this), getFundPayee(_fundIdx), 0, funds[_fundIdx].donationAmount, "0x0"); //돈을 전송한다.
            emit FundCompletion(
                _fundIdx,
                funds[_fundIdx].donationAmount,
                block.timestamp
            );
            funds[_fundIdx].isEnd = true; //모금이 완료되었음을 표기한다.
            mintDTiket(_fundIdx, 1000); //모금이 완료되면 도네이트한 사람들에게 해당 금액의 NFT를 전송한다.
        }


        
    }

    function mintDTiket(uint96 _fundId, uint96 totalTicket) private  {
        uint256 donationAmount = funds[_fundId].donationAmount;
        address[] memory userAddresses = fundUsers[_fundId]; //모금이 완료된 펀드에 투자한 사람들을 긁어와서
        uint256 userTotal;
        
        for (uint96 j = 0; j < userAddresses.length; j++){ //각 유저에게 전송
                userTotal= 0;
                for (uint96 k = 0; k < fundDonations[_fundId][userAddresses[j]].length; k++){
                        userTotal += fundDonations[_fundId][userAddresses[j]][k].amount;
                } 
                token.mint(userAddresses[j], _fundId, (userTotal * totalTicket) / donationAmount, "0x0" ); //0번 토큰을 funding한 만큼 nft를 전송함.
        }
        
    }

    function updateFund(
        uint96 _id,
        address _owner,
        address _payee,
        uint256 _threshold
    ) external {
        Fund memory _fund = funds[_id];
        require(msg.sender == _fund.owner, "Fund Update not authorized");
        funds[_id] = Fund(
            _id, 
            _owner, 
            _fund.createdAt, 
            uint48(block.timestamp), 
            _payee, 
            _threshold, 
            _fund.donationAmount,
            _fund.isEnd
        );
        emit FundUpdated(_id, _owner, _payee, _threshold, _fund.donationAmount, _fund.isEnd, block.timestamp);
    }
    
    function getAllFunds() external view returns (Fund[] memory){
        return getFunds(0, fundCount);
    }

    function getFunds(uint96 _startId, uint96 _endId) public view returns (Fund[] memory){
        require(_endId <= fundCount, "Must be _endId <= fundCount");
        require(_startId <= _endId, "Must be _startId <= _endId");
        Fund[] memory fundList = new Fund[](_endId - _startId);
        for (uint96 i = _startId; i < _endId; i++){
            fundList[i - _startId] = funds[i];
        }
        return fundList;
    }
    
    function getFundPayee(uint96 _id) public view returns (address){
        require(_id < fundCount, "Must be _id < fundCount");
        return funds[_id].payee;
    }


}