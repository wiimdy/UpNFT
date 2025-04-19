// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Pausable is Ownable {
    bool internal _paused;

    event Paused(address account);

    event Unpaused(address account);

    /// @dev contract가 정지된 상태에서 허용되지 않은 함수가 실행될 때
    error EnforcedPause();

    /// @dev contract가 정지되지 않은 상태에서 허용되지 않은 함수가 실행될 때
    error ExpectedPause();

    constructor() Ownable(msg.sender) {
        _paused = false;
    }

    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }

    modifier whenPaused() {
        _requirePaused();
        _;
    }

    function paused() public view virtual returns (bool) {
        return _paused;
    }

    function _requireNotPaused() internal view virtual {
        if (paused()) {
            revert EnforcedPause();
        }
    }

    function _requirePaused() internal view virtual {
        if (!paused()) {
            revert ExpectedPause();
        }
    }

    /// @dev contract 정지
    function stopContract() external virtual onlyOwner whenNotPaused {
        _paused = true;
        emit Paused(msg.sender);
    }

    /// @notice Stop된 contract resume
    /// @dev stop된 상태에서 실행
    function resumeContract() external virtual onlyOwner whenPaused {
        _paused = false;
        emit Unpaused(msg.sender);
    }

    /// 컨트랙트에 돈을 뺄 수 있는 유일한 방법
    function emergencyTransfer(uint256 amount) external whenPaused onlyOwner {
        require(amount <= address(this).balance, "Too much ether");
        bool success = payable(msg.sender).send(amount);
        require(success, "send Error");
    }
}
