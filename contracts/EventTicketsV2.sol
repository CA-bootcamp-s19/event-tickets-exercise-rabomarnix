pragma solidity ^0.5.0;

    /*
        The EventTicketsV2 contract keeps track of the details and ticket sales of multiple events.
     */
contract EventTicketsV2 {

    /*
        Define an public owner variable. Set it to the creator of the contract when it is initialized.
    */
    address payable public owner;
    uint PRICE_TICKET = 100 wei;

    /*
        Create a variable to keep track of the event ID numbers.
    */
    uint public idGenerator;

    /*
        Define an Event struct, similar to the V1 of this contract.
        The struct has 6 fields: description, website (URL), totalTickets, sales, buyers, and isOpen.
        Choose the appropriate variable type for each field.
        The "buyers" field should keep track of addresses and how many tickets each buyer purchases.
    */
    struct Event {
        string description;
        string website;
        uint totalTickets;
        uint sales;
        mapping(address => uint) buyers;
        bool isOpen;
    }

    /*
        Create a mapping to keep track of the events.
        The mapping key is an integer, the value is an Event struct.
        Call the mapping "events".
    */
    mapping(uint => Event) public events;

    event LogEventAdded(string desc, string url, uint ticketsAvailable, uint eventId);
    event LogBuyTickets(address buyer, uint eventId, uint numTickets);
    event LogGetRefund(address accountRefunded, uint eventId, uint numTickets);
    event LogEndSale(address owner, uint balance, uint eventId);

    /*
        Create a modifier that throws an error if the msg.sender is not the owner.
    */
    modifier onlyOwner() {
        require(msg.sender == owner, 'No contract owner!');
        _;
    }

    modifier eventIsOpen(uint eventId) {
        require(events[eventId].isOpen == true, 'Event is not open!');
        _;
    }

    modifier sufficientPay(uint ticketAmount) {
        require(msg.value >= PRICE_TICKET * ticketAmount, 'Not enough funds sent!');
        _;
    }

    modifier enoughTicketsInStock(uint eventId, uint ticketAmount) {
        require(events[eventId].totalTickets >= events[eventId].sales + ticketAmount, 'Not enough tickets in stock!');
        _;
    }

    modifier refundChange(uint ticketAmount) {
        _;
        if (msg.value > PRICE_TICKET * ticketAmount) {
            uint change = msg.value - (PRICE_TICKET * ticketAmount);
            msg.sender.transfer(change);
        }
    }

    modifier purchasedTickets(uint eventId) {
        require(events[eventId].buyers[msg.sender] > 0, 'You did not buy tickets!');
        _;
    }

    constructor() public {
        owner = msg.sender;
    }

    /*
        Define a function called addEvent().
        This function takes 3 parameters, an event description, a URL, and a number of tickets.
        Only the contract owner should be able to call this function.
        In the function:
            - Set the description, URL and ticket number in a new event.
            - set the event to open
            - set an event ID
            - increment the ID
            - emit the appropriate event
            - return the event's ID
    */
    function addEvent(string calldata description, string calldata url, uint ticketAmount)
    external
    onlyOwner()
    returns(uint)
    {
        uint eventId = idGenerator;
        events[eventId] = Event(description, url, ticketAmount, 0, true);
        idGenerator++;
        emit LogEventAdded(description, url, ticketAmount, eventId);
        return eventId;
    }

    /*
        Define a function called readEvent().
        This function takes one parameter, the event ID.
        The function returns information about the event this order:
            1. description
            2. URL
            3. tickets available
            4. sales
            5. isOpen
    */
    function readEvent(uint eventId)
    public
    view
    returns(string memory description, string memory website, uint totalTickets, uint sales, bool isOpen)
    {
        description = events[eventId].description;
        website = events[eventId].website;
        totalTickets = events[eventId].totalTickets;
        sales = events[eventId].sales;
        isOpen = events[eventId].isOpen;
    }

    /*
        Define a function called buyTickets().
        This function allows users to buy tickets for a specific event.
        This function takes 2 parameters, an event ID and a number of tickets.
        The function checks:
            - that the event sales are open
            - that the transaction value is sufficient to purchase the number of tickets
            - that there are enough tickets available to complete the purchase
        The function:
            - increments the purchasers ticket count
            - increments the ticket sale count
            - refunds any surplus value sent
            - emits the appropriate event
    */
    function buyTickets(uint eventId, uint ticketAmount)
    external
    payable
    eventIsOpen(eventId)
    sufficientPay(ticketAmount)
    enoughTicketsInStock(eventId, ticketAmount)
    refundChange(ticketAmount)
    {
        events[eventId].buyers[msg.sender] = ticketAmount;
        events[eventId].sales = events[eventId].sales + ticketAmount;
        emit LogBuyTickets(msg.sender, eventId, ticketAmount);
    }

    /*
        Define a function called getRefund().
        This function allows users to request a refund for a specific event.
        This function takes one parameter, the event ID.
        TODO:
            - check that a user has purchased tickets for the event
            - remove refunded tickets from the sold count
            - send appropriate value to the refund requester
            - emit the appropriate event
    */
    function getRefund(uint eventId)
    external
    payable
    eventIsOpen(eventId)
    purchasedTickets(eventId)
    {
        uint ticketAmount = events[eventId].buyers[msg.sender];
        events[eventId].buyers[msg.sender] = 0;
        events[eventId].sales = events[eventId].sales - ticketAmount;
        msg.sender.transfer(PRICE_TICKET * ticketAmount);
        emit LogGetRefund(msg.sender, eventId, ticketAmount);
    }

    /*
        Define a function called getBuyerNumberTickets()
        This function takes one parameter, an event ID
        This function returns a uint, the number of tickets that the msg.sender has purchased.
    */
    function getBuyerNumberTickets(uint eventId)
    external
    view
    returns(uint)
    {
        return events[eventId].buyers[msg.sender];
    }

    /*
        Define a function called endSale()
        This function takes one parameter, the event ID
        Only the contract owner can call this function
        TODO:
            - close event sales
            - transfer the balance from those event sales to the contract owner
            - emit the appropriate event
    */
    function endSale(uint eventId)
    external
    onlyOwner()
    {
        events[eventId].isOpen = false;
        uint proceeds = PRICE_TICKET * events[eventId].sales;
        // I recon storing it in a local variable is cheaper than doing the calculation twice?
        owner.transfer(proceeds);
        emit LogEndSale(owner, proceeds, eventId);
    }
}
