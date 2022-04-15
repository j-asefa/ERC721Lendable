pragma solidity ^0.8.13;

/**
 * @dev Required interface of an ERC721Lendable compliant contract.
 */
interface IERC721Lendable {
    /**
     * @dev Emitted when `tokenId` is lent from `lender` to `borrower` with the given `expiry`.
     */
    event LoanCreated(address indexed lender, address indexed borrower, uint256 tokenId, uint256 expiry);

    /**
     * @dev Emitted when an active loan for `tokenId` is reclaimed from `borrower` to `lender`.
     */
    event LoanReclaimed(address indexed lender, address indexed borrower, uint256 loanId);

    /**
    * @dev structure of an ERC721Lendable token loan.
    */
    struct ERC721TokenLoan {
        address lender;
        address borrower;
        uint256 tokenId;
        uint256 expiry;
        bool isActive;
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
    function lendFrom(address lender, address borrower, uint256 tokenId, uint256 expiry) external;

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
    function reclaimLoanForToken(address lender, address borrower, uint256 tokenId) external;

    /**
     * @dev Returns true if `tokenId` is currently on loan to `borrower`, false otherwise.
     */
    function isTokenOnLoanTo(address borrower, uint256 tokenId) external view returns (bool);
}
