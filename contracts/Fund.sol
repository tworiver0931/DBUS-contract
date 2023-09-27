// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.9;
pragma abicoder v2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// 펀드를 생성, 업데이트하고 정보를 가지고 올 수 있는 컨트랙트트

contract FundRegistry {
    uint96 public fundCount;

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
    mapping(uint96 => Donation[]) public fundDonations;
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

    function createDonation(
        address _user,
        uint96 _fundId,
        uint256 _amount
    ) public returns(Donation memory){
        Donation memory newDonation = Donation(
            _user,
            _fundId,
            _amount
        );
        fundDonations[_fundId].push(newDonation);
        return newDonation;
    }

    function createFund(
        address _owner,
        address _payee,
        uint256 _threshold
    ) external  {
        uint96 _id = fundCount;


        // Create a fund
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
        for (uint96 i = _startId; i<_endId; i++){
            fundList[i - _startId] = funds[i];
        }
        return fundList;
    }
    
    function getFundPayee(uint96 _id) public view returns (address){
        require(_id < fundCount, "Must be _id < fundCount");
        return funds[_id].payee;
    }

    function donate(
        address user,
        uint96 fundId,
        uint256 amount
    ) external payable {
        // Create new donation
        Donation memory newDonation = createDonation(user, fundId, amount);

        // QF 계산
        Fund[] memory updatedFundList = calculateQF(newDonation.fundId, newDonation.amount);

        // 업데이트, 검증
    }

    function calculateQF(uint96 _fundId, uint256 _amount) internal view returns (Fund[] memory){
        // 모든 isEnd=false 펀드 정보 불러오기 (펀드 struct에 참여한 유저 정보도 저장)
        // QF 계산 후 업데이트된 펀드 정보 반환
        
    }
}