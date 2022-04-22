
pragma solidity ^0.8.13;

import "./interfaces/IERC721Lendable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract ERC721Lendable is ERC721, IERC721Lendable {
    using Strings for uint256;

    // limit the number of outstanding loans so that recursive calls to {ERC721Lendable-_deleteSubloans} do not overflow the stack
    uint256 private _maxNumOutstandingLoans;

    // Mapping from address to token loans
    mapping(address => mapping(uint256 => ERC721TokenLoan)) private _addressToTokenLoans;
    mapping(address => mapping(uint256 => ERC721TokenLoan)) private _addressToTokenBorrows;

    mapping(uint256 => uint256) private _tokenIdToOutstandingLoanCount;

    constructor(uint maxNumOutstandingLoans, string memory name, string memory symbol) ERC721(name, symbol) {
        _maxNumOutstandingLoans = maxNumOutstandingLoans;
    }

    /**
     * @dev See {IERC721Lendable-lendFrom}.
     */
    function lendFrom(address lender, address borrower, uint256 tokenId, uint256 expiry) external virtual override {
        ERC721TokenLoan storage loan = _getTokenBorrow(lender, tokenId);
        if (loan.isActive) {
            require(expiry < loan.expiry, "ERC721Lendable: expiry is not greater than ongoing loan expiry.");
        }
        _lend(lender, borrower, tokenId, expiry);
    }

    /**
     * @dev See {IERC721Lendable-reclaimLoanForToken}.
     */
    function reclaimLoanForToken(address lender, uint256 tokenId) external virtual override {
        ERC721TokenLoan storage loan = _getLoan(lender, tokenId);
        require(loan.lender == lender, "ERC721Lendable: lender is not token lender.");
        require(block.number >= loan.expiry, "ERC721Lendable: loan has not expired");
        _reclaimLoan(lender, tokenId);
    }

    /**
     * @dev See {IERC721Lendable-isTokenOnLoanTo}.
     */
    function isTokenOnLoanTo(address borrower, uint256 tokenId) external virtual view override returns (bool) {
        return _isTokenOnLoanTo(borrower, tokenId);
    }

    /**
     * @dev See {IERC721Lendable-getLoanExpiry}.
     */
    function getLoanExpiry(address lender, uint256 tokenId) external view virtual returns (uint256) {
        ERC721TokenLoan storage loan = _getLoan(lender, tokenId);
        return loan.expiry;
    }

    /**
     * @dev See {IERC721Lendable-getLoanExpiry}.
     */
    function numOutstandingLoans(uint256 tokenId) external view virtual returns (uint256) {
        return _tokenIdToOutstandingLoanCount[tokenId];
    }

    /**
     * @dev See {IERC721Lendable-lendFrom}.
     */
    function _lend(address lender, address borrower, uint256 tokenId, uint256 expiry) internal virtual {
        require(lender != address(0), "ERC721Lendable: lend from the zero address");
        require(borrower != address(0), "ERC721Lendable: lend to the zero address");
        require(ownerOf(tokenId) == lender, "ERC721Lendable: lender is not the token owner");
        require(!_isTokenOnLoanTo(borrower, tokenId), "ERC721Lendable: token is already on loan to borrower");

        uint256 outstandingLoanCount = _tokenIdToOutstandingLoanCount[tokenId];
        require(outstandingLoanCount < _maxNumOutstandingLoans, "ERC721Lendable: token has been lent out the maximum number of times.");
        ERC721TokenLoan memory loan = ERC721TokenLoan(lender, borrower, tokenId, expiry, true);
        _addressToTokenLoans[lender][tokenId] = loan;
        _addressToTokenBorrows[borrower][tokenId] = loan;

        _tokenIdToOutstandingLoanCount[tokenId] = outstandingLoanCount + 1;
        super._safeTransfer(lender, borrower, tokenId, "");
        emit LoanCreated(lender, borrower, tokenId, expiry);
    }

    /**
     * @dev If there is an active loan to `from`, only allow lending out or reclaiming loans for this token.
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        ERC721TokenLoan storage ongoingLoan = _getTokenBorrow(from, tokenId);
        if (ongoingLoan.isActive) {
            // token is on loan to sender, require that this transfer is either part of a loan or is part of a loan reclamation
            ERC721TokenLoan storage newLoan = _getTokenLoan(from, tokenId);
            if (newLoan.isActive) {
                require((from == newLoan.lender && to == newLoan.borrower), "ERC721Lendable: token can only be sent to borrower");
            } else {
                // transfer is part of a loan reclamation. Ensure it is being sent back to the current ongoing loan lender, or to a parent lender.
                ERC721TokenLoan storage originatingLoan = _tryGetLoan(to, tokenId);
                require((from == ongoingLoan.borrower && to == ongoingLoan.lender) || (from == ongoingLoan.borrower && to == originatingLoan.lender), "ERC721Lendable: token must be sent back to lender");
            }
        }
    }

    function _isTokenOnLoanTo(address borrower, uint256 tokenId) private view returns (bool) {
        ERC721TokenLoan storage loan = _getTokenBorrow(borrower, tokenId);
        return loan.isActive && loan.borrower == borrower;
    }

    function _reclaimLoan(address lender, uint256 tokenId) private {
        address borrower = ownerOf(tokenId);
        require(borrower != lender, "ERC721Lendable: borrower is lender");
        super._safeTransfer(borrower, lender, tokenId, "");
        _deleteSubloans(lender, borrower, tokenId);
        emit LoanReclaimed(lender, borrower, tokenId);
    }

    function _deleteSubloans(address lender, address borrower, uint256 tokenId) private {
        ERC721TokenLoan storage loan = _getLoan(lender, tokenId);
        if (loan.borrower != borrower) {
            //recursively delete all subloans
            _deleteSubloans(loan.borrower, borrower, tokenId);
        }
        delete _addressToTokenBorrows[loan.borrower][tokenId];
        delete _addressToTokenLoans[loan.lender][tokenId];
        _tokenIdToOutstandingLoanCount[tokenId] -= 1;
    }

    function _getLoan(address lender, uint256 tokenId) private view returns (ERC721TokenLoan storage) {
        require(_exists(tokenId), "ERC721Lendable: query for nonexistent token.");
        ERC721TokenLoan storage loan = _getTokenLoan(lender, tokenId);
        require(loan.isActive, "ERC721Lendable: loan is not active");
        return loan;
    }

    function _tryGetLoan(address lender, uint256 tokenId) private view returns (ERC721TokenLoan storage) {
        require(_exists(tokenId), "ERC721Lendable: query for nonexistent token.");
        return _getTokenLoan(lender, tokenId);
    }

    function _getTokenLoan(address lender, uint256 tokenId) private view returns (ERC721TokenLoan storage) {
        return _addressToTokenLoans[lender][tokenId];
    }

    function _getTokenBorrow(address borrower, uint256 tokenId) private view returns (ERC721TokenLoan storage) {
        return _addressToTokenBorrows[borrower][tokenId];
    }
}
