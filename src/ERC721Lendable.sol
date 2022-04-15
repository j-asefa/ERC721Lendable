
pragma solidity ^0.8.13;

import "./interfaces/IERC721Lendable.sol";
import "./utils/Heap.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

abstract contract ERC721Lendable is ERC721, IERC721Lendable {
    using Strings for uint256;
    using Heap for Heap.Data;

    // Mapping from address to token loans
    mapping(address => mapping(uint256 => ERC721TokenLoan)) private _addressToTokenLoans;
    mapping(address => mapping(uint256 => ERC721TokenLoan)) private _addressToTokenBorrows;

    // Mapping from tokenId to loan expiry heap
    mapping(uint256 => Heap.Data) private _tokenIdToLoanExpiries;

    /**
     * @dev See {IERC721Lendable-lendFrom}.
     */
    function lendFrom(address lender, address borrower, uint256 tokenId, uint256 expiry) external virtual override {
        require(_getMaxLoanDuration(tokenId) < expiry, "ERC721Lendable: expiry must be greater than all outstanding loan expiries for token.");
        _lend(lender, borrower, tokenId, expiry);
    }

    /**
     * @dev See {IERC721Lendable-reclaimLoanForToken}.
     */
    function reclaimLoanForToken(address lender, address borrower, uint256 tokenId) external virtual override {
        ERC721TokenLoan storage loan = _getLoan(lender, tokenId);
        require(ownerOf(tokenId) == lender, "ERC721Lendable: lender is not token owner.");
        require(loan.lender == lender, "ERC721Lendable: lender is not token lender.");
        require(block.number >= loan.expiry, "ERC721Lendable: loan has not expired");
        _reclaimLoan(lender, borrower, tokenId);
    }

    /**
     * @dev See {IERC721Lendable-isTokenOnLoanTo}.
     */
    function isTokenOnLoanTo(address borrower, uint256 tokenId) external virtual view override returns (bool) {
        return _isTokenOnLoanTo(borrower, tokenId);
    }


    /**
     * @dev Returns the loan expiry value that is furthest out in the future for `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` token must exist.
     */
    function _getMaxLoanDuration(uint256 tokenId) internal view virtual returns (uint256) {
        return _tokenIdToLoanExpiries[tokenId].getMax().priority;
    }

    /**
     * @dev Lends `tokenId` from `lender` to `borrower` with expiry `expiry`.
     * 
     *  The effect is to transfer ownership from `lender` to `borrower`. After this function is called,
     *      subsequent calls to `ownerOf` for `tokenId` will return the borrowers address, and token 
     *      balances will be updated to reflect that `borrower` is now in possession of `tokenId` and
     *      that `lender` is no longer in possession of `tokenId`.
     *   
     * Requirements:
     *
     * - `lender` cannot be the zero address.
     * - `borrower` cannot be the zero address.
     * - `tokenId` token must be owned by (or be on loan to) `lender`.
     * - `tokenId` token must not be on loan to `borrower` (to prevent circular loans).
     *
     * Emits a {LoanCreated} event.
     */
    function _lend(address lender, address borrower, uint256 tokenId, uint256 expiry) internal virtual {
        require(lender != address(0), "ERC721Lendable: lend from the zero address");
        require(borrower != address(0), "ERC721Lendable: lend to the zero address");
        require(ownerOf(tokenId) == lender, "ERC721Lendable: lender is not the token owner");
        require(!_isTokenOnLoanTo(borrower, tokenId), "ERC721Lendable: token is already on loan to borrower");
        ERC721TokenLoan memory loan = ERC721TokenLoan(lender, borrower, tokenId, expiry, true);
        _tokenIdToLoanExpiries[tokenId].insert(expiry);
        _addressToTokenLoans[lender][tokenId] = loan;
        _addressToTokenBorrows[borrower][tokenId] = loan;
        super._safeTransfer(lender, borrower, tokenId, "");
        emit LoanCreated(lender, borrower, tokenId, expiry);
    }

    /**
     * @dev Reclaims ownership of `tokenId` from `borrower` to `lender`.
     * 
     *  The effect is to transfer ownership from `borrower` back to `lender`. After this function is called,
     *      subsequent calls to `ownerOf` for `tokenId` will return the lenders address, and token 
     *      balances will be updated to reflect that `lender` is now in possession of `tokenId` and
     *      that `borrower` is no longer in possession of `tokenId`.
     *
     * Requirements:
     *
     * - `lender` cannot be the zero address.
     * - `borrower` cannot be the zero address.
     * - `tokenId` token must be owned by (or be on loan to) `lender`.
     * - `tokenId` token must not be on loan to `borrower` (to prevent circular loans).
     *
     * Emits a {LoanReclaimed} event.
     */
    function _reclaimLoan(address lender, address borrower, uint256 tokenId) private {
        delete _addressToTokenLoans[lender][tokenId];
        delete _addressToTokenBorrows[borrower][tokenId];
        _tokenIdToLoanExpiries[tokenId].extractMax();
        super._safeTransfer(borrower, lender, tokenId, "");
        emit LoanReclaimed(lender, borrower, tokenId);
    }

    /**
     * @dev Return the ongoing loan for `tokenId` from `lender` to `borrower`.
     * 
     * Requirements:

     * - `tokenId` token must exist.
     */
    function _getLoan(address lender, uint256 tokenId) private view returns (ERC721TokenLoan storage) {
        require(_exists(tokenId), "ERC721Lendable: query for nonexistent token.");
        ERC721TokenLoan storage loan = _addressToTokenLoans[lender][tokenId];
        require(loan.isActive, "ERC721Lendable: loan is not active");
        return loan;
    }

    /**
     * @dev See {IERC721Lendable-isTokenOnLoanTo}.
     */
    function _isTokenOnLoanTo(address borrower, uint256 tokenId) internal view returns (bool) {
        ERC721TokenLoan storage loan = _addressToTokenBorrows[borrower][tokenId];
        return loan.isActive && loan.borrower == borrower;
    }

    /**
     * @dev If there is an active loan to `from`, only allow lending out or reclaiming loans for this token.
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        ERC721TokenLoan storage loan = _addressToTokenBorrows[from][tokenId];
        if (loan.isActive) {
            require((from == loan.lender && to == loan.borrower) || (from == loan.borrower && to == loan.lender), "ERC721Lendable: token is on loan to current owner");
        }
    }
}
