// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

contract Enums {
    enum electionType {
        scheduled,
        council,
        CKIP, //todo: change CKIP to community
        stepDown
    }
}