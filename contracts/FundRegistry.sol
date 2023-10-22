// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.9;
pragma abicoder v2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

// 펀드를 생성, 업데이트하고 정보를 가지고 올 수 있는 컨트랙트트

contract FundRegistry is ERC1155Holder {
    ERC1155 token;
    uint256 totalInvestmentAmount;
    uint96 public fundCount;
    constructor(ERC1155 _token) {
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
        uint256 investmentAmount; //현재 QF된 토큰량.
        bool isEnd; // 펀딩이 끝났는지
        // 펀딩(노선)의 메타데이터도 추가해야함
    }

    struct Donation {
        address user;
        uint96 fundId;
        uint256 amount;
    }

    struct Investment {
        address user;
        uint256 amount;
    }

    mapping(uint96 => Fund) public funds;
    mapping(uint96 => address[]) public fundUsers;
    mapping(uint96 => mapping(address => Donation[])) public fundDonations;

    //user -> investment객체로 가는 매핑정보 저장.
    mapping (address => Investment[]) public fundInvestment;

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


    //investment매핑에 정보를 저장, 돈을 fundRegistry CA로 전송.
    function createInvestment(
        address _user,
        int256 _amount
    ) private {

        require(token.balanceOf(_user, 0) > _amount, "token amount of user not sufficient" );
        require(token.isApprovedForAll(_user, address(this)), "token allowance shortage");
        token.safeTransferFrom(_user, address(this), 0, _amount, "0x0");
        

        Investment memory newInvestment = Investment(
            _user,
            _amount
        );
        fundInvestment[_user].push(newInvestment);
    }


    function createDonation(
        address _user,
        uint96 _fundId,
        uint256 _amount,
        bool _isTiketUser
    ) private {

        require(token.balanceOf(_user, 0) > _amount, "token amount of user not sufficient" );
        require(token.isApprovedForAll(_user, address(this)), "token allowance shortage");
        token.safeTransferFrom(_user, address(this), 0, _amount, "0x0");
        

        Donation memory newDonation = Donation(
            _user,
            _fundId,
            _amount,
            _isTiketUser
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

    function invest(
        address _user,
        uint256 _amount
    ) external {
        createDonation(_user, _fundId, _amount);
        QF();

        validateFunds();
    }

    function donate(
        address _user,
        uint96 _fundId,
        uint256 _amount
    ) external {
        // Create new donation
        createDonation(_user, _fundId, _amount, _isTicketUser);
        
        // QF 계산
        

        

        // THRESHOLD 검증
        
        
    validateFunds();

    }

    function validateFunds() private {
        for (uint96 fundIdx = 0; fundIdx < fundCount; fundIdx++) {
            if(funds[fundIdx].threshold < funds[fundIdx].totalAmount) { //임계량을 넘었는지 체크한다.
                token.safeTransferFrom(address(this), getFundPayee(fundIdx), 0, funds[fundIdx].totalAmount, "0x0"); //돈을 전송한다.
                emit FundCompletion(
                    fundIdx,
                    funds[fundIdx].totalAmount,
                    block.timestamp
                );
                funds[fundIdx].isEnd = true; //모금이 완료되었음을 표기한다.
                funds[fundIdx].totalAmount = 0;
                mintDTiket(fundIdx); //모금이 완료되면 도네이트한 사람들에게 해당 금액의 NFT를 전송한다.
            }


        }
    }

    


    function mintDTiket(uint96 _fundId) public {
        address[] memory userAddresses = fundUsers[_fundId];
        uint256 totalTicketFunding;
        for (uint96 j = 0; j < userAddresses.length; j++){

                for (uint96 k = 0; k < fundDonations[_fundId][userAddresses[j]].length; k++){
                    if(fundDonations[_fundId][userAddresses[j]][k].isTiketUser == true) { //소량 투자자에 수요만 고려할 수 있도록
                        totalTicketFunding += fundDonations[_fundId][userAddresses[j]][k].amount;
                    }
                }
                token.safeTransferFrom(address(this), userAddresses[j], _fundId, totalTicketFunding, "0x0" ); //0번 토큰을 funding한 만큼 nft를 전송함.
        }
        
    }
    
    //invest를 분배하는 목적
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
            funds[i].totalAmount = (ratio[i] * token.balanceOf(address(this), 0)) / totalOfRatio;
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

    function giveIncentive(uint96 _fundId, uint256 totalIncentive) public {
        require(msg.sender == funds[_fundId].owner, "only owner can give incentive");
        uint256 totalFunding;
        uint256[] memory fundingAmount;
        address[] memory userAddresses = fundUsers[_fundId];
        for (uint96 userIdx = 0; userIdx < userAddresses.length; userIdx++){
            uint256 userAmount;
            for (uint96 donationIdx = 0; donationIdx < fundDonations[_fundId][userAddresses[userIdx]].length; donationIdx++){
                if(fundDonations[_fundId][userAddresses[userIdx]][donationIdx].isTiketUser == false) { //대량 투자자에 수요만 고려할 수 있도록
                    userAmount += fundDonations[_fundId][userAddresses[userIdx]][donationIdx].amount;
                }
            }
            fundingAmount[userIdx] = userAmount;
            totalFunding += userAmount;
        }
        for(uint96 userIdx =0; userIdx < userAddresses.length; userIdx++) {
            if(fundingAmount[userIdx] != 0) {
                token.safeTransferFrom(address(this), userAddresses[userIdx], 0, totalIncentive * fundingAmount[userIdx] / totalFunding, "0x0");
            }
            
        }
            
    }
}