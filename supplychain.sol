
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SupplyChain {

    enum State { Manufactured, Shipped, Received, Distributed, Wholesaled, Expired }

    struct Batch {
        string batchID;
        string itemName;
        uint manufacturingDate;
        uint expiryDate;
        string productionDetails;
        State state;
        string stateDetails;
        address currentHolder;
    }

    struct Distributor {
        string name;
        string businessRegNumber;
        string phoneNumber;
        bool isRegistered;
    }

    struct Wholesaler {
        string name;
        string businessRegNumber;
        string phoneNumber;
        bool isRegistered;
    }

    address public owner;
    mapping(string => Batch) public batches;
    mapping(address => Distributor) public distributors;
    mapping(address => Wholesaler) public wholesalers;
    address[] public distributorAddresses;
    address[] public wholesalerAddresses;

    event BatchCreated(string batchID, string itemName, uint manufacturingDate, uint expiryDate, string productionDetails, address initialHolder);
    event StateUpdated(string batchID, State state, string stateDetails, address updatedBy);
    event DistributorRegistered(address distributor, string name, string businessRegNumber, string phoneNumber);
    event WholesalerRegistered(address wholesaler, string name, string businessRegNumber, string phoneNumber);
    event Notification(string batchID, string itemName, address notifiedTo);
    event BatchShipped(string batchID, address from, address to);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }

    modifier onlyCurrentHolder(string memory _batchID) {
        require(batches[_batchID].currentHolder == msg.sender, "Only the current holder can perform this action");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function registerDistributor(address _distributor, string memory _name, string memory _businessRegNumber, string memory _phoneNumber) public onlyOwner {
        require(!distributors[_distributor].isRegistered, "Distributor is already registered");
        distributors[_distributor] = Distributor({
            name: _name,
            businessRegNumber: _businessRegNumber,
            phoneNumber: _phoneNumber,
            isRegistered: true
        });
        distributorAddresses.push(_distributor);
        emit DistributorRegistered(_distributor, _name, _businessRegNumber, _phoneNumber);
    }

    function registerWholesaler(address _wholesaler, string memory _name, string memory _businessRegNumber, string memory _phoneNumber) public onlyOwner {
        require(!wholesalers[_wholesaler].isRegistered, "Wholesaler is already registered");
        wholesalers[_wholesaler] = Wholesaler({
            name: _name,
            businessRegNumber: _businessRegNumber,
            phoneNumber: _phoneNumber,
            isRegistered: true
        });
        wholesalerAddresses.push(_wholesaler);
        emit WholesalerRegistered(_wholesaler, _name, _businessRegNumber, _phoneNumber);
    }

    function createBatch(string memory _batchID, string memory _itemName, uint _manufacturingDate, uint _expiryDate, string memory _productionDetails) public onlyOwner {
        require(bytes(batches[_batchID].batchID).length == 0, "Batch ID already exists");

        batches[_batchID] = Batch({
            batchID: _batchID,
            itemName: _itemName,
            manufacturingDate: _manufacturingDate,
            expiryDate: _expiryDate,
            productionDetails: _productionDetails,
            state: State.Manufactured,
            stateDetails: "Manufactured",
            currentHolder: msg.sender
        });

        emit BatchCreated(_batchID, _itemName, _manufacturingDate, _expiryDate, _productionDetails, msg.sender);
    }

    function shipBatchToDistributor(string memory _batchID, address _to) public onlyOwner {
        require(distributors[_to].isRegistered, "Recipient is not a registered distributor");
        Batch storage batch = batches[_batchID];
        require(batch.state == State.Manufactured, "Batch is not in Manufactured state");
        batch.currentHolder = _to;
        batch.state = State.Shipped;
        emit BatchShipped(_batchID, msg.sender, _to);
        emit Notification(_batchID, batch.itemName, _to);
    }

    function shipBatchToWholesaler(string memory _batchID, address _to) public onlyCurrentHolder(_batchID) {
        require(wholesalers[_to].isRegistered, "Recipient is not a registered wholesaler");
        Batch storage batch = batches[_batchID];
        require(batch.state == State.Received, "Batch is not in Received state");
        batch.currentHolder = _to;
        batch.state = State.Distributed;
        emit BatchShipped(_batchID, msg.sender, _to);
        emit Notification(_batchID, batch.itemName, _to);
    }

    function updateStateAsDistributor(string memory _batchID, string memory _stateDetails) public onlyCurrentHolder(_batchID) {
        Batch storage batch = batches[_batchID];
        require(distributors[msg.sender].isRegistered, "Only registered distributors can perform this action");
        require(batch.state == State.Shipped, "Batch must be in Shipped state");
        updateExpiry(_batchID);
        require(batch.state != State.Expired, "Batch has expired");
        batch.state = State.Received;
        batch.stateDetails = _stateDetails;
        
        emit StateUpdated(_batchID, batch.state, _stateDetails, msg.sender);
    }

    function updateStateAsWholesaler(string memory _batchID, string memory _stateDetails) public onlyCurrentHolder(_batchID) {
        Batch storage batch = batches[_batchID];
        require(wholesalers[msg.sender].isRegistered, "Only registered wholesalers can perform this action");
        require(batch.state == State.Distributed, "Batch must be in Distributed state");
        updateExpiry(_batchID);
        require(batch.state != State.Expired, "Batch has expired");
        batch.state = State.Wholesaled;
        batch.stateDetails = _stateDetails;
        
        emit StateUpdated(_batchID, batch.state, _stateDetails, msg.sender);
    }

    function updateExpiry(string memory _batchID) internal {
        Batch storage batch = batches[_batchID];
        if (block.timestamp > batch.expiryDate) {
            batch.state = State.Expired;
            batch.stateDetails = "Expired";
        }
    }

    function getBatchDetails(string memory _batchID) public view returns (string memory itemName, uint manufacturingDate,uint expiryDate, string memory productionDetails, State state, string memory stateDetails, address currentHolder) {
        Batch storage batch = batches[_batchID];
        require(bytes(batch.batchID).length != 0, "Batch ID does not exist");
        return (batch.itemName, batch.manufacturingDate, batch.expiryDate, batch.productionDetails, batch.state, batch.stateDetails, batch.currentHolder);
    }
}