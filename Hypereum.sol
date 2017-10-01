pragma solidity ^0.4.11;

contract Owned {
    address public owner;

    function Owned() {
      owner = msg.sender;
    }

    modifier onlyOwner {
      require(msg.sender == owner);
      _;
    }

    function transferOwnership(address newOwner) onlyOwner {
      owner = newOwner;
    }

}

contract TokenRecipient { function receiveApproval(address from, uint256 value, address token, bytes extraData); }
contract Mortal is Owned { function cease() onlyOwner { selfdestruct(owner); }}

contract Token { 

    string public name; string public symbol; uint8 public decimals; uint256 public totalSupply;

    /* This creates an array with all balances */
    mapping (address => uint256) public balanceOf;
    mapping (address => mapping (address => uint256)) public allowance;

    /* This generates a public event on the blockchain that will notify clients */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /* This notifies clients about the amount burnt */
    event Burn(address indexed from, uint256 value);

    /* Initializes contract with initial supply tokens to the creator of the contract */
    function Token(
      uint256 initialSupply,
      string tokenName,
      uint8 decimalUnits,
      string tokenSymbol
      ) {
      balanceOf[msg.sender] = initialSupply;              // Give the creator all initial tokens
      totalSupply = initialSupply;                        // Update total supply
      name = tokenName;                                   // Set the name for display purposes
      symbol = tokenSymbol;                               // Set the symbol for display purposes
      decimals = decimalUnits;                            // Amount of decimals for display purposes
    }

    /* Internal transfer, only can be called by this contract */
    function _transfer(address _from, address _to, uint _value) internal {
      require (_to != 0x0);                               // Prevent transfer to 0x0 address. Use burn() instead
      require (balanceOf[_from] > _value);                // Check if the sender has enough
      require (balanceOf[_to] + _value > balanceOf[_to]); // Check for overflows
      balanceOf[_from] -= _value;                         // Subtract from the sender
      balanceOf[_to] += _value;                            // Add the same to the recipient
      Transfer(_from, _to, _value);
    }

    /// @notice Send `_value` tokens to `_to` from your account
    /// @param _to The address of the recipient
    /// @param _value the amount to send
    function transfer(address _to, uint256 _value) {
      _transfer(msg.sender, _to, _value);
    }

    /// @notice Send `_value` tokens to `_to` in behalf of `_from`
    /// @param _from The address of the sender
    /// @param _to The address of the recipient
    /// @param _value the amount to send
    function transferFrom(address _from, address _to, uint256 _value) returns (bool success) {
      require (_value < allowance[_from][msg.sender]);     // Check allowance
      allowance[_from][msg.sender] -= _value;
      _transfer(_from, _to, _value);
      return true;
    }

    /// @notice Allows `_spender` to spend no more than `_value` tokens in your behalf
    /// @param _spender The address authorized to spend
    /// @param _value the max amount they can spend
    function approve(address _spender, uint256 _value)
      returns (bool success) {
      allowance[msg.sender][_spender] = _value;
      return true;
    }

    /// @notice Allows `_spender` to spend no more than `_value` tokens in your behalf, and then ping the contract about it
    /// @param _spender The address authorized to spend
    /// @param _value the max amount they can spend
    /// @param _extraData some extra information to send to the approved contract
    function approveAndCall(address _spender, uint256 _value, bytes _extraData)
      returns (bool success) {
      TokenRecipient spender = TokenRecipient(_spender);
      if (approve(_spender, _value)) {
          spender.receiveApproval(msg.sender, _value, this, _extraData);
          return true;
      }
    }        

    /// @notice Remove `_value` tokens from the system irreversibly
    /// @param _value the amount of money to burn
    function burn(uint256 _value) returns (bool success) {
      require (balanceOf[msg.sender] > _value);            // Check if the sender has enough
      balanceOf[msg.sender] -= _value;                      // Subtract from the sender
      totalSupply -= _value;                                // Updates totalSupply
      Burn(msg.sender, _value);
      return true;
    }

    function burnFrom(address _from, uint256 _value) returns (bool success) {
      require(balanceOf[_from] >= _value);                // Check if the targeted balance is enough
      require(_value <= allowance[_from][msg.sender]);    // Check allowance
      balanceOf[_from] -= _value;                         // Subtract from the targeted balance
      allowance[_from][msg.sender] -= _value;             // Subtract from the sender's allowance
      totalSupply -= _value;                              // Update totalSupply
      Burn(_from, _value);
      return true;
    }

}

