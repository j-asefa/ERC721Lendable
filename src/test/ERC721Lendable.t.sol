// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "../ERC721Lendable.sol";
import "ds-test/test.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

interface CheatCodes {
    function roll(uint256) external;
    function expectRevert(bytes calldata) external;
    function prank(address) external;
}

contract Tester is ERC721Lendable {
    constructor() ERC721Lendable(100, "test", "TEST") {
    }

    function mint(address to, uint256 tokenId) external {
        super._safeMint(to, tokenId);
    }
}

contract Receiver is IERC721Receiver {
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) pure external override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}

contract ContractTest is DSTest, IERC721Receiver {
    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);

    Tester tester;
    Receiver rec;
    Receiver subloanReceiver;
    function setUp() public {
        tester = new Tester();
        rec = new Receiver();
        subloanReceiver = new Receiver();
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) pure external override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function testReclaimLoan() public {
        tester.mint(address(this), 1);
        assertEq(tester.ownerOf(1), address(this));
        uint expiry = block.number + 500;
        tester.lendFrom(address(this), address(rec), 1, expiry);
        assertEq(tester.getLoanExpiry(address(this), 1), expiry);
        assertTrue(!tester.isTokenOnLoanTo(address(this), 1));
        assertTrue(tester.isTokenOnLoanTo(address(rec), 1));
        assertEq(tester.ownerOf(1), address(rec));

        cheats.roll(expiry + 1);

        tester.reclaimLoanForToken(address(this), 1);
        assertTrue(!tester.isTokenOnLoanTo(address(rec), 1));
        assertTrue(!tester.isTokenOnLoanTo(address(this), 1));
        assertEq(tester.ownerOf(1), address(this));
    }

    function testCannotTransferDuringLoan() public {
        tester.mint(address(this), 1);
        assertEq(tester.ownerOf(1), address(this));
        uint expiry = block.number + 500;
        tester.lendFrom(address(this), address(rec), 1, expiry);
        assertTrue(tester.isTokenOnLoanTo(address(rec), 1));

        cheats.expectRevert(bytes("ERC721Lendable: token must be sent back to lender"));
        cheats.prank(address(rec));
        tester.transferFrom(address(rec), address(1234), 1);

        // now reclaim loan
        cheats.roll(expiry + 1);

        tester.reclaimLoanForToken(address(this), 1);
        assertTrue(!tester.isTokenOnLoanTo(address(rec), 1));
        assertEq(tester.ownerOf(1), address(this));

        // this should be fine
        tester.transferFrom(address(this), address(1234), 1);
    }

    function testSubLoans() public {
        tester.mint(address(this), 1);
        assertEq(tester.ownerOf(1), address(this));

        // loan 1
        uint expiry = block.number + 500;
        tester.lendFrom(address(this), address(rec), 1, expiry);
        assertEq(tester.getLoanExpiry(address(this), 1), expiry);
        assertTrue(tester.isTokenOnLoanTo(address(rec), 1));
        assertEq(tester.ownerOf(1), address(rec));

        // subloan
        uint subloanExpiry = block.number + 300;

        tester.lendFrom(address(rec), address(subloanReceiver), 1, subloanExpiry);
        assertEq(tester.getLoanExpiry(address(rec), 1), subloanExpiry);
        assertTrue(tester.isTokenOnLoanTo(address(rec), 1));
        assertTrue(tester.isTokenOnLoanTo(address(subloanReceiver), 1));
        assertEq(tester.ownerOf(1), address(subloanReceiver));

        // reclaim subloan
        cheats.roll(subloanExpiry + 1);

        tester.reclaimLoanForToken(address(rec), 1);
        assertTrue(!tester.isTokenOnLoanTo(address(subloanReceiver), 1));
        assertTrue(tester.isTokenOnLoanTo(address(rec), 1));
        assertEq(tester.ownerOf(1), address(rec));

        // reclaim parent loan
        cheats.roll(expiry + 1);

        tester.reclaimLoanForToken(address(this), 1);
        assertTrue(!tester.isTokenOnLoanTo(address(rec), 1));
        assertTrue(!tester.isTokenOnLoanTo(address(subloanReceiver), 1));
        assertTrue(!tester.isTokenOnLoanTo(address(this), 1));
        assertEq(tester.ownerOf(1), address(this));
    }
    
    function testReclaimParentLoanAfterChildLoanExpires() public {
        tester.mint(address(this), 1);
        assertEq(tester.ownerOf(1), address(this));

        // loan 1
        uint expiry = block.number + 500;
        tester.lendFrom(address(this), address(rec), 1, expiry);
        assertEq(tester.getLoanExpiry(address(this), 1), expiry);
        assertTrue(tester.isTokenOnLoanTo(address(rec), 1));
        assertEq(tester.ownerOf(1), address(rec));

        // subloan
        uint subloanExpiry = block.number + 300;

        tester.lendFrom(address(rec), address(subloanReceiver), 1, subloanExpiry);
        assertEq(tester.getLoanExpiry(address(rec), 1), subloanExpiry);
        assertTrue(tester.isTokenOnLoanTo(address(rec), 1));
        assertTrue(tester.isTokenOnLoanTo(address(subloanReceiver), 1));
        assertEq(tester.ownerOf(1), address(subloanReceiver));

        cheats.roll(expiry + 1);

        // parent reclaimis subloan
        tester.reclaimLoanForToken(address(this), 1);
        assertTrue(!tester.isTokenOnLoanTo(address(subloanReceiver), 1));
        assertEq(tester.ownerOf(1), address(this));
    }

    function testRecursiveReclaim() public {
        tester.mint(address(this), 1);
        assertEq(tester.ownerOf(1), address(this));

        // loan 1
        uint expiry = block.number + 500;
        tester.lendFrom(address(this), address(rec), 1, expiry);
        assertEq(tester.getLoanExpiry(address(this), 1), expiry);
        assertTrue(tester.isTokenOnLoanTo(address(rec), 1));
        assertEq(tester.ownerOf(1), address(rec));
        uint count = 99;
        for (uint i = 0; i < count; i++) {
            uint subloanExpiry = block.number + count - i;
            Receiver newRec = new Receiver();
            tester.lendFrom(tester.ownerOf(1), address(newRec), 1, subloanExpiry);
            assertTrue(tester.isTokenOnLoanTo(address(newRec), 1));
            assertEq(tester.ownerOf(1), address(newRec));
        }

        // subloan
        cheats.roll(expiry + 1);

        // parent reclaims subloan
        tester.reclaimLoanForToken(address(this) , 1);
        assertEq(tester.numOutstandingLoans(1), 0);
        assertTrue(!tester.isTokenOnLoanTo(address(subloanReceiver), 1));
        assertTrue(!tester.isTokenOnLoanTo(address(this), 1));
        assertTrue(!tester.isTokenOnLoanTo(address(rec), 1));
        assertEq(tester.ownerOf(1), address(this));
    }
}
