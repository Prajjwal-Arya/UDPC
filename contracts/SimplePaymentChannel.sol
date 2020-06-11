pragma solidity ^0.4.24;

import "zeppelin-solidity/contracts/math/SafeMath.sol";
import "zeppelin-solidity/contracts/ECRecovery.sol";

contract SimplePaymentChannel {
    using SafeMath for uint256;
    using ECRecovery for bytes32;

    //============================================================================
    // EVENTS
    //============================================================================

    event ChannelOpened(address sender, address recipient, uint expiration, uint256 deposit);
    event ChannelClosed(uint256 senderBalance, uint256 recipientBalance);

    // Creator of channel
    address public sender;
    // Recipient of channel
    address public recipient;
    // When sender can close the channel
    uint256 public expiration;

    //============================================================================
    // PUBLIC FUNCTIONS
    //============================================================================


    constructor(address _recipient, uint256 _duration) public payable {
        // sanity checks
        require(msg.value > 0);
        require(msg.sender != _recipient);

        sender = msg.sender;
        recipient = _recipient;
        expiration = now + _duration;

        emit ChannelOpened(sender, recipient, expiration, msg.value);
    }

    function closeChannel(uint256 _balance, bytes _signedMessage) public {
        // only recipient can call closeChannel
        require(msg.sender == recipient);
        require(isValidSignature(_balance, _signedMessage));

        // temp vars for calculating sender and recipient remittances
        uint256 balance = _balance;
        uint256 remainder = 0;

        // if _balance > address(this).balance, send address(this).balance to recipient
        if (_balance > address(this).balance) {
            balance = address(this).balance;
        } else {
            remainder = address(this).balance.sub(balance);
        }

        // remit payment to recipient
        recipient.transfer(balance);

        emit ChannelClosed(remainder, balance);

        // remit remainder to sender
        selfdestruct(sender);
    }

    function extendExpiration(uint256 _expiration) public {
        // only sender can call extendExpiration
        require(msg.sender == sender);
        require(_expiration > expiration);

        // update expiration
        expiration = _expiration;
    }


    function claimTimeout() public {
        // must be beyond expiration date
        require(now >= expiration);

        // remit payment to sender
        selfdestruct(sender);
    }

    //============================================================================
    // INTERNAL FUNCTIONS
    //============================================================================
    function isValidSignature(uint256 _balance, bytes _signedMessage)
        internal
        view
        returns (bool)
    {
        bytes32 message = prefixed(keccak256(abi.encodePacked(address(this), _balance)));

        // check that the signature is from the payment sender
        return message.recover(_signedMessage) == sender;
    }

    function prefixed(bytes32 _hash)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", _hash));
    }
}