contract Hypereum is Owned, Token, Mortal {

    uint256 public sellPrice;
    uint256 public buyPrice;

    mapping (address => bool) public frozenAccount;

    /* This generates a public event on the blockchain that will notify clients */
    event FrozenFunds(address target, bool frozen); 

    /* Initializes contract with initial supply tokens to the creator of the contract */
    function Hypereum(
      uint256 initialSupply,
      string tokenName,
      uint8 decimalUnits,
      string tokenSymbol
    ) Token (initialSupply, tokenName, decimalUnits, tokenSymbol) {
         // Initial buy and sell price for Hypereum (0.0005 ether per Hyper Token)
         buyPrice = 1 ether * (1 ether / 2000 ether);   // 500000000000000
         sellPrice = 1 ether * (1 ether / 2000 ether);  // 500000000000000
    }

    /// @notice Transfer Hypereum Tokens from the token rewards pool to receiver's address
    /// @param receiver address to receieve the Hyper Tokens
    /// @param amount amount of Hyper Tokens to be received
    function rewardHyperToken(address receiver, uint256 amount) onlyOwner returns(bool sufficient) {
      require (receiver != 0x0);                               
      require (balanceOf[owner] > amount);                
      require (balanceOf[receiver] + amount > balanceOf[receiver]); 
      require(!frozenAccount[owner]);                     
      require(!frozenAccount[receiver]);                  
      balanceOf[owner] -= amount;                         
      balanceOf[receiver] += amount;     
      Transfer(owner, receiver, amount);
      return true;
    }

    /// @notice Transfer Hypereum tokens from sender to the token rewards pool as a payment method
    /// @param amount amount of Hyper Tokens to be transferred as payment
    function paidHyperToken(address sender, uint256 amount) onlyOwner returns(bool sufficient) {
        require (balanceOf[sender] > amount);                   // Check if the sender has enough
        require (balanceOf[owner] + amount > balanceOf[owner]); // Check for overflows
        balanceOf[sender] -= amount;                            // Subtract from the sender
        balanceOf[owner] += amount;                             // Add the same to the the rewards pool
        Transfer(sender, owner, amount);
        return true;
    }

    /* Internal transfer, only can be called by this contract */
    function _transfer(address _from, address _to, uint _value) internal {
      require (_to != 0x0);                               // Prevent transfer to 0x0 address. Use burn() instead
      require (balanceOf[_from] > _value);                // Check if the sender has enough
      require (balanceOf[_to] + _value > balanceOf[_to]); // Check for overflows
      require(!frozenAccount[_from]);                     // Check if sender is frozen
      require(!frozenAccount[_to]);                       // Check if recipient is frozen
      balanceOf[_from] -= _value;                         // Subtract from the sender
      balanceOf[_to] += _value;                           // Add the same to the recipient
      Transfer(_from, _to, _value);
    }

    /// @notice Create `mintedAmount` tokens and send it to `target`
    /// @param target Address to receive the tokens
    /// @param mintedAmount the amount of tokens it will receive
    function mintToken(address target, uint256 mintedAmount) onlyOwner {
      balanceOf[target] += mintedAmount;
      totalSupply += mintedAmount;
      Transfer(0, this, mintedAmount);
      Transfer(this, target, mintedAmount);
    }

    /// @notice `freeze? Prevent | Allow` `target` from sending & receiving tokens
    /// @param target Address to be frozen
    /// @param freeze either to freeze it or not
    function freezeAccount(address target, bool freeze) onlyOwner {
      frozenAccount[target] = freeze;
      FrozenFunds(target, freeze);
    }

    /// @notice Allow users to buy tokens for `newBuyPrice` eth and sell tokens for `newSellPrice` eth
    /// @param newSellPrice Price the users can sell to the contract
    /// @param newBuyPrice Price users can buy from the contract
    function setPrices(uint256 newSellPrice, uint256 newBuyPrice) onlyOwner {
      sellPrice = newSellPrice;
      buyPrice = newBuyPrice;
    }

    /// @notice Buy Hyper Tokens from contract by sending Ether
    function buy() payable returns (uint amount){
        amount = msg.value / buyPrice;                  // calculates the amount
        require(balanceOf[owner] >= amount);            // checks if it has enough to sell
        balanceOf[msg.sender] += amount;                // adds the amount to buyer's balance
        balanceOf[owner] -= amount;                     // subtracts amount from seller's balance
        Transfer(owner, msg.sender, amount);            // execute an event reflecting the change
        return amount;                                  // ends function and returns
    }

    /// @notice Sell `amount` of Hyper Tokens to contract
    /// @param amount amount of Hyper Tokens to be sold
    function sell(uint amount) returns (uint revenue){
        require(balanceOf[msg.sender] >= amount);         // checks if the sender has enough to sell
        balanceOf[owner] += amount;                       // adds the amount to owner's balance
        balanceOf[msg.sender] -= amount;                  // subtracts the amount from seller's balance
        revenue = amount * sellPrice;                     // calculate revenue by multiplying amount by sell price
        require(msg.sender.send(revenue));                // sends ether to the seller: it's important to do this last to prevent recursion attacks
        Transfer(msg.sender, owner, amount);              // executes an event reflecting on the change
        return revenue;                                   // ends function and returns
    }

}