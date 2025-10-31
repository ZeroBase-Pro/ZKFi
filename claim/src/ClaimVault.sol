// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title ClaimVault
 * @notice Immediate token claims authorized by an off-chain signer with per-epoch global/user caps.
 * @dev Uses personal-sign style hashing with explicit contract address in the payload.
 *      Protected by Pausable and ReentrancyGuard.
 */
contract ClaimVault is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice ERC20 token managed by this vault.
    IERC20 public immutable ZBT;

    /// @notice Timestamp when claiming starts; used as the epoch anchor.
    uint256 public immutable startClaimTimestamp;

    /// @notice Address whose signatures authorize claims.
    address public signer;

    /// @notice Per-user nonce to prevent signature replay.
    mapping(address user => uint256 nonce) public userNonce;

    /// @notice Epoch length in seconds.
    uint256 public epochDuration = 1 hours;

    /// @notice Max total claimed per epoch across all users.
    uint256 public globalCapPerEpoch = 100_000 ether;

    /// @notice Max total claimed per epoch for a single user.
    uint256 public userCapPerEpoch = 50_000 ether;

    /// @notice Global claimed amounts: epochDuration => epochId => amount.
    mapping(uint256 epochDuration => mapping(uint256 epochId => uint256 claimedAmount))
        public claimedByEpoch;

    /// @notice Per-user claimed amounts: epochDuration => user => epochId => amount.
    mapping(uint256 epochDuration => mapping(address user => mapping(uint256 epochId => uint256 claimedAmount)))
        public userClaimedByEpoch;

    /**
     * @notice Emitted when a claim is successfully processed.
     * @param user Recipient address.
     * @param amount Claimed amount.
     * @param epochId Current epoch id.
     * @param currentEpochDuration Epoch length used for accounting.
     * @param userNonce User nonce consumed for this claim.
     */
    event Claimed(
        address indexed user,
        uint256 indexed amount,
        uint256 indexed epochId,
        uint256 currentEpochDuration,
        uint256 userNonce
    );

    /**
     * @notice Emitted when the owner withdraws tokens in emergencies.
     * @param _token Token address withdrawn.
     * @param _receiver Recipient address.
     */
    event EmergencyWithdrawal(
        address indexed _token,
        address indexed _receiver
    );

    /**
     * @notice Emitted when the signer address changes.
     * @param oldSigner Previous signer.
     * @param newSigner New signer.
     */
    event UpdateSigner(address indexed oldSigner, address indexed newSigner);

    /**
     * @notice Emitted when epoch configuration changes.
     * @param epochDuration New epoch length (seconds).
     * @param globalCapPerEpoch New global cap per epoch.
     * @param userCapPerEpoch New per-user cap per epoch.
     */
    event UpdateEpochConfig(
        uint256 indexed epochDuration,
        uint256 globalCapPerEpoch,
        uint256 userCapPerEpoch
    );

    /**
     * @notice Initializes the vault.
     * @param _ZBT Token address to manage.
     * @param _signer Off-chain signer that authorizes claims.
     */
    constructor(address _ZBT, address _signer) Ownable(msg.sender) {
        ZBT = IERC20(_ZBT);
        signer = _signer;
        startClaimTimestamp = block.timestamp;
    }

    /**
     * @notice Claim tokens immediately using a valid off-chain signature.
     * @dev Verifies signature over (user, amount, nonce, chainId, expiry, address(this)).
     *      Increments user nonce after successful verification.
     *      Enforces global and per-user epoch caps.
     * @param user Must equal msg.sender.
     * @param claimAmount Amount to claim.
     * @param expiry Signature expiry timestamp (must be > block.timestamp).
     * @param signature Signer's signature.
     */
    function Claim(
        address user,
        uint256 claimAmount,
        uint256 expiry,
        bytes calldata signature
    ) external whenNotPaused nonReentrant {
        require(claimAmount != 0, "Zero ZBT number");
        require(user == msg.sender, "Invalid sender");
        require(expiry > block.timestamp, "Signature expired");
        uint256 currentEpochDuration = epochDuration;
        uint256 currentUserNonce = userNonce[msg.sender];

        uint256 chainId;
        assembly {
            chainId := chainid()
        }

        bytes32 claimDigestHash = calculateClaimZBTHash(
            msg.sender,
            claimAmount,
            currentUserNonce,
            chainId,
            expiry
        );

        require(
            _checkSignature(claimDigestHash, signature),
            "Invalid signature"
        );
        unchecked {
            userNonce[msg.sender] = currentUserNonce + 1;
        }

        uint256 epochId = currentEpochId();

        uint256 globalUsed = claimedByEpoch[currentEpochDuration][epochId];
        require(
            globalUsed + claimAmount <= globalCapPerEpoch,
            "Global cap exceeded"
        );

        uint256 userUsed = userClaimedByEpoch[currentEpochDuration][msg.sender][
            epochId
        ];
        require(userUsed + claimAmount <= userCapPerEpoch, "User cap exceeded");

        require(
            ZBT.balanceOf(address(this)) >= claimAmount,
            "Insufficient Balance"
        );

        unchecked {
            claimedByEpoch[currentEpochDuration][epochId] = globalUsed + claimAmount;
            userClaimedByEpoch[currentEpochDuration][msg.sender][epochId] =
                userUsed +
                claimAmount;
        }

        ZBT.safeTransfer(msg.sender, claimAmount);
        emit Claimed(msg.sender, claimAmount, epochId, currentEpochDuration , currentUserNonce);
    }

    /**
     * @notice Returns the current epoch id based on start timestamp and epoch duration.
     * @return epochId Current epoch index.
     */
    function currentEpochId() public view returns (uint256) {
        return (block.timestamp - startClaimTimestamp) / epochDuration;
    }

    /**
     * @notice Computes the personal-sign style digest used by the contract.
     * @dev Equivalent to keccak256(abi.encode(...)) followed by toEthSignedMessageHash.
     * @param _user Claiming user.
     * @param _claimAmount Amount authorized.
     * @param _userNonce Expected user nonce.
     * @param _chainid Chain id for domain separation.
     * @param _expiry Expiry timestamp.
     * @return digest 32-byte message hash to be signed/verified.
     */
    function calculateClaimZBTHash(
        address _user,
        uint256 _claimAmount,
        uint256 _userNonce,
        uint256 _chainid,
        uint256 _expiry
    ) public view returns (bytes32) {
        bytes32 userClaimZBTStructHash = keccak256(
            abi.encode(_user, _claimAmount, _userNonce, _chainid, _expiry, address(this))
        );
        return MessageHashUtils.toEthSignedMessageHash(userClaimZBTStructHash);
    }

    /**
     * @notice Verifies that a signature was produced by the configured signer.
     * @param digestHash Message hash (already prefixed) that was signed.
     * @param signature Signature bytes (r||s||v).
     * @return result True if signature is valid.
     */
    function _checkSignature(
        bytes32 digestHash,
        bytes memory signature
    ) private view returns (bool result) {
        address recovered = ECDSA.recover(digestHash, signature);
        result = recovered == signer;
    }

    /**
     * @notice Owner-only emergency token sweep.
     * @param _token Token address to withdraw.
     * @param _receiver Recipient of the withdrawn balance.
     */
    function emergencyWithdraw(
        address _token,
        address _receiver
    ) external onlyOwner {
        require(_token != address(0), "Token must not be zero");
        require(_receiver != address(0), "Receiver must not be zero");

        IERC20(_token).safeTransfer(
            _receiver,
            IERC20(_token).balanceOf(address(this))
        );
        emit EmergencyWithdrawal(_token, _receiver);
    }

    /**
     * @notice Updates the signer address.
     * @param _newSigner New signer (must be non-zero).
     */
    function setSigner(address _newSigner) external onlyOwner {
        require(_newSigner != address(0), "Signer must not be zero");
        address oldSigner = signer;
        signer = _newSigner;
        emit UpdateSigner(oldSigner, _newSigner);
    }

    /**
     * @notice Updates epoch length and caps.
     * @dev Per-user cap must be > 0 and <= global cap.
     * @param _epochDuration Epoch length in seconds.
     * @param _globalCapPerEpoch Global cap per epoch.
     * @param _userCapPerEpoch Per-user cap per epoch.
     */
    function setEpochConfig(
        uint256 _epochDuration,
        uint256 _globalCapPerEpoch,
        uint256 _userCapPerEpoch
    ) external onlyOwner {
        require(_epochDuration > 0, "epochDuration can not be zero");
        require(
            _globalCapPerEpoch > 0,
            "globalCapPerEpoch must greater than zero"
        );
        require(
            _userCapPerEpoch > 0 && _userCapPerEpoch <= _globalCapPerEpoch,
            "_userCapPerEpoch must greater than zero and less than _globalCapPerEpoch"
        );
        epochDuration = _epochDuration;
        globalCapPerEpoch = _globalCapPerEpoch;
        userCapPerEpoch = _userCapPerEpoch;
        emit UpdateEpochConfig(
            _epochDuration,
            _globalCapPerEpoch,
            _userCapPerEpoch
        );
    }

    /// @notice Pauses claiming (owner-only).
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpauses claiming (owner-only).
    function unpause() external onlyOwner {
        _unpause();
    }
}