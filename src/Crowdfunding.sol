// We will be using Solidity version 0.5.4
pragma solidity 0.5.4;
// Importing OpenZeppelin's SafeMath Implementation
import 'https://github.com/OpenZeppelin/openzeppelin-solidity/contracts/math/SafeMath.sol';


contract Crowdfunding {
    using SafeMath for uint256;

    // List of existing projects
    Project[] private projects;

    // Event that will be emitted whenever a new project is started
    event ProjectStarted(
        address contractAddress,
        address projectStarter,
        string projectTitle,
        string projectDesc,
        uint256 deadline,
        uint256 goalAmount
    );

    /** @dev Function to start a new project.
      * @param title Title of the project to be created
      * @param description Brief description about the project
      * @param durationInSeconds Project deadline in seconds
      * @param amountToRaise Project goal in wei
      */
    function startProject(
        string calldata title,
        string calldata description,
        uint durationInSeconds,
        uint amountToRaise
    ) external {
        uint raiseUntil = now.add(durationInSeconds.mul(1 seconds));
        Project newProject = new Project(msg.sender, title, description, raiseUntil, amountToRaise);
        projects.push(newProject);
        emit ProjectStarted(
            address(newProject),
            msg.sender,
            title,
            description,
            raiseUntil,
            amountToRaise
        );
    }                                                                                                                                   

    /** @dev Function to get all projects' contract addresses.
      * @return A list of all projects' contract addreses
      */
    function returnAllProjects() external view returns(Project[] memory){
        return projects;
    }
}


contract Project {
    using SafeMath for uint256;

    // Data structures
    enum State {
        Fundraising,
        Expired,
        Successful
    }

    // State variables
    address payable public creator;
    uint public amountGoal; // required to reach at least this much, else everyone gets refund
    uint public completeAt;
    uint256 public currentBalance;
    uint public raiseBy;
    string public title;
    string public description;
    State public state = State.Fundraising; // initialize on create
    mapping (address => uint) public contributions;

    // Event that will be emitted whenever funding will be received
    event FundingReceived(address contributor, uint value, uint currentTotal);
    // Event that will be emitted whenever the project starter has received the funds
    event CreatorPaid(address recipient);
    // Event that will be emitted whenever the project has been expired
    event ProjectExpired(bool expired);

    // Modifier to check current state
    modifier inState(State _state) {
        require(state == _state, "Not funding anymore");
        _;
    }

    // Modifier to check if the function caller is the project creator
    modifier isCreator() {
        require(msg.sender == creator, "Sender is not creator!");
        _;
    }

    constructor
    (
        address payable projectStarter,
        string memory projectTitle,
        string memory projectDesc,
        uint fundRaisingDeadline,
        uint goalAmount
    ) public {
        creator = projectStarter;
        title = projectTitle;
        description = projectDesc;
        amountGoal = goalAmount;
        raiseBy = fundRaisingDeadline;
        currentBalance = 0;
    }

    /** @dev Function to fund a certain project.
      */
    function contribute() external inState(State.Fundraising) payable {
        require(msg.sender != creator, "Sender is creator!");
        bool expired = isExpired();
        contributions[msg.sender] = contributions[msg.sender].add(msg.value);
        currentBalance = currentBalance.add(msg.value);
	    emit ProjectExpired(expired);
        emit FundingReceived(msg.sender, msg.value, currentBalance);
        if(!expired) {
	        checkIfFundingComplete();
	    }
    }

    /** @dev Function to change the project state depending on conditions.
      */
    function checkIfFundingComplete() internal {
        if (currentBalance >= amountGoal) {
            state = State.Successful;
            payOut();
        }
        completeAt = now;
    }

    /** @dev Function to control if the crowdfunding has epired
     */
    function isExpired() internal returns (bool){
        if(now > raiseBy) {
            state = State.Expired;
            completeAt = now;
            return true;
        }
        return false;
    }

    /** @dev Function to give the received funds to project starter.
      */
    function payOut() internal inState(State.Successful) {
        uint256 totalRaised = currentBalance;
        currentBalance = 0;
        creator.transfer(totalRaised);
        emit CreatorPaid(creator);
    }

    /** @dev Function to retrieve donated amount when a project expires.
      */
    function getRefund() public inState(State.Expired) returns (bool) {
        require(contributions[msg.sender] > 0, "Address did not make any contributions!");

        uint amountToRefund = contributions[msg.sender];
        contributions[msg.sender] = 0;

        if (!msg.sender.send(amountToRefund)) {
            contributions[msg.sender] = amountToRefund;
            return false;
        } else {
            currentBalance = currentBalance.sub(amountToRefund);
        }
        return true;
    }

    /** @dev Function to get specific information about the project.
      * @return Returns all the project's details
      */
    function getDetails() public view returns
    (
        address payable projectStarter,
        string memory projectTitle,
        string memory projectDesc,
        uint256 deadline,
        State currentState,
        uint256 currentAmount,
        uint256 goalAmount
    ) {
        projectStarter = creator;
        projectTitle = title;
        projectDesc = description;
        deadline = raiseBy;
        currentState = state;
        currentAmount = currentBalance;
        goalAmount = amountGoal;
    }
}
