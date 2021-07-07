//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "eth-token-recover/contracts/TokenRecover.sol";

interface ITransferReceiver {
    function onTokenTransfer(address, uint, bytes calldata) external returns (bool);
}

interface IApprovalReceiver {
    function onTokenApproval(address, uint, bytes calldata) external returns (bool);
}

contract BSCToken is ERC20, TokenRecover {

    // This value must be included whenever signature is generated
    mapping(address => uint256) public nonces;

    bytes32 public constant PERMIT_TYPEHASH = keccak256("Permit(address target,address spender,uint256 value,uint256 deadline)");
    bytes32 public constant TRANSFER_TYPEHASH = keccak256("Transfer(address target,address to,uint256 value,uint256 deadline)");
    bytes32 public immutable DOMAIN_SEPARATOR;

    constructor(
        string memory name,
        string memory symbol,
        uint totalSupply,
        address recipient
    ) ERC20(name, symbol) {
        uint256 chainId;
        assembly {chainId := chainid()}
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(symbol)),
                keccak256(bytes("1")),
                chainId,
                address(this)));

        _mint(recipient, totalSupply);
    }

    function getOwner() external view returns (address) {
        return owner();
    }

    function transferAndCall(address to, uint value, bytes calldata data) external returns (bool) {
        super.transfer(to, value);
        return ITransferReceiver(to).onTokenTransfer(msg.sender, value, data);
    }

    function approveAndCall(address spender, uint256 value, bytes calldata data) external returns (bool) {
        super.approve(spender, value);
        return IApprovalReceiver(spender).onTokenApproval(msg.sender, value, data);
    }

    function permit(address target, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external {
        require(block.timestamp <= deadline, "Expired permit");

        bytes32 hashStruct = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                target,
                spender,
                value,
                nonces[target]++,
                deadline));

        require(verifyEIP712(target, hashStruct, v, r, s) || verifyPersonalSign(target, hashStruct, v, r, s));

        _approve(target, spender, value);
    }

    function transferWithPermit(address target, address to, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external returns (bool) {
        require(block.timestamp <= deadline, "Expired permit");

        bytes32 hashStruct = keccak256(
            abi.encode(
                TRANSFER_TYPEHASH,
                target,
                to,
                value,
                nonces[target]++,
                deadline));

        require(verifyEIP712(target, hashStruct, v, r, s) || verifyPersonalSign(target, hashStruct, v, r, s));

        _transfer(target, to, value);

        return true;
    }

    function verifyEIP712(address target, bytes32 hashStruct, uint8 v, bytes32 r, bytes32 s) internal view returns (bool) {
        bytes32 hash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                hashStruct));
        address signer = ecrecover(hash, v, r, s);
        return (signer != address(0) && signer == target);
    }

    function verifyPersonalSign(address target, bytes32 hashStruct, uint8 v, bytes32 r, bytes32 s) internal pure returns (bool) {
        bytes32 hash = prefixed(hashStruct);
        address signer = ecrecover(hash, v, r, s);
        return (signer != address(0) && signer == target);
    }

    // Builds a prefixed hash to mimic the behavior of eth_sign.
    function prefixed(bytes32 hash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }
}