// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * PaymentRegistry - Smart Contract ghi lại thanh toán hóa đơn
 * Đảm bảo minh bạch và không thể chỉnh sửa
 */
contract PaymentRegistry {
    
    struct Payment {
        string invoiceId;
        string apartmentId;
        address payer;
        uint256 amount; // Số tiền (VND * 10^18)
        uint256 timestamp;
        string paymentMethod; // PayOS, VNPay, etc.
        string status; // SUCCESS, FAILED
    }
    
    // Mapping: invoiceId => Payment
    mapping(string => Payment) public payments;
    
    // Array các invoice IDs
    string[] public invoiceIds;
    
    // Owner (Backend API)
    address public owner;
    
    // Events
    event PaymentRecorded(
        string indexed invoiceId,
        address indexed payer,
        uint256 amount,
        uint256 timestamp,
        string paymentMethod
    );
    
    constructor() {
        owner = msg.sender;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this");
        _;
    }
    
    /**
     * Ghi lại payment lên blockchain
     */
    function recordPayment(
        string memory _invoiceId,
        string memory _apartmentId,
        address _payer,
        uint256 _amount,
        string memory _paymentMethod,
        string memory _status
    ) public onlyOwner {
        require(_payer != address(0), "Invalid payer address");
        require(_amount > 0, "Amount must be greater than 0");
        require(bytes(payments[_invoiceId].invoiceId).length == 0, "Payment already recorded");
        
        Payment memory newPayment = Payment({
            invoiceId: _invoiceId,
            apartmentId: _apartmentId,
            payer: _payer,
            amount: _amount,
            timestamp: block.timestamp,
            paymentMethod: _paymentMethod,
            status: _status
        });
        
        payments[_invoiceId] = newPayment;
        invoiceIds.push(_invoiceId);
        
        emit PaymentRecorded(
            _invoiceId,
            _payer,
            _amount,
            block.timestamp,
            _paymentMethod
        );
    }
    
    /**
     * Lấy thông tin payment theo invoiceId
     */
    function getPayment(string memory _invoiceId) 
        public 
        view 
        returns (
            string memory invoiceId,
            string memory apartmentId,
            address payer,
            uint256 amount,
            uint256 timestamp,
            string memory paymentMethod,
            string memory status
        ) 
    {
        Payment memory p = payments[_invoiceId];
        return (
            p.invoiceId,
            p.apartmentId,
            p.payer,
            p.amount,
            p.timestamp,
            p.paymentMethod,
            p.status
        );
    }
    
    /**
     * Đếm tổng số payments
     */
    function getTotalPayments() public view returns (uint256) {
        return invoiceIds.length;
    }
    
    /**
     * Lấy invoice ID theo index
     */
    function getInvoiceIdByIndex(uint256 index) public view returns (string memory) {
        require(index < invoiceIds.length, "Index out of bounds");
        return invoiceIds[index];
    }
}
