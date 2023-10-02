// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.9;
pragma abicoder v2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// 펀드를 생성, 업데이트하고 정보를 가지고 올 수 있는 컨트랙트트

contract FundRegistry {
    ERC20 token;
    uint96 public fundCount;
    constructor(ERC20 _token) {
        token = _token;
    }
    struct Fund {
        uint96 id;
        address owner; // 정보 변경할 수 있는 owenr 주소
        uint48 createdAt;
        uint48 updatedAt;
        address payee; // 토큰 수취인 주소
        uint256 threshold; // 펀딩 임계 토큰량
        uint256 totalAmount; // 현재 펀딩된 토큰량
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
    function createDonation(
        address _user,
        uint96 _fundId,
        uint256 _amount
    ) private {
        require(token.balanceOf(_user) > _amount, "token amount of user not sufficient" );
        require(token.allowance(_user, address(this)) > _amount, "token allowance shortage");        
        require(token.transferFrom(_user, address(this), _amount), "token transfer failed");
        

        Donation memory newDonation = Donation(
            _user,
            _fundId,
            _amount
        );
        fundDonations[_fundId][_user].push(newDonation);
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

    function createFund(
        address _owner,
        address _payee,
        uint256 _threshold
    ) external  {
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
            _fund.totalAmount,
            _fund.isEnd
        );
        emit FundUpdated(_id, _owner, _payee, _threshold, _fund.totalAmount, _fund.isEnd, block.timestamp);
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

    function donate(
        address _user,
        uint96 _fundId,
        uint256 _amount
    ) external payable {
        // Create new donation
        createDonation(_user, _fundId, _amount);
        
        // QF 계산
        QF();

        // THRESHOLD 검증
        
        
        for (uint96 fundIdx = 0; fundIdx < fundCount; fundIdx++) {
            if(funds[fundIdx].threshold < funds[fundIdx].totalAmount) { //임계량을 넘었는지 체크한다.
                token.transfer(getFundPayee(fundIdx), funds[fundIdx].totalAmount); //돈을 전송한다.
                emit FundCompletion(
                    fundIdx,
                    funds[fundIdx].totalAmount,
                    block.timestamp
                );
                funds[fundIdx].isEnd = true; //모금이 완료되었음을 표기한다.
                funds[fundIdx].totalAmount = 0;
            }


        }

    }


    function QF() internal {
        // 모든 isEnd=false 펀드 정보 불러오기

        
        // QF formula에 따른 ratio 계산: sum(sqrt(c))**2
        uint256[] memory ratio = new uint256[](fundCount);
        uint256 totalOfRatio;
        for (uint96 i = 0; i < fundCount; i++){
            if(funds[i].isEnd == true) { //isEnd인 상태에서는 고려하지 않음.
                continue;
            }
            uint256 totalOfFund;
            address[] memory userAddresses = fundUsers[i];
            for (uint96 j = 0; j < userAddresses.length; j++){
                uint256 totalOfUser;
                for (uint96 k = 0; k < fundDonations[i][userAddresses[j]].length; k++){
                    totalOfUser += fundDonations[i][userAddresses[j]][k].amount;
                }
                totalOfFund += sqrt(totalOfUser);
            }
            totalOfFund = totalOfFund ** 2;
            ratio[i] = totalOfFund;
            totalOfRatio += totalOfFund;
        }

        // ratio에 따라 각 fund 업데이트
        for(uint96 i = 0; i < fundCount; i++){
            funds[i].totalAmount = (ratio[i] * token.balanceOf(address(this))) / totalOfRatio;
        }
    }

    function sqrt(uint256 x) private pure returns (uint256 y) { //solidity는 float을 지원하지 않기 때문에 다음과 같은 sqrt연산 식을 이용한다.
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}