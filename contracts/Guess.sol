pragma solidity ^0.4.24;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./GuessDatasets.sol";
import "./GuessEvents.sol";
import "./GuessInterface.sol";
import "./ProductOwnership.sol";


/**
@dev main contract 
 */
contract Guess is GuessEvents, ProductOwnership {
    using SafeMath for *;
    // using NameFilter for string;
    // using F3DKeysCalcLong for uint256;

    // DiviesInterface constant private Divies = DiviesInterface(0xc7029Ed9EBa97A096e72607f4340c34049C7AF48);
    // JIincForwarderInterface constant private Jekyll_Island_Inc = JIincForwarderInterface(0xdd4950F977EE28D2C132f1353D1595035Db444EE);
    // PlayerBookInterface constant private PlayerBook = PlayerBookInterface(0xD60d353610D9a5Ca478769D371b53CEfAA7B6E4c);
    // F3DexternalSettingsInterface constant private extSettings = F3DexternalSettingsInterface(0x32967D6c142c2F38AB39235994e2DDF11c37d590);
    OtherToken private utoToken_ = OtherToken(0x1a8f615F0dD39B9DE8ad26db89Cfa76F7c9D0274);
//==============================================================================
// game settings
//=================_|===========================================================
    string constant public name = "Guess Game for UTour";
    string constant public symbol = "GUESS";

    uint256 private rndPrz_ = .001 ether;          // price of guess
    uint256 private wthdMin_ = .1 ether;           // min withdraw value
    uint256 private rndNum_ = 1;                   // amount of round at the same time
    uint256 private rndMaxNum_ = 200;              // max amount of players in one round
    uint256 private rndMaxPrcnt_ = 50;             // max percent of pot for product
    uint256 private fndValaut_;                    // total valaut for found
    uint256 private airdrop_;                      // total airdrop in this round  
//==============================================================================
// data used to store game info that changes
//=============================|=============================================
    // uint256 public airDropPot_;             // person who gets the airdrop wins part of this pot
    // uint256 public airDropTracker_ = 0;     // incremented each time a "qualified" tx occurs.  used to determine winning air drop
    uint256 public rID_;    // round id number / total rounds that have happened
    uint256 public pID_;    // last player number;
//****************
// PLAYER DATA 
//****************
    mapping (address => uint256) public pIDxAddr_;          // (addr => pID) returns player id by address
    mapping (bytes32 => uint256) public pIDxName_;          // (name => pID) returns player id by name
    mapping (uint256 => GuessDatasets.Player) public plyrs_;   // (pID => data) player data
    mapping (uint256 => mapping (uint256 => GuessDatasets.PlayerRounds)) public plyrRnds_;
    // (pID => rID => data) player round data by player id & round id
    mapping (uint256 => mapping (bytes32 => bool)) public plyrNames_;
    // (pID => name => bool) list of names a player owns. 
    // (used so you can change your display name amongst any name you own)
//****************
// ROUND DATA 
//****************
    mapping (uint256 => GuessDatasets.Round) public round_;   // (rID => data) round data
    mapping (uint256 => mapping(uint256 => uint256)) public rndTmEth_; 
    // (rID => tID => data) eth in per team, by round id and team id
    // mapping (uint256 => mapping(uint256 => GuessDatasets.PlayerRounds)) public rndPlyrs_;
    // (rID => pID => data) player data in rounds, by round id and player id
    mapping (uint256 => GuessDatasets.PlayerRounds[]) public rndPlyrs_;
//****************
// PRODUCT DATA 
//****************
    mapping(uint256 => Product) public prdcts_; // (id => product) product data

//****************
// PRODUCT DATA 
//****************
    mapping(address => uint256) public tetants_; // (address => valaut) valaut of tetants sell product

//****************
// TEAM FEE DATA 
//****************
    mapping (uint256 => GuessDatasets.TeamFee) public fees_;          // (team => fees) fee distribution by team
    mapping (uint256 => GuessDatasets.PotSplit) public potSplit_;     // (team => fees) pot split distribution by team
//****************
// DIVIDE
//****************
    GuessDatasets.Divide private divide_; 

//==============================================================================
// initial data setup upon contract deploy
//==============================================================================
    constructor () public
    {
        divide_ = GuessDatasets.Divide(2, 10, 10);
    }
//==============================================================================
// these are safety checks
// modifiers
//==============================================================================
    /**
     * @dev used to make sure no one can interact with contract until it has 
     * been activated. 
     */
    modifier isActivated() {
        require(activated_ == true, "its not ready yet.  check ?eta in discord"); 
        _;
    }
    
    /**
     * @dev prevents contracts from interacting with fomo3d 
     */
    modifier isHuman() {
        address _addr = msg.sender;
        uint256 _codeLength;
        
        assembly {_codeLength := extcodesize(_addr)}
        require(_codeLength == 0, "sorry humans only");
        _;
    }

    /**
     * @dev sets boundaries for incoming tx 
     */
    modifier isWithinLimits(uint256 _eth) {
        require(_eth >= 1000000000, "pocket lint: not a valid currency");
        require(_eth <= 100000000000000000000000, "no vitalik, no");
        _;    
    }
    
//==============================================================================
// use these to interact with contract
//====|=========================================================================
    /**
     * @dev converts all incoming ethereum to keys.
     * @param _price price of player guess
     * @param _affCode the ID of the player who gets the affiliate fee
     * @param _team what team is the player playing for?
     */
    function guess(uint256 _rID, uint256 _price, uint256 _affCode, uint256 _team)
        isActivated()
        isHuman()
        isWithinLimits(msg.value)
        public
        payable
    {
        // determine if player is new or not
        determinePID(msg.sender);
        
        // fetch player id
        uint256 _pID = pIDxAddr_[msg.sender];
        
        // manage affiliate residuals
        // if no affiliate code was given or player tried to use their own, lolz
        if (_affCode == 0 || _affCode == _pID)
        {
            // use last stored affiliate code 
            _affCode = plyrs_[_pID].laff;
            
        // if affiliate code was given & its not the same as previously stored 
        } else if (_affCode != plyrs_[_pID].laff) {
            // update last affiliate 
            plyrs_[_pID].laff = _affCode;
        }
        
        // verify a valid team was selected
        _team = verifyTeam(_team);
        
        // buy core 
        buyCore(_rID, _price, _affCode, _pID, _team);
    }
    
    
    /**
     * @dev essentially the same as buy, but instead of you sending ether 
     * from your wallet, it uses your unwithdrawn earnings.
     * -functionhash- 0x349cdcac (using ID for affiliate)
     * -functionhash- 0x82bfc739 (using address for affiliate)
     * -functionhash- 0x079ce327 (using name for affiliate)
     * @param _affCode the ID/address/name of the player who gets the affiliate fee
     * @param _team what team is the player playing for?
     * @param _eth amount of earnings to use (remainder returned to gen vault)
     */
    function reLoadXid(uint256 _rID, uint256 _price, uint256 _affCode, uint256 _team, uint256 _eth)
        isActivated()
        isHuman()
        isWithinLimits(_eth)
        public
    {   
        // fetch player ID
        uint256 _pID = pIDxAddr_[msg.sender];
        
        // manage affiliate residuals
        // if no affiliate code was given or player tried to use their own, lolz
        if (_affCode == 0 || _affCode == _pID)
        {
            // use last stored affiliate code 
            _affCode = plyrs_[_pID].laff;
            
        // if affiliate code was given & its not the same as previously stored 
        } else if (_affCode != plyrs_[_pID].laff) {
            // update last affiliate 
            plyrs_[_pID].laff = _affCode;
        }

        // verify a valid team was selected
        _team = verifyTeam(_team);

        // reload core
        reLoadCore(_rID, _pID, _price, _affCode, _team, _eth);
    }

    /**
     * @dev logic runs whenever a reload order is executed.  determines how to handle 
     * incoming eth depending on if we are in an active round or not 
     */
    function reLoadCore(uint256 _rID, uint256 _pID, uint256 _price, uint256 _affID, uint256 _team, uint256 _eth)
        private
    {   
        require(!round_[_rID].ended);
        require(round_[_rID].plyrMaxCount > round_[_rID].plyrCount);
        require(round_[_rID].minUTO <= utoToken_.balanceOf());
        require(plyrRnds_[_pID][_rID].plyrID == 0); 
        
        // grab time
        uint256 _now = now;
        require(_now > round_[_rID].strt);
        
        // sub eth
        plyrs_[_pID].gen = withdrawEarnings(_pID).sub(_eth);

        // call core 
        core(_rID, _pID, _price, msg.value, _affID, _team);

        // if round is over
        if (round_[_rID].plyrMaxCount ==  round_[_rID].plyrCount) 
        {
            endRound(_rID);
        }
    }

    /**
     * @dev withdraws all of your earnings.
     */
    function withdrawValaut()
        isActivated()
        isHuman()
        public
    {        
        // grab time
        uint256 _now = now;
        
        // fetch player ID
        uint256 _pID = pIDxAddr_[msg.sender];
        
        // get their earnings
        uint256 _eth = withdrawEarnings(_pID);

        require(_eth > wthdMin_);
            
        // gib moni
        if (_eth > 0)
            plyrs_[_pID].addr.transfer(_eth);
            
        // fire withdraw event
        emit GuessEvents.OnWithdraw(_pID, msg.sender, _eth, _now);
    }
//==============================================================================
// (for UI & viewing things on etherscan)
//=====_|=======================================================================
    /**
     * @dev returns player earnings per vaults 
     * @return general vault
     * @return airdrop vault
     * @return affiliate vault
     */
    function getPlayerVaults(uint256 _pID)
        public
        view
        returns(uint256 ,uint256, uint256)
    {
        return(
            plyrs_[_pID].gen,
            plyrs_[_pID].airdrop,
            plyrs_[_pID].aff
        );
    }

    /**
     * @dev returns all current round info needed for front end
     * -functionhash- 0x747dff42
     * @return eth invested during ICO phase
     * @return round id 
     * @return total keys for round 
     * @return time round ends
     * @return time round started
     * @return current pot 
     * @return current team ID & player ID in lead 
     * @return current player in leads address 
     * @return current player in leads name
     * @return whales eth in for round
     * @return bears eth in for round
     * @return sneks eth in for round
     * @return bulls eth in for round
     * @return airdrop tracker # & airdrop pot
     */
    function getCurrentRoundInfo()
        public
        view
        returns(uint256, string, string, string, string, uint256, uint256)
    {
        // setup local rID
        uint256 _rID = rID_;
        
        return
        (
            _rID,                           //0
            prdcts_[round_[_rID].prdctID].name,              //1
            prdcts_[round_[_rID].prdctID].nameEn,            //2
            prdcts_[round_[_rID].prdctID].disc,              //3
            prdcts_[round_[_rID].prdctID].discEn,            //4
            prdcts_[round_[_rID].prdctID].price,             //5
            round_[_rID].plyrCount          //6
        );
    }

    /**
     * @dev returns player info based on address.  if no address is given, it will 
     * use msg.sender 
     * @param _addr address of the player you want to lookup 
     * @return player id
     * @return general vault 
     * @return airdrop vault
     * @return affiliate vault 
	 * @return player last round price
     */
    function getPlayerInfoByAddress(address _addr)
        public 
        view 
        returns(uint256, uint256, uint256, uint256, uint256)
    {   
        if (_addr == address(0))
        {
            _addr == msg.sender;
        }
        uint256 _pID = pIDxAddr_[_addr];
        uint256 _rID = plyrs_[_pID].lrnd;
        return
        (
            _pID,                               // 0
            plyrs_[_pID].gen,                    // 1
            plyrs_[_pID].airdrop,                // 2
            plyrs_[_pID].aff,                    // 3
            plyrRnds_[_pID][_rID].price         // 4
        );
    }

//==============================================================================
// this + tools + calcs + modules = our softwares engine
//=====================_|=======================================================
    /**
     * @dev logic runs whenever a buy order is executed.  determines how to handle 
     * incoming eth depending on if we are in an active round or not
     */
    function buyCore(uint _rID, uint256 _price, uint256 _affID, uint256 _pID, uint256 _team)
        private
    {
        require(!round_[_rID].ended);
        require(round_[_rID].plyrMaxCount > round_[_rID].plyrCount);
        require(round_[_rID].minUTO <= utoToken_.balanceOf());
        require(plyrRnds_[_pID][_rID].plyrID == 0); 
        
        // grab time
        uint256 _now = now;
        require(_now > round_[_rID].strt);

        // call core 
        core(_rID, _pID, _price, msg.value, _affID, _team);

        // if round is over
        if (round_[_rID].plyrMaxCount ==  round_[_rID].plyrCount) 
        {
            endRound(_rID);
        } 
    }
    
    /**
     * @dev this is the core logic for any buy/reload that happens while a round 
     * is live.
     */
    function core(uint256 _rID, uint256 _pID, uint256 _price, uint256 _eth, uint256 _affID, uint256 _team)
        private
    {
        GuessDatasets.PlayerRounds memory data = GuessDatasets.PlayerRounds(
            _pID, utoToken_.balanceOf(), _price, now, _team, false);
        // update player 
        // plyrRnds_[_pID][_rID].uto = utoToken_.balanceOf(msg.sender);
        // plyrRnds_[_pID][_rID].price = _price;
        // plyrRnds_[_pID][_rID].timestamp = now;
        // plyrRnds_[_pID][_rID].team = _team;
        // plyrRnds_[_pID][_rID].iswin = false;
        plyrRnds_[_pID][_rID] = data;
        
        // update round
        round_[_rID].plyrCount = round_[_rID].plyrCount.add(1);
        round_[_rID].eth = _eth.add(round_[_rID].eth);
        rndTmEth_[_rID][_team] = _eth.add(rndTmEth_[_rID][_team]);

        rndPlyrs_[_rID].push(data);

        // distribute eth
        // 2% found 10% aff 10% airdrop %n tenant %m players in round
        uint _left = distributeExternal(_rID, _pID, _eth, _affID);
        distributeInternal(_rID, _left);

        // call end tx function to fire end tx event.
        endTx(_pID, _team, _eth);
    }
//==============================================================================
// tools
//============================================================================== 
    /**
     * @dev gets existing or registers new pID.  use this when a player may be new
     * @return pID 
     */
    function determinePID(address _addr)
        private
        returns (bool)
    {
        uint256 _pID = pIDxAddr_[_addr];
        bool isNew = false;
        // if player is new to this version of fomo3d
        if (_pID == 0)
        {
            // grab their player ID 
            pID_++ ;
            // set up player account 
            pIDxAddr_[_addr] = pID_;
            plyrs_[_pID].addr = _addr;
            isNew = true;
        } 
        return (isNew);
    }
    
    /**
     * @dev checks to make sure user picked a valid team.  if not sets team 
     * to default (sneks)
     */
    function verifyTeam(uint256 _team)
        private
        pure
        returns (uint256)
    {
        if (_team < 0 || _team > 3)
            return(0);
        else
            return(_team);
    }
    
    /**
     * @dev decides if round end needs to be run & new round started.  and if 
     * player unmasked earnings from previously played rounds need to be moved.
     */
    function managePlayer(uint256 _pID)
        private
    {       
        // update player's last round played
        plyrs_[_pID].lrnd = rID_;
    }
    
    /**
     * @dev ends the round. manages paying out winner/splitting up pot
     */
    function endRound(uint256 _rID) private
    {   
        // get winner
        uint256 _winID;
        uint256 _winPrice;
        uint256 _winPlyrPrice;
        (_winID, _winPrice, _winPlyrPrice) = calWinner(_rID);

        // update round
        round_[_rID].price = _winPrice;
        round_[_rID].winPrice = _winPlyrPrice;
        round_[_rID].plyr = _winID;
        round_[_rID].team = plyrRnds_[_winID][_rID].team;
        round_[_rID].end = now; 
        round_[_rID].ended = true;

        // update player
    }
    
    /**
     * @dev generates a random number between 0-99 and checks to see if thats
     * resulted in an airdrop win
     * @return do we have a winner?
     */
    // function airdrop()
    //     private  
    //     returns(bool)
    // {
        

    //     // 
    // }

    function calWinner(uint256 _rID) 
        private
        view 
        returns (uint256, uint256, uint256) 
    {
        uint256 seed = uint256(keccak256(abi.encodePacked(
            
            (block.timestamp).add
            (block.difficulty).add
            ((uint256(keccak256(abi.encodePacked(block.coinbase)))) / (now)).add
            (block.gaslimit).add
            ((uint256(keccak256(abi.encodePacked(msg.sender)))) / (now)).add
            (block.number)
            
        ))) % 100;

        uint256 _winPrice = prdcts_[round_[_rID].prdctID].price;
        uint256 _diff = _winPrice;
        _winPrice = _winPrice.div(100).mul(seed);

        uint256 _winID;
        uint256 _tmp;
        uint256 _winPlyrPrice;
        
        for(uint256 i = 0; i < rndPlyrs_[_rID].length; i++){
            if ( rndPlyrs_[_rID][i].price > _winPrice ){
                _tmp = rndPlyrs_[_rID][i].price.sub(_winPrice);
            } else {
                _tmp = _winPrice.sub(rndPlyrs_[_rID][i].price);
            }

            if (_tmp < _diff ){
                _diff = _tmp;
                _winID = rndPlyrs_[_rID][i].plyrID;
                _winPlyrPrice = rndPlyrs_[_rID][i].price;
            }
        }

        return (_winID, _winPrice, _winPlyrPrice);
    }

    /**
     * @dev distributes eth based on fees to found, aff
     */
    function distributeExternal(uint256 _rID, uint256 _pID, uint256 _eth, uint256 _affID)
        private 
        returns(uint256)
    {
        uint256 _left = _eth;
        // pay 2% out to community rewards
        uint256 _com = _eth / 50;
        fndValaut_ = _com.add(fndValaut_);
        _left = _eth.sub(_com);
        
        // distribute share to affiliate
        uint256 _aff = _eth / 10;
        
        // decide what to do with affiliate share of fees
        // affiliate must not be self, and must have a name registered
        if (_affID != _pID) {
            plyrs_[_affID].aff = _aff.add(plyrs_[_affID].aff);
            _left = _left.sub(_aff);
            emit GuessEvents.OnAffiliatePayout(_affID, plyrs_[_affID].addr, _rID, _pID, _aff, now);
        }

        // airdrop for all players
        uint256 _airdrop = _eth / 10;
        round_[_rID].airdrop = _airdrop.add(round_[_rID].airdrop);
        _left = _left.sub(_airdrop);
        
        // tetant
        uint256 _percent = prdcts_[round_[_rID].prdctID].prcnt;
        uint256 _tenant = _eth.div(100).mul(_percent);

        tetants_[productToOwner[round_[_rID].prdctID]] = _tenant.add(tetants_[productToOwner[round_[_rID].prdctID]]);
        _left = _left.sub(_tenant);

        return _left;
    }
    
    /**
     * @dev distributes eth based on fees to gen and pot
     */
    function distributeInternal(uint256 _rID, uint256 _eth)
        private
    {
        round_[_rID].pot = _eth.add(round_[_rID].pot);
    }

    
    /**
     * @dev adds up unmasked earnings, & vault earnings, sets them all to 0
     * @return earnings in wei format
     */
    function withdrawEarnings(uint256 _pID)
        private
        returns(uint256)
    {   
        // from vaults 
        uint256 _earnings = (plyrs_[_pID].airdrop).add(plyrs_[_pID].gen).add(plyrs_[_pID].aff);
        if (_earnings > 0)
        {
            plyrs_[_pID].airdrop = 0;
            plyrs_[_pID].gen = 0;
            plyrs_[_pID].aff = 0;
        }

        return(_earnings);
    }
    
    /**
     * @dev prepares compression data and fires event for buy or reload tx's
     */
    function endTx(uint256 _pID, uint256 _team, uint256 _eth)
        private
    {
        emit GuessEvents.OnEndTx
        (
            msg.sender,
            _pID,
            _team,
            _eth
        );
    }
//==============================================================================
//    (~ _  _    _._|_    .
//    _)(/_(_|_|| | | \/  .
//====================/=========================================================
    /** upon contract deploy, it will be deactivated.  this is a one time
     * use function that will activate the contract.  we do this so devs 
     * have time to set things up on the web end                            **/
    bool public activated_ = false;
    function activate()
        public
    {
        // only team just can activate 
        require(
            msg.sender == 0x18E90Fc6F70344f53EBd4f6070bf6Aa23e2D748C ||
            msg.sender == 0x8b4DA1827932D71759687f925D17F81Fc94e3A9D ||
            msg.sender == 0x8e0d985f3Ec1857BEc39B76aAabDEa6B31B67d53 ||
            msg.sender == 0x7ac74Fcc1a71b106F12c55ee8F802C9F672Ce40C ||
			msg.sender == 0xF39e044e1AB204460e06E87c6dca2c6319fC69E3,
            "only team just can activate"
        );

		// make sure that its been linked.
        require(address(utoToken_) != address(0), "must link to other FoMo3D first");
        
        // can only be ran once
        require(activated_ == false, "fomo3d already activated");
        
        // activate the contract 
        activated_ = true;
        
        // lets start first round
		rID_ = 1;
    }
    function setOtherToken(address _otherToken)
        public
    {
        // only team just can activate 
        require(
            msg.sender == 0x18E90Fc6F70344f53EBd4f6070bf6Aa23e2D748C ||
            msg.sender == 0x8b4DA1827932D71759687f925D17F81Fc94e3A9D ||
            msg.sender == 0x8e0d985f3Ec1857BEc39B76aAabDEa6B31B67d53 ||
            msg.sender == 0x7ac74Fcc1a71b106F12c55ee8F802C9F672Ce40C ||
			msg.sender == 0xF39e044e1AB204460e06E87c6dca2c6319fC69E3,
            "only team just can activate"
        );

        // make sure that it HASNT yet been linked.
        require(address(_otherToken) == address(0), "silly dev, you already did that");
        
        // set up other fomo3d (fast or long) for pot swap
        utoToken_ = OtherToken(_otherToken);
    }
}