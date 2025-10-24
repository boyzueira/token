/**
 *Submitted for verification at BscScan.com on 2024-10-20
*/

/**
 *Submitted for verification at testnet.bscscan.com on 2024-10-18
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;



/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}


/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}


/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _setOwner(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _setOwner(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}


contract PresaleBoyz is Ownable {
    IERC20 public usdtToken;
    IERC20 public boyzToken;
    uint256 public rate; // how many BOYZ per smallest USDT unit (rate is scaled by decimals)
    uint256 public usdtDecimals = 18; // USDT has 8 decimals
    uint256 public boyzDecimals = 18; // BOYZ has 18 decimals
    bool public claimAllowed = false; // To allow 10% special claim
    uint256 public totalRaised = 0;
    address public adminWallet = 0x6872910e0c4008de5fc7a495e352120D75e86044;
    mapping(address => bool) public hasClaimedSpecial;

    struct VestingInfo {
        uint256 boyzAmount;
        uint256 claimedAmount;
        uint256 lastClaimTime;
        uint256 purchaseTime;
        bool specialClaimed; // Track if special claim is used for each vesting entry
    }

    struct VestingInfoWithClaimable {
        uint256 boyzAmount;
        uint256 claimedAmount;
        uint256 purchaseTime;
        bool specialClaimed;
        bool claimable; // Whether the special claim can be made
    }


    mapping(address => VestingInfo[]) public vestingHistory; // Store vesting details per user

    event TokensPurchased(address indexed purchaser, uint256 usdtAmount, uint256 boyzAmount);
    event WithdrawnUSDT(uint256 amount);
    event WithdrawnBoyz(uint256 amount);
    event Claimed(address indexed claimer, uint256 amount);
    event SpecialClaimed(address indexed claimer, uint256 amount);

    constructor(
        IERC20 _usdtToken,
        IERC20 _boyzToken,
        uint256 _rate
    ) Ownable() {
        usdtToken = _usdtToken;
        boyzToken = _boyzToken;
        rate = _rate; // initial rate in smallest units
    }

    // Allows the owner to change the presale rate
    function changeRate(uint256 newRate) public onlyOwner {
        rate = newRate;
    }

    // Function to purchase BOYZ tokens using USDT
    function buyTokens(uint256 usdtAmount) public {
        require(usdtAmount > 0, "Amount of USDT must be greater than zero");

        uint256 boyzAmount = (usdtAmount * rate * (10 ** (boyzDecimals - usdtDecimals)));

        require(usdtToken.transferFrom(msg.sender, address(this), usdtAmount), "USDT transfer failed");
        totalRaised += boyzAmount;
        vestingHistory[msg.sender].push(
            VestingInfo({
                boyzAmount: boyzAmount,
                claimedAmount: 0,
                lastClaimTime: block.timestamp,
                purchaseTime: block.timestamp,
                specialClaimed: false
            })
        );

        emit TokensPurchased(msg.sender, usdtAmount, boyzAmount);
    }
	function claim(uint256 vestingId) public {
		require(vestingId < vestingHistory[msg.sender].length, "Invalid vesting ID");

		VestingInfo storage vesting = vestingHistory[msg.sender][vestingId];

		// Calculate how many months have passed since the last claim
		uint256 monthsPassed = (block.timestamp - vesting.lastClaimTime) / 30 days;
		require(monthsPassed > 0, "No claimable amount at this time");

		// Calculate the maximum amount claimable based on the months passed (5% per month)
		uint256 claimable = (vesting.boyzAmount * 5 * monthsPassed) / 100;

		// Check how much is still unclaimed
		uint256 remainingAmount = vesting.boyzAmount - vesting.claimedAmount;

		// Ensure the user cannot claim more than they are entitled to (cap at remaining amount)
		if (claimable >= remainingAmount) {
			claimable = remainingAmount;  // Limit the claimable amount to what remains
            vesting.lastClaimTime = block.timestamp;
            vesting.specialClaimed = true;
		}

		// Update claimed amount and last claim time
		vesting.claimedAmount += claimable;
		vesting.lastClaimTime = block.timestamp;

		// Transfer the claimable tokens to the user
		require(boyzToken.transfer(msg.sender, claimable), "BOYZ transfer failed");

		emit Claimed(msg.sender, claimable);
	}

    // Function to get the total staked, claimed, and unclaimed amount for a user
    function getVestingTotals(address _user) public view returns (uint256 totalStaked, uint256 totalClaimed) {
        totalStaked = 0;
        totalClaimed = 0;


        // Loop through the user's vesting entries and calculate the totals
        for (uint256 i = 0; i < vestingHistory[_user].length; i++) {
            VestingInfo memory vesting = vestingHistory[_user][i];
            totalStaked += vesting.boyzAmount;
            totalClaimed += vesting.claimedAmount;      
        }
    }


    



    function withdrawUSDT() public onlyOwner {
        uint256 balance = usdtToken.balanceOf(address(this));
        require(balance > 0, "No USDT to withdraw");

        require(usdtToken.transfer(adminWallet, balance), "USDT withdrawal failed");

        emit WithdrawnUSDT(balance);
    }

    function withdrawLBoyz() public onlyOwner {
        uint256 balance = boyzToken.balanceOf(address(this));
        require(balance > 0, "No BOYZ to withdraw");

        require(boyzToken.transfer(adminWallet, balance), "BOYZ withdrawal failed");

        emit WithdrawnBoyz(balance);
    }

    function getAllVestingDetails(address _user) public view returns (VestingInfo[] memory) {
        uint256 vestingCount = vestingHistory[_user].length;
        VestingInfo[] memory details = new VestingInfo[](vestingCount);

        for (uint256 i = 0; i < vestingCount; i++) {
            VestingInfo storage vesting = vestingHistory[_user][i];

            details[i] = VestingInfo({
                boyzAmount: vesting.boyzAmount,
                claimedAmount: vesting.claimedAmount,
                lastClaimTime: vesting.lastClaimTime,
                purchaseTime: vesting.purchaseTime,
                specialClaimed: vesting.specialClaimed
            });
        }

        return details;
    }
}