// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.9;

import "./ADonkeyDecay.sol";

/// @custom:security-contact contact@dkdk.club
contract DonkeyDecay is ADonkeyDecay {
    address public constant DESIGNATIED_INTIALIZER =
        0xd240bc7905f8D32320937cd9aCC3e69084ec4658;
    string public constant DEFAULT_BASE_URI = "https://data.dkdk.club/metadata/";
    string public constant DEFAULT_NAME = "Donkey Decay";
    string public constant DEFAULT_SYMBOL = "DKDK";

    // We have to use zero parameters in constructor to avoid front-run.
    constructor()
        ADonkeyDecay(
            DESIGNATIED_INTIALIZER,
            DEFAULT_NAME,
            DEFAULT_SYMBOL,
            DEFAULT_BASE_URI
        )
    {}
}
