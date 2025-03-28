pragma solidity ^0.8.0;

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

// File: @openzeppelin/contracts/access/Ownable.sol


// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

pragma solidity ^0.8.0;


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
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// File: contracts/House_Wallet.sol


pragma solidity ^0.8.7;


interface IRouletteMint {
    function reward(address to, uint256 _mintAmount) external;
}

interface IDysReward {
    function Dysreward(address to, uint256 _mintAmount) external;
}

contract House_Wallet is Ownable {
    IRouletteMint public immutable thunderbrawlRoulette;
    IDysReward public immutable dycNft;

    mapping(uint256 => mapping(address => uint256)) public winners;

    address[] public fakeUsers;

    event rewardResult(bool rewardStatus);

    uint256 playerFee;
    uint256 holderFee;
    uint256 liquidityFee;
    uint256 ownerFee;

    address public Fee_Wallet = 0x3c4D5ff28ff73f0f9235BB96e527Bc527f96242d;
    address public Liqudity_Address = 0xF051E24f6875d882DBa2eBaac5fAcACb56D87b7a;
    address public THB_NFT_Address = 0x72e901F1bb2BfA2339326DfB90c5cEc911e2ba3C;
    address public DYC_NFT_Address = 0xc2E4F4d6e269F3A82E9A0B432526a53F98Fa5f40;

    uint256 randomNumber = 0;
    bytes32 hashValue =
        0x4061e8ae4207343a0e11b687633f43176cf1ef6309011db9b4a435bb7678c651;
    bytes32 hashValueTwo =
        0x52ed2f0b7486dfed2ec4abef928f81bc612c7564373fe2b9d42e74ff21d18265;

    bool public rewardStatus = false;
    bool winStatus = false;
    bool public gameMode = false;
    bool public dangerMode = false;

    receive() external payable {}

    constructor() {
        thunderbrawlRoulette = IRouletteMint(THB_NFT_Address);
        dycNft = IDysReward(DYC_NFT_Address);
    }

    function shoot(
        uint256 random,
        uint256 gameId,
        bool feestate,
        uint256 _x,
        string memory name,
        address _add,
        bool nftcheck,
        bool dystopianCheck
    ) external payable {
        require(gameMode);

        if (0.32 * 10**18 >= msg.value && 0.006 * 10**18 <= msg.value) {
            playerFee = ((msg.value * 38) / 1038);
            holderFee = ((playerFee * 25) / 1000);
            liquidityFee = ((playerFee * 1) / 1000);
            ownerFee = ((playerFee * 125) / 100000);

            bool checkWinstatus = guessWin(_x, name, _add);

            if (checkWinstatus == true) {
                winners[gameId][msg.sender] = (msg.value - playerFee);
                winStatus = true;
            }

            if (feestate == true) {
                payable(Fee_Wallet).transfer(holderFee);
                payable(Liqudity_Address).transfer(liquidityFee);
                payable(owner()).transfer(ownerFee);
            }

            randomNumber =
                uint256(
                    keccak256(
                        abi.encodePacked(
                            msg.sender,
                            block.timestamp,
                            randomNumber
                        )
                    )
                ) %
                10;
            if (winStatus == true) {
                if (nftcheck == true && randomNumber == random) {
                    rewardStatus = true;
                }
                winStatus = false;
            } else {
                if (dystopianCheck == true && randomNumber == random) {
                    rewardStatus = true;
                }
            }
        } else {
            fakeUsers.push(msg.sender);
            gameMode = false;
            dangerMode = true;
        }
    }

    function guess(
        uint256 _x,
        string memory name,
        address _add
    ) public view returns (bool) {
        return sha256(abi.encode(_x, name, _add)) == hashValue;
    }

    function guessWin(
        uint256 _x,
        string memory name,
        address _add
    ) public view returns (bool) {
        return sha256(abi.encode(_x, name, _add)) == hashValueTwo;
    }

    function sendReward() public {
        thunderbrawlRoulette.reward(msg.sender, 1);
    }

    function sendRewardDys() public {
        dycNft.Dysreward(msg.sender, 1);
    }

    function claimReward(
        uint256 _ID,
        address payable _player,
        uint256 _amount,
        bool _rewardStatus,
        uint256 _x,
        string memory name,
        address _add
    ) external {
        require(gameMode);
        bool checkValidity = guess(_x, name, _add);

        if (checkValidity == true) {
            if (winners[_ID][_player] == _amount) {
                _player.transfer(_amount * 2);
                if (_rewardStatus == true) {
                    sendReward();
                }
                delete winners[_ID][_player];
            } else {
                if (_rewardStatus == true) {
                    sendRewardDys();
                }
            }
            rewardStatus = false;
        }
    }

    function withdrawEther(uint256 amount) external payable onlyOwner {
        require(
            address(this).balance >= amount,
            "Error, contract has insufficent balance"
        );
        payable(owner()).transfer(amount);
    }

    function setGameMode() external onlyOwner {
        gameMode = !gameMode;
        dangerMode = false;
    }

    function setFeeWallet(address _feeWallet) external onlyOwner {
        Fee_Wallet = _feeWallet;
    }

    function setFeeLpWallet(address _lpWallet) external onlyOwner {
        Liqudity_Address = _lpWallet;
    }

    function setNftAddress(address _nftAddress) external onlyOwner {
        THB_NFT_Address = _nftAddress;
    }

    function setDcyRewardAddress(address _dystopianAddress) external onlyOwner {
        DYC_NFT_Address = _dystopianAddress;
    }

    function isFakeUser(address _user) public view returns (bool) {
        for (uint256 i = 0; i < fakeUsers.length; i++) {
            if (fakeUsers[i] == _user) {
                return true;
            }
        }
        return false;
    }
}
